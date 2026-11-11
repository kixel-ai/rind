// Written for Graviola by Joe Birr-Pixton, 2024.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! Basic implementation using vmull_p64, and aws-lc's NEON code for CPUs
//! without it.
//!
//! Based on the implementation in low/x86_64/ghash.rs

use core::arch::aarch64::*;
use core::mem;

use super::cpu::{HaveCryptoExt, HaveSha3};
use super::ghash_neon_armv8::NeonTable;
use crate::low;

pub(crate) enum GhashTable {
    Pmull(PmullTable),
    /// NEON's, which the table picks when the CPU lacks the crypto extension.
    Neon(NeonTable),
}

impl GhashTable {
    pub(crate) fn new(h: u128) -> Self {
        match HaveCryptoExt::check() {
            Some(token) => Self::Pmull(PmullTable::new(h, token)),
            None => Self::Neon(NeonTable::new(&h.to_be_bytes())),
        }
    }
}

/// Powers of a GHASH key for PMULL, which only a `HaveCryptoExt` token builds.
pub(crate) struct PmullTable {
    /// H to H^8 in the layout `gcm_init_v8` writes, which s2n-bignum's
    /// AES-GCM kernels read and `mul!` multiplies by: H, m(H, H^2), H^2,
    /// H^3, m(H^3, H^4), H^4, and so on to H^8, with each power's 64-bit
    /// halves swapped and m(A, B) holding the Karatsuba middle terms of A and
    /// B in its low and high halves. The four-way kernels read only the first
    /// six entries.
    pub(crate) htable: [uint64x2_t; 12],
    /// Whether AES-GCM runs the eight-way kernels, which need SHA3's `EOR3`.
    pub(crate) eight_way: Option<HaveSha3>,
}

impl PmullTable {
    pub(crate) fn new(h: u128, token: HaveCryptoExt) -> Self {
        // SAFETY: this crate requires the `neon` cpu feature
        let h = unsafe { gf128_big_endian(from_u128(h)) };
        // A tree, so the longest chain of dependent multiplies is three
        // rather than seven.
        let h2 = mul(h, h, token);
        let (h3, h4) = (mul(h2, h, token), mul(h2, h2, token));
        let h5 = mul(h4, h, token);
        let h6 = mul(h4, h2, token);
        let h7 = mul(h4, h3, token);
        let h8 = mul(h4, h4, token);

        // SAFETY: this crate requires the `neon` cpu feature
        let htable = unsafe {
            let m = |a, b| vzip1q_u64(xor_halves(a), xor_halves(b));
            [
                vextq_u64(h, h, 1),
                m(h, h2),
                vextq_u64(h2, h2, 1),
                vextq_u64(h3, h3, 1),
                m(h3, h4),
                vextq_u64(h4, h4, 1),
                vextq_u64(h5, h5, 1),
                m(h5, h6),
                vextq_u64(h6, h6, 1),
                vextq_u64(h7, h7, 1),
                m(h7, h8),
                vextq_u64(h8, h8, 1),
            ]
        };

        Self {
            htable,
            eight_way: HaveSha3::check(),
        }
    }
}

impl Drop for PmullTable {
    fn drop(&mut self) {
        low::zeroise(&mut self.htable);
    }
}

pub(crate) struct Ghash<'a> {
    pub(crate) table: &'a GhashTable,
    pub(crate) current: uint64x2_t,
}

impl<'a> Ghash<'a> {
    pub(crate) fn new(table: &'a GhashTable) -> Self {
        Self {
            table,
            current: zero(),
        }
    }

