// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! Montgomery multiplication modulo an RSA modulus or prime: from two words,
//! aws-lc's `bn_mul_mont`, which picks its own squaring or 4x routine by the
//! width as aws-lc does. On a Neoverse-N2 it measured faster than
//! s2n-bignum's generic `bignum_montmul` and `bignum_montsqr` in every width
//! class it branches on: 1.15x at 17 and 33 words, 1.6x at 20, and twice as
//! fast at 24, 48, 64, 96, and 128. It replaces s2n-bignum's Karatsuba
//! routines at 16 and 32 words too, where it signs RSA-2048 1.75x and
//! RSA-4096 1.6x as fast, and verifies RSA-1024 and RSA-2048 1.5x as fast.
//! The generic routines run only below two words.

/// `z = x * y / 2^(64k) mod m`, for `x` and `y` below `m`, where `k` is the
/// length of each and `n0` is `-m^-1 mod 2^64`.
pub(crate) fn mont_mul(z: &mut [u64], x: &[u64], y: &[u64], m: &[u64], n0: u64) {
    assert!(z.len() == m.len() && x.len() == m.len() && y.len() == m.len());
    match m.len() {
        k if k >= 2 => mul_mont(z, x, y, m, n0),
        _ => super::bignum_montmul::bignum_montmul(z, x, y, m),
    }
}

/// `z = x^2 / 2^(64k) mod m`, for `x` below `m`, where `k` is the length of
/// each and `n0` is `-m^-1 mod 2^64`.
pub(crate) fn mont_sqr(z: &mut [u64], x: &[u64], m: &[u64], n0: u64) {
    assert!(z.len() == m.len() && x.len() == m.len());
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
    unsafe {
        asm_call!(unsafe extern "C" bn_mul_mont(z.as_mut_ptr(), x.as_ptr(), y.as_ptr(), m.as_ptr(), &n0, k))
    };
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
    use proptest::prelude::*;

    use super::super::{bignum_montmul, bignum_negmodinv};
    use super::*;
    use crate::test::bignum::{below, div_r, mod_mul_vectors, modulus};

    /// `bn_mul_mont`'s product of `x` and `y`, and its square of `x`.
    fn mul_and_sqr(x: &[u64], y: &[u64], m: &[u64]) -> [Vec<u64>; 2] {
        let mut n0 = [0];
        bignum_negmodinv::bignum_negmodinv(&mut n0, &m[..1]);
        let (mut mul, mut sqr) = (vec![0; m.len()], vec![0; m.len()]);
        mul_mont(&mut mul, x, y, m, n0[0]);
        mul_mont(&mut sqr, x, x, m, n0[0]);
        [mul, sqr]
    }

    /// A modulus of a width taking each of `bn_mul_mont`'s paths, and two
    /// values below it.
    fn operands() -> impl Strategy<Value = (Vec<u64>, Vec<u64>, Vec<u64>)> {
        const WIDTHS: &[usize] = &[
            2, 3, 5, 8, 9, 12, 16, 17, 18, 24, 32, 33, 36, 48, 64, 96, 128,
        ];
        prop::sample::select(WIDTHS)
            .prop_flat_map(|k| modulus(64, k))
            .prop_flat_map(|m| (Just(m.clone()), below(64, m.clone()), below(64, m)))
    }

    proptest! {
        // Every other test runs only the routine each width picks, so here
        // aws-lc's are checked against s2n-bignum's generic
        // `bignum_montmul`, multiplying and squaring.
        #[test]
        fn matches_generic((m, x, y) in operands()) {
            let (mut mul, mut sqr) = (vec![0; m.len()], vec![0; m.len()]);
            bignum_montmul::bignum_montmul(&mut mul, &x, &y, &m);
            bignum_montmul::bignum_montmul(&mut sqr, &x, &x, &m);
            prop_assert_eq!(mul_and_sqr(&x, &y, &m), [mul, sqr]);
        }
    }

    #[test]
    fn aws_lc_mod_mul() {
        let mut ran = 0;
        for v in mod_mul_vectors().iter().filter(|v| v.m.len() >= 2) {
            let want = div_r(&v.want, &v.m);
            let [mul, sqr] = mul_and_sqr(&v.a, &v.b, &v.m);
            assert_eq!(mul, want, "{}", v.at);
            if v.a == v.b {
                assert_eq!(sqr, want, "squaring, {}", v.at);
            }
            ran += 1;
        }
        assert!(ran > 0);
    }
}
