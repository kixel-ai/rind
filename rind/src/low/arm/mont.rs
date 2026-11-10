// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! Montgomery multiplication modulo an RSA modulus or prime, by aws-lc's
//! `armv4-mont` routines as its `bn_mul_mont` picks them: NEON where the CPU
//! has it and the width is a multiple of eight 32-bit words, and integer
//! code otherwise.
//!
//! The assembly is aws-lc's, imported by `admin/import-aws-lc`. It is not
//! formally verified: its correctness rests on its use and testing in
//! OpenSSL, BoringSSL, and aws-lc, and on rind's tests of it against the
//! portable Montgomery reduction.
//!
//! The routines take 32-bit words. A little-endian slice of 64-bit words is
//! the same bytes as twice as many 32-bit words, and the low half of
//! `-m^-1 mod 2^64` is `-m^-1 mod 2^32`, as aws-lc's two-word `n0` holds it.

use super::cpu::HaveNeon;
use crate::low::ct;

unsafe extern "C" {
    #[link_name = aws_lc_symbol!("bn_mul_mont_nohw")]
    fn bn_mul_mont_nohw(
        rp: *mut u64,
        ap: *const u64,
        bp: *const u64,
        np: *const u64,
        n0: *const u64,
        num: usize,
    ) -> i32;

    #[link_name = aws_lc_symbol!("bn_mul8x_mont_neon")]
    fn bn_mul8x_mont_neon(
        rp: *mut u64,
        ap: *const u64,
        bp: *const u64,
        np: *const u64,
        n0: *const u64,
        num: usize,
    );
}

// As in `aesv8_armx`: ARM mode with NEON, then the target's `.fpu` again.
core::arch::global_asm!(
    ".text",
    ".fpu neon",
    ".code 32",
    include_str!("aws_lc/armv4-mont.s"),
    ".fpu vfpv3",
    bn_mul_mont_nohw = sym bn_mul_mont_nohw,
    bn_mul8x_mont_neon = sym bn_mul8x_mont_neon,
);

/// `z = x * y / 2^(64k) mod m`, for `x` and `y` below the odd `m`, where `k`
/// is the length of each and `n0` is `-m^-1 mod 2^64`.
pub(crate) fn mont_mul(z: &mut [u64], x: &[u64], y: &[u64], m: &[u64], n0: u64) {
    let k = m.len();
    assert!(k >= 1 && z.len() == k && x.len() == k && y.len() == k);
    let (rp, ap, bp, np, num) = (z.as_mut_ptr(), x.as_ptr(), y.as_ptr(), m.as_ptr(), k * 2);
    match HaveNeon::check() {
        // SAFETY: `z`, `x`, `y`, and `m` are each `num` 32-bit words, which
        // the routines read and write, `num` is at least two and a multiple
        // of eight, they read `n0`'s low word, and the token proves the CPU
        // has NEON.
        Some(_) if num.is_multiple_of(8) => unsafe {
            asm_call!(unsafe extern "C" bn_mul8x_mont_neon(rp, ap, bp, np, &n0, num))
        },
        // Where m's top 32 bits are zero, as for a 2056-bit key's 1028-bit
        // primes, so are x's and y's, and the integer routine runs a word
        // narrower, as aws-lc's does at the modulus's own width; one more
        // reduction step then divides by the word it left out. The modulus's
        // width is public: the key's encoding gives it.
        _ if k > 1 && ct::into_public(m[k - 1] >> 32 == 0) => {
            // SAFETY: as above, for `num - 1` words, at least two.
            unsafe { asm_call!(unsafe extern "C" bn_mul_mont_nohw(rp, ap, bp, np, &n0, num - 1)) };
            reduce_limb(z, m, n0 as u32);
        }
        // SAFETY: as above, from two words.
        _ => unsafe {
            asm_call!(unsafe extern "C" bn_mul_mont_nohw(rp, ap, bp, np, &n0, num));
        },
    }
}

/// `z = x^2 / 2^(64k) mod m`, for `x` below the odd `m`, where `k` is the
/// length of each and `n0` is `-m^-1 mod 2^64`.
pub(crate) fn mont_sqr(z: &mut [u64], x: &[u64], m: &[u64], n0: u64) {
    mont_mul(z, x, x, m, n0);
}