    /// Input `bytes` to the computation.
    ///
    /// `bytes` is zero-padded, if required.
    pub(crate) fn add(&mut self, bytes: &[u8]) {
        let table = match self.table {
            GhashTable::Pmull(table) => table,
            GhashTable::Neon(table) => {
                let mut xi = self.state();
                let (blocks, tail) = bytes.as_chunks::<16>();
                table.ghash(&mut xi, blocks);
                if !tail.is_empty() {
                    let mut last = [0u8; 16];
                    last[..tail.len()].copy_from_slice(tail);
                    table.ghash(&mut xi, &[last]);
                }
                return self.set_state(xi);
            }
        };

        let (by8_blocks, remainder) = bytes.as_chunks::<128>();

        for chunk8 in by8_blocks {
            self.eight_blocks(
                table,
                u128::from_be_bytes(chunk8[0..16].try_into().unwrap()),
                u128::from_be_bytes(chunk8[16..32].try_into().unwrap()),
                u128::from_be_bytes(chunk8[32..48].try_into().unwrap()),
                u128::from_be_bytes(chunk8[48..64].try_into().unwrap()),
                u128::from_be_bytes(chunk8[64..80].try_into().unwrap()),
                u128::from_be_bytes(chunk8[80..96].try_into().unwrap()),
                u128::from_be_bytes(chunk8[96..112].try_into().unwrap()),
                u128::from_be_bytes(chunk8[112..128].try_into().unwrap()),
            );
        }

        let (whole_blocks, remainder) = remainder.as_chunks::<16>();

        for chunk in whole_blocks {
            let u = u128::from_be_bytes(*chunk);
            self.one_block(table, u);
        }

        let bytes = remainder;
        if !bytes.is_empty() {
            let mut block = [0u8; 16];
            block[..bytes.len()].copy_from_slice(bytes);

            let u = u128::from_be_bytes(block);
            self.one_block(table, u);
        }
    }

    pub(crate) fn into_bytes(self) -> [u8; 16] {
        self.state()
    }

    /// The running hash, in the byte order s2n-bignum's AES-GCM kernels hold it.
    pub(crate) fn state(&self) -> [u8; 16] {
        to_u128(self.current).to_be_bytes()
    }

    /// Resumes from a running hash that [`Self::state`] returned.
    pub(crate) fn set_state(&mut self, state: [u8; 16]) {
        self.current = from_u128(u128::from_be_bytes(state));
    }

    fn one_block(&mut self, table: &PmullTable, block: u128) {
        // SAFETY: this crate requires the `neon` cpu feature
        self.current = unsafe { veorq_u64(self.current, from_u128(block)) };
        // SAFETY: only a `HaveCryptoExt` token builds `table`, and rind
        // requires NEON.
        self.current = unsafe { _mul_h(table, self.current) };
    }

    #[inline]
    fn eight_blocks(
        &mut self,
        table: &PmullTable,
        b1: u128,
        b2: u128,
        b3: u128,
        b4: u128,
        b5: u128,
        b6: u128,
        b7: u128,
        b8: u128,
    ) {
        // SAFETY: this crate requires the `neon` cpu feature
        let b1 = unsafe { veorq_u64(self.current, from_u128(b1)) };
        self.current = mul8(
            table,
            b1,
            from_u128(b2),
            from_u128(b3),
            from_u128(b4),
            from_u128(b5),
            from_u128(b6),
            from_u128(b7),
            from_u128(b8),
        );
    }
}

#[inline]
fn mul(a: uint64x2_t, b: uint64x2_t, _: HaveCryptoExt) -> uint64x2_t {
    // SAFETY: the token proves the CPU has PMULL, and rind requires NEON.
    unsafe { _mul(a, b) }
}

#[inline]
fn mul8(
    table: &PmullTable,
    a: uint64x2_t,
    b: uint64x2_t,
    c: uint64x2_t,
    d: uint64x2_t,
    e: uint64x2_t,
    f: uint64x2_t,
    g: uint64x2_t,
    h: uint64x2_t,
) -> uint64x2_t {
    // SAFETY: only a `HaveCryptoExt` token builds `table`, and rind requires
    // NEON.
    unsafe { _mul8(table, a, b, c, d, e, f, g, h) }
}

