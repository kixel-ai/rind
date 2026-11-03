// Copyright (c) 1998-2005 The OpenSSL Project.  All rights reserved.
// SPDX-License-Identifier: Apache-2.0

//! Exponentiation modulo an odd `m` in Montgomery form, by a 5-bit fixed
//! window whose table entry is gathered by reading every entry.
//!
//! This ports the `OPENSSL_BN_ASM_MONT5` branch of aws-lc's
//! `BN_mod_exp_mont_consttime`, from `exponentiation.c` at the commit
//! `admin/import-aws-lc` names, over its `x86_64-mont5` assembly, where it
//! displaces no verified code. Per width in words, from GitHub bench runs
//! 41401212831 and 41401209714, RSA signing on the same CPU before and
//! after:
//!
//! - A multiple of eight but 16 and 32 with BMI2 and ADX: `bn_power5` squares
//!   five times and multiplies by the gathered entry in one call, whose
//!   products skip the full reduction and copy that each `bn_sqr8x_mont`
//!   makes. It displaces only unverified code: aws-lc's `bn_sqr8x_mont` and
//!   `bn_mul4x_mont` and Graviola's gather. It saved 7-8% on Zen 3 without
//!   ADX or AVX2, and 0.2-2% with them on Zen 5.
//! - Otherwise: s2n-bignum's verified products, Karatsuba at 16 and 32 words
//!   with BMI2 and ADX, by rind's `mont_sqr` and `mont_mul`, after its
//!   verified `bignum_copy_row_from_table`. `bn_powerx5` trailed Karatsuba by
//!   13% at 16 words on Zen 5 and 1% at 32 on an i7-8700, and led by 6% at 16
//!   there. aws-lc's `bn_gather5` saved at most 5% at 17 and 20 words, and
//!   its `bn_mul_mont_gather5` jumps into its routine for a multiple of
//!   eight, so it can't be carried alone.
//!
//! aws-lc's routines are not formally verified: their correctness rests on
//! their use in OpenSSL and aws-lc, and on rind's tests of them against
//! s2n-bignum's `bignum_montmul`, Wycheproof, and aws-lc-rs. `bn_power5`'s
//! products are almost Montgomery: below `R`, not `m`, given inputs below
//! `R`. So the last product, by `R mod m`, is below `2m`, and one
//! subtraction reduces it.

use super::bignum_copy_row_from_table::bignum_copy_row_from_table;
use super::cpu::HaveBmi2Adx;
use super::mont::{mont_mul, mont_sqr};
use crate::low;

/// Word `j` of each of the 32 powers, as `bn_scatter5` lays out the table, so
/// a gather reads the same rows whichever power it takes.
#[derive(Clone, Copy)]
#[repr(C, align(64))]
struct Row([u64; 32]);

/// `z = x^e` in Montgomery form modulo `m`, for `x` and `one`, which is
/// `R mod m`, in Montgomery form below `m`, where `n0` is `-m^-1 mod 2^64`.
///
/// The instruction trace and memory addresses depend only on the lengths of
/// `e` and `m`.
pub(crate) fn mont_exp(z: &mut [u64], x: &[u64], one: &[u64], e: &[u64], m: &[u64], n0: u64) {
    mont_exp_by(z, x, one, e, m, n0, HaveBmi2Adx::check());
}