/// `z := z / 2^32 mod m`, for `z` below the odd `m`, whose top 32 bits are
/// zero, and ignoring the top 32 bits of `z`; `n0` is `-m^-1 mod 2^32`.
///
/// One step of Montgomery reduction: adding `u * m` for `u = z * n0 mod 2^32`
/// clears the low limb, and `(z + u * m) / 2^32 < (m + (2^32 - 1) m) / 2^32
/// = m`, so no subtraction follows.
fn reduce_limb(z: &mut [u64], m: &[u64], n0: u32) {
    const LOW: u64 = u32::MAX as u64;
    let k = m.len();
    z[k - 1] &= LOW;
    let u = u64::from((z[0] as u32).wrapping_mul(n0));

    // Each word's two limbs of `z + u * m`, the low then the high, each at
    // most (2^32 - 1)^2 + 2 (2^32 - 1) = 2^64 - 1. Wrapping, as a debug
    // build's overflow check would branch on the values. The sum moves down
    // a limb, so each word is written once the next word's low limb is known.
    let (mut carry, mut high) = (0, 0);
    for j in 0..k {
        let lo = u
            .wrapping_mul(m[j] & LOW)
            .wrapping_add(z[j] & LOW)
            .wrapping_add(carry);
        let hi = u
            .wrapping_mul(m[j] >> 32)
            .wrapping_add(z[j] >> 32)
            .wrapping_add(lo >> 32);
        if let Some(below) = j.checked_sub(1) {
            z[below] = high | lo << 32;
        }
        (high, carry) = (hi & LOW, hi >> 32);
    }
    z[k - 1] = high;
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::*;
    use crate::low::generic::bignum::{bignum_montredc, bignum_mul, bignum_negmodinv};

    /// xorshift64, so the moduli need no dependency.
    struct Rng(u64);

    impl Rng {
        fn words(&mut self, k: usize) -> [u64; 64] {
            let mut out = [0; 64];
            for word in &mut out[..k] {
                self.0 ^= self.0 << 13;
                self.0 ^= self.0 >> 7;
                self.0 ^= self.0 << 17;
                *word = self.0;
            }
            out
        }
    }

    // Every other test runs only the routine the CPU and width pick, so here
    // both are checked against the portable product and reduction, at
    // widths each takes, with the modulus's top word full, one, and zero.
    #[test]
    fn matches_portable() {
        let mut rng = Rng(0x2545_f491_4f6c_dd1d);
        for k in [1, 2, 3, 4, 5, 8, 12, 16, 17, 24, 32, 64] {
            for case in 0..12 {
                let mut m = rng.words(k);
                let m = &mut m[..k];
                match case {
                    0 => m.fill(u64::MAX),
                    1 if k > 1 => m[k - 1] = 1,
                    2 if k > 1 => m[k - 1] = 0,
                    _ => m[k - 1] |= 1 << 63,
                }
                m[0] |= 1;
                let mut n0 = [0];
                bignum_negmodinv(&mut n0, &m[..1]);
                let n0 = n0[0];

                // Operands below `m`, with its extremes: zero, and `m - 1`.
                let below = |rng: &mut Rng| {
                    let mut x = rng.words(k);
                    let top = (0..k).rev().find(|i| m[*i] != 0).unwrap();
                    x[top] %= m[top];
                    x[top + 1..k].fill(0);
                    x
                };
                let (mut x, y) = (below(&mut rng), below(&mut rng));
                match case {
                    3 => x[..k].fill(0),
                    4 => {
                        x[..k].copy_from_slice(m);
                        x[0] -= 1;
                    }
                    _ => {}
                }
                let (x, y) = (&x[..k], &y[..k]);

                let mut product = [0; 128];
                bignum_mul(&mut product[..2 * k], x, y);
                let mut want = [0; 64];
                bignum_montredc(&mut want[..k], &product[..2 * k], m, k as u64);
                let mut got = [0; 64];
                let (num, z) = (k * 2, got[..k].as_mut_ptr());
                // SAFETY: each operand is `num` 32-bit words.
                unsafe {
                    asm_call!(unsafe extern "C" bn_mul_mont_nohw(z, x.as_ptr(), y.as_ptr(), m.as_ptr(), &n0, num))
                };
                assert_eq!(want[..k], got[..k], "nohw, {k} words, case {case}");

                if num.is_multiple_of(8) && HaveNeon::check().is_some() {
                    got.fill(0);
                    let z = got[..k].as_mut_ptr();
                    // SAFETY: as above, and the CPU has NEON.
                    unsafe {
                        asm_call!(unsafe extern "C" bn_mul8x_mont_neon(z, x.as_ptr(), y.as_ptr(), m.as_ptr(), &n0, num))
                    };
                    assert_eq!(want[..k], got[..k], "neon, {k} words, case {case}");
                }

                mont_mul(&mut got[..k], x, y, m, n0);
                assert_eq!(want[..k], got[..k], "mont_mul, {k} words, case {case}");
            }
        }
    }
}
