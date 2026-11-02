// Copyright 2020-2021 The OpenSSL Project Authors. All Rights Reserved.
// Copyright (c) 2020-2021, Intel Corporation. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

//! Two exponentiations at once, each modulo its own odd modulus of 16, 24,
//! or 32 words, by aws-lc's dual RSAZ: almost Montgomery products on 256-bit
//! AVX-512 IFMA vectors over 52-bit limbs, and a 5-bit fixed window whose
//! table entry is gathered by masking every entry.
//!
//! This ports aws-lc's `RSAZ_mod_exp_avx512_x2`, from `rsaz_exp_x2.c` at the
//! commit `admin/import-aws-lc` names, over its `rsaz-2k-avx512`,
//! `rsaz-3k-avx512`, and `rsaz-4k-avx512` assembly, which Sergey Kirillov
//! and Andrey Matyukov wrote for OpenSSL. aws-lc runs it for the CRT of
//! RSA-2048, 3072, and 4096 on CPUs with AVX-512 IFMA, where it signed 1.85,
//! 3.09, and 3.56 times as fast as rind's exponentiations one at a time. It
//! takes `rr` to its own `R` by the dual product, not aws-lc's single one,
//! which rind then has no use for.
//!
//! It is not formally verified: its correctness rests on its use in OpenSSL
//! and aws-lc, and on rind's tests of it against the exponentiation the other
//! CPUs run, Wycheproof, and aws-lc-rs. Each product is below `2m` given
//! inputs below `2m`, since `4m` is below its `R` of `2^(52 * limbs)`, so it
//! holds for any odd modulus of its width, where aws-lc also asks for the top
//! bit set.

use super::cpu::HaveAvx512ForRsa;
use crate::low;

/// Proof that the dual RSAZ runs for moduli of the width it was checked for:
/// the CPU has AVX-512 IFMA, as aws-lc's `BN_mod_exp_mont_consttime_x2`
/// decides, and the width is 16, 24, or 32 words.
#[derive(Clone, Copy, Debug)]
pub(crate) struct RsazAvx512 {
    token: HaveAvx512ForRsa,
    words: usize,
}

/// One exponentiation of the pair: `x^e mod m`, for an odd `m` and `x` below
/// it, where `rr` is `2^(128k) mod m` and `n0` is `-m^-1 mod 2^64`, for `k`
/// words each.
pub(crate) struct Operands<'a> {
    pub(crate) x: &'a [u64],
    pub(crate) e: &'a [u64],
    pub(crate) m: &'a [u64],
    pub(crate) rr: &'a [u64],
    pub(crate) n0: u64,
}

impl RsazAvx512 {
    pub(crate) fn check(words: usize) -> Option<Self> {
        let token = HaveAvx512ForRsa::check()?;
        matches!(words, 16 | 24 | 32).then_some(Self { token, words })
    }

    /// `z[i] = x^e mod m` for each of `operands`.
    ///
    /// The instruction trace and memory addresses depend on none of their
    /// values.
    pub(crate) fn mod_exp(self, z: [&mut [u64]; 2], operands: [Operands<'_>; 2]) {
        for (z, o) in z.iter().zip(&operands) {
            assert!([z.len(), o.x.len(), o.e.len(), o.m.len(), o.rr.len()] == [self.words; 5]);
        }
        match self.words {
            16 => mod_exp(self.token, &X20, z, &operands),
            24 => mod_exp(self.token, &X30, z, &operands),
            _ => mod_exp(self.token, &X40, z, &operands),
        }
    }
}

/// A value for each modulus, in `H` words of 52-bit limbs each, one after
/// the other, as the routines take them. Products are almost Montgomery:
/// below `2m`, not `m`.
#[derive(Clone, Copy)]
#[repr(C, align(64))]
struct Pair<const H: usize>([[u64; H]; 2]);

impl<const H: usize> Pair<H> {
    const ZERO: Self = Self([[0; H]; 2]);

    /// `words[i]` in the value for modulus `i`.
    fn from_words(words: [&[u64]; 2]) -> Self {
        let mut pair = Self::ZERO;
        for (limbs, words) in pair.0.iter_mut().zip(words) {
            to_limbs(limbs, words);
        }
        pair
    }

