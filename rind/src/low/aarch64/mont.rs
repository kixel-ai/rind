// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! Montgomery multiplication modulo an RSA modulus or prime: from two words,
//! aws-lc's `bn_mul_mont`, which picks its own squaring or 4x routine by the
//! width as aws-lc does. On a Neoverse-N2 it measured faster than
//! s2n-bignum's generic `bignum_montmul` and `bignum_montsqr` in every width
//! class it branches on: 1.15x at 17 and 33 words, 1.6x at 20, and twice as
//! fast at 24, 48, 64, 96, and 128. It replaces s2n-bignum's Karatsuba
//! routines at 16 and 32 words too, where ring, running it, signed RSA-2048
//! and RSA-4096 1.55x as fast as rind did on them. The generic routines run
//! only below two words.

/// `z = x * y / 2^(64k) mod m`, for `x` and `y` below `m`, where `k` is the
/// length of each and `n0` is `-m^-1 mod 2^64`.
pub(crate) fn mont_mul(z: &mut [u64], x: &[u64], y: &[u64], m: &[u64], n0: u64) {
    debug_assert!(z.len() == m.len() && x.len() == m.len() && y.len() == m.len());
    match m.len() {
        k if k >= 2 => mul_mont(z, x, y, m, n0),
        _ => super::bignum_montmul::bignum_montmul(z, x, y, m),
    }
}

/// `z = x^2 / 2^(64k) mod m`, for `x` below `m`, where `k` is the length of
/// each and `n0` is `-m^-1 mod 2^64`.
pub(crate) fn mont_sqr(z: &mut [u64], x: &[u64], m: &[u64], n0: u64) {
    debug_assert!(z.len() == m.len() && x.len() == m.len());
    match m.len() {
        k if k >= 2 => mul_mont(z, x, x, m, n0),
        _ => super::bignum_montsqr::bignum_montsqr(z, x, m),
    }
}

/// `mont_mul` for any width from two words. It squares by its own routine
/// when `x` and `y` are the same slice and the width is a multiple of eight.
fn mul_mont(z: &mut [u64], x: &[u64], y: &[u64], m: &[u64], n0: u64) {
    let k = m.len();
    assert!(k >= 2 && z.len() == k && x.len() == k && y.len() == k);
    // SAFETY: `z`, `x`, `y`, and `m` are each `k` words, as `bn_mul_mont`
    // reads and writes for such a `k`, and it reads `n0` as one word.
    unsafe { bn_mul_mont(z.as_mut_ptr(), x.as_ptr(), y.as_ptr(), m.as_ptr(), &n0, k) };
}

/// Returns 1, which tells aws-lc's C it ran.
#[unsafe(naked)]
unsafe extern "C" fn bn_mul_mont(
    rp: *mut u64,
    ap: *const u64,
    bp: *const u64,
    np: *const u64,
    n0: *const u64,
    num: usize,
) -> i32 {
    #[cfg(not(target_vendor = "apple"))]
    core::arch::naked_asm!(include_str!("aws_lc/bn_mul_mont.linux.s"));
    #[cfg(target_vendor = "apple")]
    core::arch::naked_asm!(include_str!("aws_lc/bn_mul_mont.apple.s"));
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::super::{bignum_montmul, bignum_negmodinv};
    use super::*;

    /// xorshift64, so the moduli need no dependency.
    struct Rng(u64);

    impl Rng {
        fn words(&mut self, k: usize) -> [u64; 128] {
            let mut out = [0; 128];
            for word in &mut out[..k] {
                self.0 ^= self.0 << 13;
                self.0 ^= self.0 >> 7;
                self.0 ^= self.0 << 17;
                *word = self.0;
            }
            out
        }
    }

    // Every other test runs only the routine each width picks, so here
    // aws-lc's are checked against s2n-bignum's generic `bignum_montmul` at
    // widths that take each of its three paths, multiplying and squaring.
    #[test]
    fn matches_generic() {
        let mut rng = Rng(0x2545_f491_4f6c_dd1d);
        for k in [
            2, 3, 5, 8, 9, 12, 16, 17, 18, 24, 32, 33, 36, 48, 64, 96, 128,
        ] {
            for case in 0..16 {
                let mut m = rng.words(k);
                let m = &mut m[..k];
                // The widest modulus, the narrowest with its top word set,
                // and random ones.
                match case {
                    0 => m.fill(u64::MAX),
                    1 => {
                        m.fill(0);
                        m[k - 1] = 1;
                    }
                    _ => m[k - 1] |= 1 << 63,
                }
                m[0] |= 1;
                let mut n0 = [0];
                bignum_negmodinv::bignum_negmodinv(&mut n0, &m[..1]);
                let n0 = n0[0];

                // Operands below `m`, with its extremes: zero, and `m - 1`
                // for both.
                let below = |rng: &mut Rng| {
                    let mut x = rng.words(k);
                    x[k - 1] %= m[k - 1];
                    x
                };
                let (mut x, mut y) = (below(&mut rng), below(&mut rng));
                match case {
                    2 => x[..k].fill(0),
                    3 => {
                        x[..k].copy_from_slice(m);
                        x[0] -= 1;
                        y = x;
                    }
                    _ => {}
                }
                let (x, y) = (&x[..k], &y[..k]);

                let mut want = [0; 128];
                let want = &mut want[..k];
                let mut got = [0; 128];
                let got = &mut got[..k];

                bignum_montmul::bignum_montmul(want, x, y, m);
                mul_mont(got, x, y, m, n0);
                assert_eq!(want, got, "mul_mont, {k} words, case {case}");

                bignum_montmul::bignum_montmul(want, x, x, m);
                mul_mont(got, x, x, m, n0);
                assert_eq!(want, got, "mul_mont squaring, {k} words, case {case}");
            }
        }
    }
}