/// Accumulates `x` times a power of H, read as `htable` holds it: `hs`, its
/// halves swapped, and the half of `m` that `mul_m` takes, its Karatsuba
/// middle term. Swapping `x` lines it up with `hs` and also sums its halves
/// into both lanes of `xx`, so the layout costs no extra instructions.
macro_rules! mul {
    ($lo:ident, $mi:ident, $hi:ident, $x:expr, $hs:expr, $m:expr, $mul_m:ident) => {
        let x = $x;
        let xs = vextq_u64(x, x, 1);

        let tlo = vmull_high_p64_fix(xs, $hs);
        $lo = veorq_u64(tlo, $lo);

        let xx = veorq_u64(xs, x);

        let thi = vmull_p64_fix(xs, $hs);
        $hi = veorq_u64(thi, $hi);

        let tmi = $mul_m(xx, $m);
        $mi = veorq_u64(tmi, $mi);
    };
}

macro_rules! reduce {
    ($lo:ident, $mi:ident, $hi:ident) => {{
        let $mi = veorq_u64($mi, $lo);
        let $mi = veorq_u64($mi, $hi);

        let ls = vextq_u64($lo, $lo, 1);
        let $lo = vmull_p64_fix(GF128_POLY_HI, $lo);
        let $mi = veorq_u64($mi, ls);
        let $mi = veorq_u64($mi, $lo);

        let ms = vextq_u64($mi, $mi, 1);
        let $mi = vmull_p64_fix(GF128_POLY_HI, $mi);
        let $hi = veorq_u64($hi, ms);
        let $hi = veorq_u64($hi, $mi);
        $hi
    }};
}

#[target_feature(enable = "neon,aes")]
fn _mul(a: uint64x2_t, b: uint64x2_t) -> uint64x2_t {
    let (mut lo, mut mi, mut hi) = (zero(), zero(), zero());
    let (bs, bx) = (vextq_u64(b, b, 1), xor_halves(b));
    mul!(lo, mi, hi, a, bs, bx, vmull_p64_fix);
    reduce!(lo, mi, hi)
}

#[target_feature(enable = "neon,aes")]
fn _mul_h(table: &PmullTable, a: uint64x2_t) -> uint64x2_t {
    let (mut lo, mut mi, mut hi) = (zero(), zero(), zero());
    let t = &table.htable;
    mul!(lo, mi, hi, a, t[0], t[1], vmull_p64_fix);
    reduce!(lo, mi, hi)
}

#[target_feature(enable = "neon,aes")]
#[inline]
fn _mul8(
    table: &PmullTable,
    a: uint64x2_t,
    b: uint64x2_t,
    c: uint64x2_t,
    d: uint64x2_t,
    e: uint64x2_t,
    f: uint64x2_t,
    g: uint64x2_t,
    h: uint64x2_t,
) -> uint64x2_t {
    let (mut lo, mut mi, mut hi) = (zero(), zero(), zero());
    let t = &table.htable;
    mul!(lo, mi, hi, a, t[11], t[10], vmull_high_p64_fix);
    mul!(lo, mi, hi, b, t[9], t[10], vmull_p64_fix);
    mul!(lo, mi, hi, c, t[8], t[7], vmull_high_p64_fix);
    mul!(lo, mi, hi, d, t[6], t[7], vmull_p64_fix);
    mul!(lo, mi, hi, e, t[5], t[4], vmull_high_p64_fix);
    mul!(lo, mi, hi, f, t[3], t[4], vmull_p64_fix);
    mul!(lo, mi, hi, g, t[2], t[1], vmull_high_p64_fix);
    mul!(lo, mi, hi, h, t[0], t[1], vmull_p64_fix);
    reduce!(lo, mi, hi)
}