/// `mont_exp` by `mulx`, `adcx`, and `adox` given the proof of BMI2 and ADX.
fn mont_exp_by(
    z: &mut [u64],
    x: &[u64],
    one: &[u64],
    e: &[u64],
    m: &[u64],
    n0: u64,
    adx: Option<HaveBmi2Adx>,
) {
    let k = m.len();
    assert!(k >= 1 && z.len() == k && x.len() == k && one.len() == k);
    let Some(top) = (e.len() * 64).checked_sub(1) else {
        z.copy_from_slice(one);
        return;
    };

    // `powers` holds `x^i` at row `i`: each even power squares its half, and
    // each odd one multiplies the power below it by `x`.
    let mut powers = vec![0; 32 * k];
    powers[..k].copy_from_slice(one);
    powers[k..2 * k].copy_from_slice(x);
    for i in 2..32 {
        let (done, rest) = powers.split_at_mut(i * k);
        let row = |j: usize| &done[j * k..(j + 1) * k];
        match i % 2 {
            0 => mont_sqr(&mut rest[..k], row(i / 2), m, n0),
            _ => mont_mul(&mut rest[..k], row(i - 1), x, m, n0),
        }
    }
    let select = |z: &mut [u64], i: u64| bignum_copy_row_from_table(z, &powers, 32, k as u64, i);

    // The top window takes what is left above whole windows, starting `z`
    // at its power rather than squaring `one`.
    let mut lsb = top - top % 5;
    select(z, bits(e, lsb, top + 1 - lsb));

    // At 16 and 32 words with ADX, the verified Karatsuba products below run
    // instead.
    if k.is_multiple_of(8) && (adx.is_none() || !matches!(k, 16 | 32)) {
        let mut table = vec![Row([0; 32]); k];
        for (i, power) in powers.chunks_exact(k).enumerate() {
            for (row, &word) in table.iter_mut().zip(power) {
                row.0[i] = word;
            }
        }
        while lsb > 0 {
            lsb -= 5;
            power5(z, &table, m, n0, bits(e, lsb, 5), adx);
        }
        let mut almost = vec![0; k];
        mont_mul(&mut almost, z, one, m, n0);
        let ge = 1 - low::bignum_cmp_lt(&almost, m);
        low::bignum_optsub(z, &almost, m, ge);
    } else {
        let (mut spare, mut term) = (vec![0; k], vec![0; k]);
        while lsb > 0 {
            lsb -= 5;
            for _ in 0..5 {
                mont_sqr(&mut spare, z, m, n0);
                z.copy_from_slice(&spare);
            }
            select(&mut term, bits(e, lsb, 5));
            mont_mul(&mut spare, z, &term, m, n0);
            z.copy_from_slice(&spare);
        }
    }
}

/// The `width` bits of `e` from bit `lsb` up, which must lie within it. Only
/// the positions decide which words are read, so the bits may be secret.
fn bits(e: &[u64], lsb: usize, width: usize) -> u64 {
    let (word, shift) = (lsb / 64, lsb % 64);
    let mut bits = e[word] >> shift;
    if shift + width > 64 {
        bits |= e[word + 1] << (64 - shift);
    }
    bits & ((1 << width) - 1)
}

/// Squares `z` five times and multiplies it by power `i % 32` of `table`,
/// each product almost Montgomery modulo `m`, for a multiple of eight words,
/// by `mulx`, `adcx`, and `adox` given the proof of BMI2 and ADX.
fn power5(z: &mut [u64], table: &[Row], m: &[u64], n0: u64, i: u64, adx: Option<HaveBmi2Adx>) {
    let k = m.len();
    assert!(k.is_multiple_of(8) && z.len() == k && table.len() == k);
    // A mask rather than a check bounds the secret `i`, since a debug build
    // would branch on the check.
    let i = (i % 32) as i32;
    let z = z.as_mut_ptr();
    let (table, m) = (table.as_ptr().cast(), m.as_ptr());
    // SAFETY: `z` and `m` are each `k` words, a nonzero multiple of eight, as
    // each routine reads and writes for such a `k`, and it takes `z` as both
    // input and output, as aws-lc calls it. `table` is `k` rows of 32 words,
    // 64-byte aligned, which it reads whatever `i` is, and it reads `n0` as
    // one word. The token proves the CPU has the BMI2 and ADX
    // `bn_powerx5` runs.
    unsafe {
        match adx {
            Some(_) => bn_powerx5(z, z, table, m, &n0, k as i32, i),
            None => bn_power5(z, z, table, m, &n0, k as i32, i),
        }
    };
}

/// The gather's index increments, which the routines load 16-byte aligned.
#[repr(C, align(64))]
struct Inc([u32; 8]);

static INC: Inc = Inc(include!("aws_lc/x86_64-mont5.inc.rs"));

// The routines take the System V ABI on every OS, since their text is
// aws-lc's ELF and Mach-O flavors, which read their arguments from its
// registers.

