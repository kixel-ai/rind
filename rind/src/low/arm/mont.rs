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
        Some(_) if num.is_multiple_of(8) => unsafe { bn_mul8x_mont_neon(rp, ap, bp, np, &n0, num) },
        // SAFETY: as above, from two words.
        _ => unsafe {
            bn_mul_mont_nohw(rp, ap, bp, np, &n0, num);
        },
    }
}

/// `z = x^2 / 2^(64k) mod m`, for `x` below the odd `m`, where `k` is the
/// length of each and `n0` is `-m^-1 mod 2^64`.
pub(crate) fn mont_sqr(z: &mut [u64], x: &[u64], m: &[u64], n0: u64) {
    mont_mul(z, x, x, m, n0);
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
                unsafe { bn_mul_mont_nohw(z, x.as_ptr(), y.as_ptr(), m.as_ptr(), &n0, num) };
                assert_eq!(want[..k], got[..k], "nohw, {k} words, case {case}");

                if num.is_multiple_of(8) && HaveNeon::check().is_some() {
                    got.fill(0);
                    let z = got[..k].as_mut_ptr();
                    // SAFETY: as above, and the CPU has NEON.
                    unsafe { bn_mul8x_mont_neon(z, x.as_ptr(), y.as_ptr(), m.as_ptr(), &n0, num) };
                    assert_eq!(want[..k], got[..k], "neon, {k} words, case {case}");
                }

                mont_mul(&mut got[..k], x, y, m, n0);
                assert_eq!(want[..k], got[..k], "mont_mul, {k} words, case {case}");
            }
        }
    }
}