/// The GHASH of `n` blocks from zero, with one reduction per eight: of a
/// group of `k` blocks, the first, plus the hash of the groups before it, is
/// multiplied by H^k, the next by H^(k-1), and so on. The first group takes
/// what is left over from eights.
pub(crate) struct Aggregate<'a> {
    table: &'a PmullTable,
    /// The power of H the next block is multiplied by, or zero when it
    /// starts a group.
    power: usize,
    lo: uint64x2_t,
    mi: uint64x2_t,
    hi: uint64x2_t,
}

impl<'a> Aggregate<'a> {
    /// Starts a hash of `n` blocks, at least one.
    pub(crate) fn new(table: &'a PmullTable, n: usize) -> Self {
        assert!(n > 0);
        Self {
            table,
            power: (n - 1) % 8 + 1,
            lo: zero(),
            mi: zero(),
            hi: zero(),
        }
    }

    /// Adds the next block, in memory order.
    #[target_feature(enable = "neon,aes")]
    #[inline]
    pub(crate) fn add(&mut self, block: uint8x16_t) {
        // For H^p, `htable`'s index of its swapped halves, and of the 64-bit
        // word holding its Karatsuba middle term.
        const POWERS: [(usize, usize); 8] = [
            (0, 2),
            (2, 3),
            (3, 8),
            (5, 9),
            (6, 14),
            (8, 15),
            (9, 20),
            (11, 21),
        ];
        let (mut lo, mut mi, mut hi) = (self.lo, self.mi, self.hi);
        let mut x = reverse(block);
        if self.power == 0 {
            x = veorq_u64(x, reduce!(lo, mi, hi));
            (lo, mi, hi) = (zero(), zero(), zero());
            self.power = 8;
        }
        self.power -= 1;
        let (hs, m) = POWERS[self.power];
        // SAFETY: a `uint64x2_t` is two `u64`s, low lane first.
        let words: &[u64; 24] = unsafe { mem::transmute(&self.table.htable) };
        mul!(
            lo,
            mi,
            hi,
            x,
            self.table.htable[hs],
            vdupq_n_u64(words[m]),
            vmull_p64_fix
        );
        (self.lo, self.mi, self.hi) = (lo, mi, hi);
    }

    /// The hash, in memory order.
    #[target_feature(enable = "neon,aes")]
    #[inline]
    pub(crate) fn finish(self) -> uint8x16_t {
        let (lo, mi, hi) = (self.lo, self.mi, self.hi);
        vreinterpretq_u8_u64(reverse(vreinterpretq_u8_u64(reduce!(lo, mi, hi))))
    }
}

/// Reverses `block`'s bytes, between memory order and the hash's, as
/// [`Ghash`] reads each block through `u128::from_be_bytes`.
#[target_feature(enable = "neon")]
#[inline]
fn reverse(block: uint8x16_t) -> uint64x2_t {
    let r = vreinterpretq_u64_u8(vrev64q_u8(block));
    vextq_u64(r, r, 1)
}

#[target_feature(enable = "neon")]
fn xor_halves(h: uint64x2_t) -> uint64x2_t {
    let hx = vextq_u64(h, h, 1);
    veorq_u64(hx, h)
}

#[target_feature(enable = "neon")]
fn gf128_big_endian(h: uint64x2_t) -> uint64x2_t {
    // takes a raw hash subkey, and arranges that it can
    // be used in big endian ordering.
    let t = vreinterpretq_s32_u64(h);
    let (a, c, d) = (
        vgetq_lane_s32::<3>(t),
        vgetq_lane_s32::<1>(t),
        vgetq_lane_s32::<0>(t),
    );
    let t = vsetq_lane_s32(a, t, 3);
    let t = vsetq_lane_s32(c, t, 2);
    let t = vsetq_lane_s32(d, t, 1);
    let t = vsetq_lane_s32(a, t, 0);

    let t = vreinterpretq_u64_s32(vshrq_n_s32(t, 31));
    let h = vaddq_u64(h, h);
    let t = vandq_u64(GF128_POLY_CARRY_MASK, t);
    veorq_u64(h, t)
}