macro_rules! mont5_routine {
    ($name:ident ($($arg:ident: $ty:ty),*) $(, $operand:ident = $sym:path)*) => {
        #[unsafe(naked)]
        unsafe extern "sysv64" fn $name($($arg: $ty),*) {
            #[cfg(not(target_vendor = "apple"))]
            core::arch::naked_asm!(
                include_str!(concat!("aws_lc/", stringify!($name), ".linux.s")),
                $($operand = sym $sym,)*
                options(att_syntax)
            );
            #[cfg(target_vendor = "apple")]
            core::arch::naked_asm!(
                include_str!(concat!("aws_lc/", stringify!($name), ".apple.s")),
                $($operand = sym $sym,)*
                options(att_syntax)
            );
        }
    };
}

mont5_routine!(
    bn_power5(rp: *mut u64, ap: *const u64, table: *const u64, np: *const u64, n0: *const u64, num: i32, power: i32),
    inc = INC,
    bn_sqr8x_internal = super::mont::bn_sqr8x_internal
);
mont5_routine!(
    bn_powerx5(rp: *mut u64, ap: *const u64, table: *const u64, np: *const u64, n0: *const u64, num: i32, power: i32),
    inc = INC,
    bn_sqrx8x_internal = super::mont::bn_sqrx8x_internal
);

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::super::adx_mux::tests::Rng;
    use super::super::{bignum_montifier, bignum_montmul, bignum_negmodinv};
    use super::*;

    // Every other test runs only the path this CPU picks, so here each is
    // checked against square-and-multiply over s2n-bignum's generic
    // `bignum_montmul`, with and without `mulx` where the CPU has BMI2 and
    // ADX, at widths either side of each multiple of eight.
    #[test]
    fn matches_square_and_multiply() {
        let adx = HaveBmi2Adx::check();
        let mut rng = Rng(0xbb67_ae85_84ca_a73b);
        for k in [1, 2, 7, 8, 9, 16, 17, 20, 24, 32, 33, 48, 64] {
            for case in 0..8 {
                let mut m = rng.words::<64>(64 * k as u32);
                let m = &mut m[..k];
                // The widest modulus, then the narrowest with its top word
                // set, which leaves `bn_power5`'s products furthest from
                // reduced, then random ones.
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

                let mut one = [0; 64];
                let one = &mut one[..k];
                one[0] = 1;
                let mut r = [0; 64];
                let r = &mut r[..k];
                let mut rr = [0; 64];
                bignum_montifier::bignum_montifier(&mut rr[..k], m, &mut [0; 64][..k]);
                bignum_montmul::bignum_montmul(r, &rr[..k], one, m);

                // A base below `m`, with its extremes, zero and `m - 1`, and
                // exponents of one word, of `k`, and of every bit set.
                let mut x = rng.words::<64>(64 * k as u32);
                x[k - 1] %= m[k - 1];
                match case {
                    2 => x[..k].fill(0),
                    3 => {
                        x[..k].copy_from_slice(m);
                        x[0] -= 1;
                    }
                    _ => {}
                }
                let x = &x[..k];
                let e = rng.words::<64>(64 * 64);
                let e = match case {
                    4 => &e[..1],
                    5 => &[u64::MAX; 64][..k],
                    _ => &e[..k],
                };

                let mut want = r.to_vec();
                for i in (0..e.len() * 64).rev() {
                    let mut t = vec![0; k];
                    bignum_montmul::bignum_montmul(&mut t, &want, &want, m);
                    if e[i / 64] >> (i % 64) & 1 == 1 {
                        bignum_montmul::bignum_montmul(&mut want, &t, x, m);
                    } else {
                        want = t;
                    }
                }

                let mut got = vec![0; k];
                mont_exp_by(&mut got, x, r, e, m, n0, None);
                assert_eq!(want, got, "{k} words, case {case}");
                if adx.is_some() {
                    mont_exp_by(&mut got, x, r, e, m, n0, adx);
                    assert_eq!(want, got, "mulx, {k} words, case {case}");
                }
            }
        }
    }
}