    /// `v << shift` in the value for each modulus, for `v` below `2^52`.
    fn both(v: u64, shift: usize) -> Self {
        let mut pair = Self::ZERO;
        for limbs in &mut pair.0 {
            limbs[shift / 52] = v << (shift % 52);
        }
        pair
    }
}

const MASK: u64 = (1 << 52) - 1;

/// Splits `words` into 52-bit `limbs`, zero above them.
fn to_limbs(limbs: &mut [u64], words: &[u64]) {
    let (mut acc, mut held) = (0u128, 0);
    let mut words = words.iter();
    for limb in limbs {
        if held < 52 {
            acc |= u128::from(words.next().copied().unwrap_or(0)) << held;
            held += 64;
        }
        *limb = acc as u64 & MASK;
        acc >>= 52;
        held -= 52;
    }
}

/// Joins 52-bit `limbs` into `words`, which must hold their value.
fn from_limbs(words: &mut [u64], limbs: &[u64]) {
    let (mut acc, mut held) = (0u128, 0);
    let mut limbs = limbs.iter();
    for word in words {
        while held < 64 {
            acc |= u128::from(limbs.next().copied().unwrap_or(0)) << held;
            held += 52;
        }
        *word = acc as u64;
        acc >>= 64;
        held -= 64;
    }
}

/// One width's routines, which take each value as a [`Pair<H>`].
struct Routines<const H: usize> {
    /// The limbs of each value; `H` pads 30 to 32 so that each value fills
    /// whole vectors.
    limbs: usize,
    amm: unsafe extern "sysv64" fn(
        r: *mut u64,
        a: *const u64,
        b: *const u64,
        m: *const u64,
        k0: *const u64,
    ),
    extract: unsafe extern "sysv64" fn(r: *mut u64, table: *const u64, i: u64, j: u64),
}

static X20: Routines<20> = Routines {
    limbs: 20,
    amm: rsaz_amm52x20_x2_ifma256,
    extract: extract_multiplier_2x20_win5,
};
static X30: Routines<32> = Routines {
    limbs: 30,
    amm: rsaz_amm52x30_x2_ifma256,
    extract: extract_multiplier_2x30_win5,
};
static X40: Routines<40> = Routines {
    limbs: 40,
    amm: rsaz_amm52x40_x2_ifma256,
    extract: extract_multiplier_2x40_win5,
};

fn mod_exp<const H: usize>(
    token: HaveAvx512ForRsa,
    routines: &Routines<H>,
    z: [&mut [u64]; 2],
    operands: &[Operands<'_>; 2],
) {
    let k = operands[0].m.len();
    let [a, b] = operands;
    let m = Pair::from_words([a.m, b.m]);
    let rsaz = Products {
        _token: token,
        routines,
        m: &m,
        k0: [a.n0, b.n0],
    };

    // `rr` is R^2 for R = 2^(64k); RSAZ's R is 2^(52l) for `l` limbs. This
    // takes it to 2^(256k) / 2^(52l), then times 2^(4(52l - 64k)) over
    // 2^(52l) to 2^(104l), RSAZ's R^2.
    let mut rr = Pair::from_words([a.rr, b.rr]);
    rsaz.sqr(&mut rr);
    rsaz.mul_by(&mut rr, &Pair::both(1, 4 * (52 * routines.limbs - 64 * k)));

    // table[i] is the base to the `i`, in Montgomery form: each even entry
    // squares its half, and each odd one multiplies the entry below it by
    // the base.
    let one = Pair::both(1, 0);
    let mut table = vec![Pair::ZERO; 32];
    rsaz.mul(&mut table[0], &one, &rr);
    rsaz.mul(&mut table[1], &Pair::from_words([a.x, b.x]), &rr);
    for i in 2..32 {
        let (done, rest) = table.split_at_mut(i);
        match i % 2 {
            0 => rsaz.mul(&mut rest[0], &done[i / 2], &done[i / 2]),
            _ => rsaz.mul(&mut rest[0], &done[i - 1], &done[1]),
        }
    }

    // Each exponent's bits from `bit`, through `bit + 4`, at public `bit`.
    let window = |bit: usize| {
        let (w, s) = (bit / 64, bit % 64);
        operands.each_ref().map(|o| {
            let pair =
                u128::from(o.e[w]) | o.e.get(w + 1).map_or(0, |&above| u128::from(above) << 64);
            (pair >> s) as u64 & 31
        })
    };

    // The top window takes what is left above whole windows.
    let top = 64 * k - 64 * k % 5;
    let (mut y, mut x) = (Pair::ZERO, Pair::ZERO);
    rsaz.extract(&mut y, &table, window(top));
    for bit in (0..top).step_by(5).rev() {
        rsaz.extract(&mut x, &table, window(bit));
        for _ in 0..5 {
            rsaz.sqr(&mut y);
        }
        rsaz.mul_by(&mut y, &x);
    }

    // Out of Montgomery form, which leaves each at most its modulus.
    rsaz.mul_by(&mut y, &one);
    for ((z, limbs), o) in z.into_iter().zip(&y.0).zip(operands) {
        let mut norm = [0; 32];
        let norm = &mut norm[..k];
        from_limbs(norm, limbs);
        let ge = 1 - low::bignum_cmp_lt(norm, o.m);
        low::bignum_optsub(z, norm, o.m, ge);
    }
}

/// The products modulo each of `m`, with `k0` as each's `-m^-1 mod 2^64`.
struct Products<'a, const H: usize> {
    _token: HaveAvx512ForRsa,
    routines: &'a Routines<H>,
    m: &'a Pair<H>,
    k0: [u64; 2],
}

impl<const H: usize> Products<'_, H> {
    /// `r = a * b / R`.
    fn mul(&self, r: &mut Pair<H>, a: &Pair<H>, b: &Pair<H>) {
        self.mul_raw(r, a, b);
    }