// the intrinsics exist, but have the wrong types :(

#[inline]
#[target_feature(enable = "neon,aes")]
fn vmull_p64_fix(a: uint64x2_t, b: uint64x2_t) -> uint64x2_t {
    let a = vgetq_lane_u64::<0>(a);
    let b = vgetq_lane_u64::<0>(b);
    let p = vmull_p64(a, b);
    // SAFETY: uint64x2_t and u128 have the same representation
    unsafe { mem::transmute(p) }
}

#[inline]
#[target_feature(enable = "neon,aes")]
fn vmull_high_p64_fix(a: uint64x2_t, b: uint64x2_t) -> uint64x2_t {
    let a = vgetq_lane_u64::<1>(a);
    let b = vgetq_lane_u64::<1>(b);
    let p = vmull_p64(a, b);
    // SAFETY: uint64x2_t and u128 have the same representation
    unsafe { mem::transmute(p) }
}

#[inline]
fn zero() -> uint64x2_t {
    // SAFETY: u128 and uint64x2_t have the same size and meaning of bits
    unsafe { mem::transmute(0u128) }
}

#[inline]
fn from_u128(u: u128) -> uint64x2_t {
    // SAFETY: u128 and uint64x2_t have the same size and meaning of bits
    unsafe { mem::transmute(u) }
}

#[inline]
fn to_u128(u: uint64x2_t) -> u128 {
    // SAFETY: u128 and uint64x2_t have the same size and meaning of bits
    unsafe { mem::transmute(u) }
}

// SAFETY: u128 and uint64x2_t have the same size and meaning of bits
const GF128_POLY_HI: uint64x2_t =
    unsafe { mem::transmute(0xc2000000_00000000_c2000000_00000000u128) };

// SAFETY: u128 and uint64x2_t have the same size and meaning of bits
const GF128_POLY_CARRY_MASK: uint64x2_t =
    unsafe { mem::transmute(0xc2000000_00000001_00000000_00000001u128) };

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::*;
    use crate::low::generic::ghash as model;

    #[test]
    fn pairwise() {
        check(0, b"");
        check(0, b"hello");
        check(1, b"");
        check(1, b"hello");
        let k = 0x00112233_44556677_8899aabb_ccddeeffu128;
        check(k, b"hello");
        check(k, b"hello world!");
        check(k, &[b'a'; 32]);
        check(k, &[b'b'; 64]);
        check(k, &[b'c'; 512 + 64 + 32 + 16]);

        let mut pattern = [0; 512 + 64 + 32 + 16];
        for (i, p) in pattern.iter_mut().enumerate() {
            *p = i as u8;
        }
        check(k, &pattern);

        let k = 0xffeeeedd_ffeeeedd_ff0000dd_ff0000ddu128;
        for (i, p) in pattern.iter_mut().enumerate() {
            *p = 0xf0 | (i & 0xf) as u8;
        }
        check(k, &pattern);
    }

    // Checks both tables the CPU can build, not only the one it picks, in
    // one call and split at a block boundary.
    fn check(key: u128, input: &[u8]) {
        println!("check: input={input:02x?}");
        let tb = model::GhashTable::new(key);
        let mut b = model::Ghash::new(&tb);
        b.add(input);
        let fb = b.into_bytes();

        let mut tables = vec![GhashTable::Neon(NeonTable::new(&key.to_be_bytes()))];
        if let Some(token) = HaveCryptoExt::check() {
            tables.push(GhashTable::Pmull(PmullTable::new(key, token)));
        }
        for ta in &tables {
            let mut a = Ghash::new(ta);
            a.add(input);
            assert_eq!(a.into_bytes(), fb, "for input: {input:02x?}");

            let split = input.len().min(16);
            let mut a = Ghash::new(ta);
            a.add(&input[..split]);
            a.add(&input[split..]);
            assert_eq!(a.into_bytes(), fb, "for input: {input:02x?}, split");
        }
    }
}