    /// `r = r * b / R`.
    fn mul_by(&self, r: &mut Pair<H>, b: &Pair<H>) {
        let r: *mut Pair<H> = r;
        self.mul_raw(r, r, b);
    }

    /// `r = r * r / R`.
    fn sqr(&self, r: &mut Pair<H>) {
        let r: *mut Pair<H> = r;
        self.mul_raw(r, r, r);
    }

    /// `r = a * b / R`, where `a` and `b` may be `r`, as aws-lc calls it.
    fn mul_raw(&self, r: *mut Pair<H>, a: *const Pair<H>, b: *const Pair<H>) {
        // SAFETY: each pointer is to a pair of `H` words, as the routine for
        // `H` reads and writes, and it reads two words of `k0`. It
        // takes `a` and `b` as `r` too, as aws-lc calls it; the token proves
        // the AVX-512 IFMA and BMI2 it uses.
        unsafe {
            (self.routines.amm)(
                r.cast(),
                a.cast(),
                b.cast(),
                self.m.0.as_ptr().cast(),
                self.k0.as_ptr(),
            )
        };
    }

    /// Loads entry `i[0]` of `table` into `r` for the first modulus, and
    /// `i[1]` for the second, for secret `i` below 32, reading every entry.
    fn extract(&self, r: &mut Pair<H>, table: &[Pair<H>], i: [u64; 2]) {
        assert!(table.len() == 32);
        // SAFETY: the routine for `H` reads the 32 entries of `2H` words
        // whatever `i` is, and writes `2H` words; the token proves the
        // AVX-512 it uses.
        unsafe {
            (self.routines.extract)(r.0.as_mut_ptr().cast(), table.as_ptr().cast(), i[0], i[1])
        };
    }
}

/// The limb mask, which the products load.
#[repr(C, align(32))]
struct Mask52x4([u64; 4]);

/// The gather's index increment, then the products' zeros: 32-byte
/// aligned.
#[repr(C, align(32))]
struct Ones([u64; 8]);

static MASK52X4: Mask52x4 = Mask52x4(include!("aws_lc/rsaz-2k-avx512.mask52x4.rs"));
static ONES: Ones = Ones(include!("aws_lc/rsaz-2k-avx512.ones.rs"));

// The routines take the System V ABI on every OS, since their text is
// aws-lc's ELF and Mach-O flavors, which read their arguments from its
// registers.

macro_rules! rsaz_routine {
    ($name:ident ($($arg:ident: $ty:ty),*) $(, $table:ident = $sym:ident)*) => {
        #[unsafe(naked)]
        unsafe extern "sysv64" fn $name($($arg: $ty),*) {
            #[cfg(not(target_vendor = "apple"))]
            core::arch::naked_asm!(
                include_str!(concat!("aws_lc/", stringify!($name), ".linux.s")),
                $($table = sym $sym,)*
                options(att_syntax)
            );
            #[cfg(target_vendor = "apple")]
            core::arch::naked_asm!(
                include_str!(concat!("aws_lc/", stringify!($name), ".apple.s")),
                $($table = sym $sym,)*
                options(att_syntax)
            );
        }
    };
}

rsaz_routine!(rsaz_amm52x20_x2_ifma256(r: *mut u64, a: *const u64, b: *const u64, m: *const u64, k0: *const u64), mask52x4 = MASK52X4, ones = ONES);
rsaz_routine!(rsaz_amm52x30_x2_ifma256(r: *mut u64, a: *const u64, b: *const u64, m: *const u64, k0: *const u64), mask52x4 = MASK52X4, ones = ONES);
rsaz_routine!(rsaz_amm52x40_x2_ifma256(r: *mut u64, a: *const u64, b: *const u64, m: *const u64, k0: *const u64), mask52x4 = MASK52X4, ones = ONES);
rsaz_routine!(extract_multiplier_2x20_win5(r: *mut u64, table: *const u64, i: u64, j: u64), ones = ONES);
rsaz_routine!(extract_multiplier_2x30_win5(r: *mut u64, table: *const u64, i: u64, j: u64), ones = ONES);
rsaz_routine!(extract_multiplier_2x40_win5(r: *mut u64, table: *const u64, i: u64, j: u64), ones = ONES);

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::super::adx_mux::tests::Rng;
    use super::*;
    use crate::low::PosInt;

    // Only CPUs with AVX-512 IFMA run it, so on those this checks it against
    // the exponentiation the others run, at each width it takes.
    #[test]
    fn matches_mont_exp() {
        if HaveAvx512ForRsa::check().is_none() {
            return;
        }
        let mut rng = Rng(0x3c6e_f372_fe94_f82b);
        for k in [16, 24, 32] {
            let rsaz = RsazAvx512::check(k).unwrap();
            let int = |words: &[u64]| {
                let bytes: Vec<u8> = words.iter().rev().flat_map(|w| w.to_be_bytes()).collect();
                PosInt::<32>::from_bytes(&bytes).unwrap()
            };
            let words = |int: &PosInt<32>| {
                let mut bytes = [0; 256];
                let bytes = int.to_bytes(&mut bytes).unwrap();
                let mut words = vec![0; k];
                for (word, chunk) in words.iter_mut().zip(bytes.rchunks(8)) {
                    let mut be = [0; 8];
                    be[8 - chunk.len()..].copy_from_slice(chunk);
                    *word = u64::from_be_bytes(be);
                }
                words
            };
            for case in 0..16 {
                let ops: [_; 2] = core::array::from_fn(|i| {
                    // The widest modulus, the narrowest with its top word
                    // set, which leaves the products furthest from reduced,
                    // and random ones of the full width, with the other
                    // modulus of the pair random.
                    let mut m: [u64; 32] = rng.words(64 * k as u32);
                    let m = &mut m[..k];
                    match (case, i) {
                        (0, 0) => m.fill(u64::MAX),
                        (1, 0) => {
                            m.fill(0);
                            m[k - 1] = 1;
                        }
                        _ => m[k - 1] |= 1 << 63,
                    }
                    m[0] |= 1;

                    // Bases below `m`: zero, one, and `m - 1` too.
                    let mut x: [u64; 32] = rng.words(64 * k as u32);
                    let x = &mut x[..k];
                    x[k - 1] %= m[k - 1];
                    match (case, i) {
                        (2, 0) => x.fill(0),
                        (3, 1) => {
                            x.fill(0);
                            x[0] = 1;
                        }
                        (4, _) => {
                            x.copy_from_slice(m);
                            x[0] -= 1;
                        }
                        _ => {}
                    }

                    // Exponents of the full width and a few words short:
                    // zero, one, all ones, and only the top bit, which the
                    // top window reaches.
                    let mut e: [u64; 32] = rng.words(64 * (k - case % 4) as u32);
                    let e = &mut e[..k];
                    match (case, i) {
                        (5, 0) => e.fill(0),
                        (6, 1) => {
                            e.fill(0);
                            e[0] = 1;
                        }
                        (7, _) => e.fill(u64::MAX),
                        (8, 0) => {
                            e.fill(0);
                            e[k - 1] = 1 << 63;
                        }
                        _ => {}
                    }
                    (m.to_vec(), x.to_vec(), e.to_vec())
                });

                let want = ops.each_ref().map(|(m, x, e)| {
                    let (n, x, mut e) = (int(m), int(x), int(e));
                    e.expand(&n);
                    let rr = n.montifier();
                    let n0 = n.mont_neg_inverse();
                    let one = n.fixed_one().mont_mul(&rr, &n, n0);
                    let r = x
                        .to_montgomery(&rr, &n)
                        .mont_exp(one, &e, &n, n0)
                        .from_montgomery(&n);
                    (words(&r), words(&rr), n0)
                });

                let mut got = [vec![0; k], vec![0; k]];
                let [g0, g1] = &mut got;
                let operands: [_; 2] = core::array::from_fn(|i| Operands {
                    x: &ops[i].1,
                    e: &ops[i].2,
                    m: &ops[i].0,
                    rr: &want[i].1,
                    n0: want[i].2,
                });
                rsaz.mod_exp([g0, g1], operands);
                assert_eq!(got, want.map(|w| w.0), "{k} words, case {case}");
            }
        }
    }
}
