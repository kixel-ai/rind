// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! The steps of P-256's generator multiplication, using aws-lc's
//! `p256-x86_64-asm` routines, which aws-lc's `ecp_nistz256_point_mul_base`
//! runs over its 7-bit generator table.
//!
//! The assembly is aws-lc's, imported by `admin/import-aws-lc`. The row scan
//! reads all 64 points of a row and masks off all but one, and the mixed
//! addition selects its special cases with masks, so neither branches on or
//! indexes by its inputs. Neither is formally verified: their correctness
//! rests on their use and testing in OpenSSL, BoringSSL, and aws-lc, and on
//! rind's tests of them against s2n-bignum's verified arithmetic,
//! Wycheproof, and aws-lc-rs.

use super::cpu::{HaveAvx2, HaveBmi2Adx};

/// One row of the generator table: 64 affine points with Montgomery
/// coordinates, `x` then `y`, each 4 little-endian words. The scans load it
/// with `movdqa` and `vmovdqa`.
#[repr(C, align(64))]
pub(crate) struct P256GeneratorRow(pub(crate) [u64; 512]);

impl core::ops::Deref for P256GeneratorRow {
    type Target = [u64; 512];

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

/// Returns `row`'s point `index - 1`, or zeros for an `index` of 0, reading
/// every point.
pub(crate) fn p256_select_w7(row: &P256GeneratorRow, index: u8) -> [u64; 8] {
    debug_assert!(index <= 64);
    let mut r = [0; 8];
    // SAFETY: `r` is one writable point and `row` 64 readable points, as
    // aligned as the routines load them. The AVX2 routine runs only where the
    // token proves AVX2, and the other needs only SSE2.
    unsafe {
        match HaveAvx2::check() {
            Some(_) => ecp_nistz256_avx2_select_w7(&mut r, row, index.into()),
            None => ecp_nistz256_select_w7(&mut r, row, index.into()),
        }
    }
    r
}

/// Returns the Jacobian `p1` plus the affine `p2`, both in Montgomery form.
///
/// Either may be infinity: `p1` with a zero `z`, `p2` as all zeros. They must
/// not be the same point, which this does not double.
pub(crate) fn p256_point_add_affine(p1: &[u64; 12], p2: &[u64; 8]) -> [u64; 12] {
    let mut r = [0; 12];
    // SAFETY: `r` is one writable Jacobian point, `p1` one readable Jacobian
    // point, and `p2` one readable affine point; the routines load them
    // unaligned. The BMI2 and ADX routine runs only where the token proves
    // both, and the other needs only SSE2.
    unsafe {
        match HaveBmi2Adx::check() {
            Some(_) => ecp_nistz256_point_add_affinex(&mut r, p1, p2),
            None => ecp_nistz256_point_add_affine(&mut r, p1, p2),
        }
    }
    r
}

/// Sets `p3` to `2 * p1`, for a Jacobian point in Montgomery form: by
/// s2n-bignum's verified `p256_montjdouble` with BMI2 and ADX, and otherwise
/// by aws-lc's doubling, which measured faster than s2n-bignum's `_alt`.
pub(crate) fn p256_montjdouble(p3: &mut [u64; 12], p1: &[u64; 12]) {
    match HaveBmi2Adx::check() {
        Some(_) => super::p256_montjdouble::p256_montjdouble(p3, p1),
        // SAFETY: `p3` is one writable Jacobian point and `p1` one readable
        // one, which the routine loads unaligned. It needs only SSE2.
        None => unsafe { ecp_nistz256_point_double(p3, p1) },
    }
}

/// Sets `p3` to `p1 + p2`, for Jacobian points in Montgomery form that are
/// not equal or at infinity, which s2n-bignum's routine does not handle: by
/// its verified `p256_montjadd` with BMI2 and ADX, and otherwise by aws-lc's
/// addition, which measured faster than s2n-bignum's `_alt`.
pub(crate) fn p256_montjadd(p3: &mut [u64; 12], p1: &[u64; 12], p2: &[u64; 12]) {
    match HaveBmi2Adx::check() {
        Some(_) => super::p256_montjadd::p256_montjadd(p3, p1, p2),
        // SAFETY: `p3` is one writable Jacobian point and `p1` and `p2`
        // readable ones, which the routine loads unaligned. It needs only
        // SSE2.
        None => unsafe { ecp_nistz256_point_add(p3, p1, p2) },
    }
}

/// aws-lc's `.Lpoly`, the field prime, as the multiplications load it.
#[repr(C, align(16))]
struct Poly([u64; 4]);

/// aws-lc's `.LOne`, `.LTwo`, and `.LThree`, the scans' counters, as aligned
/// as the AVX2 scan loads them.
#[repr(C, align(32))]
struct One([u32; 24]);

/// aws-lc's `.LONE_mont`, one in Montgomery form, which the addition masks
/// with `pand`. It runs on through `.Lord` and `.LordK`, which the import
/// keeps but these routines never read.
#[repr(C, align(16))]
struct OneMont([u64; 9]);

static POLY: Poly = Poly(include!("aws_lc/p256-x86_64-asm.poly.rs"));
static ONE: One = One(include!("aws_lc/p256-x86_64-asm.One.rs"));
static ONE_MONT: OneMont = OneMont(include!("aws_lc/p256-x86_64-asm.ONE_mont.rs"));

/// Defines a naked function running an imported routine, which reaches its
/// tables and helpers through the `sym` operands listed. Each takes the System
/// V ABI on every OS, since its text is aws-lc's ELF and Mach-O flavors.
macro_rules! p256_routine {
    ($name:ident($($arg:ident: $ty:ty),*) { $($op:ident = $sym:ident),* }) => {
        #[unsafe(naked)]
        unsafe extern "sysv64" fn $name($($arg: $ty),*) {
            #[cfg(not(target_vendor = "apple"))]
            core::arch::naked_asm!(
                include_str!(concat!("aws_lc/", stringify!($name), ".linux.s"))
                $(, $op = sym $sym)*,
                options(att_syntax),
            );
            #[cfg(target_vendor = "apple")]
            core::arch::naked_asm!(
                include_str!(concat!("aws_lc/", stringify!($name), ".apple.s"))
                $(, $op = sym $sym)*,
                options(att_syntax),
            );
        }
    };
}

p256_routine!(ecp_nistz256_select_w7(out: *mut [u64; 8], row: *const P256GeneratorRow, index: u32) {
    One = ONE
});
p256_routine!(ecp_nistz256_avx2_select_w7(out: *mut [u64; 8], row: *const P256GeneratorRow, index: u32) {
    One = ONE
});
p256_routine!(ecp_nistz256_point_add_affine(r: *mut [u64; 12], a: *const [u64; 12], b: *const [u64; 8]) {
    ONE_mont = ONE_MONT,
    ecp_nistz256_mul_montq = ecp_nistz256_mul_montq,
    ecp_nistz256_sqr_montq = ecp_nistz256_sqr_montq,
    ecp_nistz256_sub_fromq = ecp_nistz256_sub_fromq,
    ecp_nistz256_subq = ecp_nistz256_subq
});
p256_routine!(ecp_nistz256_point_add_affinex(r: *mut [u64; 12], a: *const [u64; 12], b: *const [u64; 8]) {
    ONE_mont = ONE_MONT,
    ecp_nistz256_mul_montx = ecp_nistz256_mul_montx,
    ecp_nistz256_sqr_montx = ecp_nistz256_sqr_montx,
    ecp_nistz256_sub_fromx = ecp_nistz256_sub_fromx,
    ecp_nistz256_subx = ecp_nistz256_subx
});

p256_routine!(ecp_nistz256_point_double(r: *mut [u64; 12], a: *const [u64; 12]) {
    poly = POLY,
    ecp_nistz256_add_toq = ecp_nistz256_add_toq,
    ecp_nistz256_mul_by_2q = ecp_nistz256_mul_by_2q,
    ecp_nistz256_mul_montq = ecp_nistz256_mul_montq,
    ecp_nistz256_sqr_montq = ecp_nistz256_sqr_montq,
    ecp_nistz256_sub_fromq = ecp_nistz256_sub_fromq,
    ecp_nistz256_subq = ecp_nistz256_subq
});
p256_routine!(ecp_nistz256_point_add(r: *mut [u64; 12], a: *const [u64; 12], b: *const [u64; 12]) {
    poly = POLY,
    ecp_nistz256_add_toq = ecp_nistz256_add_toq,
    ecp_nistz256_mul_by_2q = ecp_nistz256_mul_by_2q,
    ecp_nistz256_mul_montq = ecp_nistz256_mul_montq,
    ecp_nistz256_sqr_montq = ecp_nistz256_sqr_montq,
    ecp_nistz256_sub_fromq = ecp_nistz256_sub_fromq,
    ecp_nistz256_subq = ecp_nistz256_subq
});

// The routines' helpers, which pass their arguments in registers of their
// own choosing rather than by the C ABI, so only the routines call them.
p256_routine!(ecp_nistz256_add_toq() {});
p256_routine!(ecp_nistz256_mul_by_2q() {});
p256_routine!(ecp_nistz256_mul_montq() { poly = POLY });
p256_routine!(ecp_nistz256_sqr_montq() { poly = POLY });
p256_routine!(ecp_nistz256_sub_fromq() {});
p256_routine!(ecp_nistz256_subq() {});
p256_routine!(ecp_nistz256_mul_montx() { poly = POLY });
p256_routine!(ecp_nistz256_sqr_montx() { poly = POLY });
p256_routine!(ecp_nistz256_sub_fromx() {});
p256_routine!(ecp_nistz256_subx() {});

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::super::adx_mux::tests::Rng;
    use super::*;

    // The other tests run only the twin this CPU picks, so each pair is
    // checked against each other here, where the CPU runs both, as are
    // aws-lc's doubling and addition against s2n-bignum's verified ones.
    #[test]
    fn twins_agree() {
        let mut rng = Rng(0x243f_6a88_85a3_08d3);
        let mut row = P256GeneratorRow([0; 512]);
        for word in row.0.iter_mut() {
            *word = rng.next();
        }

        if HaveAvx2::check().is_some() {
            for index in 0..=64 {
                let (mut sse2, mut avx2) = ([1; 8], [1; 8]);
                // SAFETY: as in `p256_select_w7`, on a CPU with AVX2.
                unsafe {
                    ecp_nistz256_select_w7(&mut sse2, &row, index);
                    ecp_nistz256_avx2_select_w7(&mut avx2, &row, index);
                }
                assert_eq!(sse2, avx2);
                let want = match index {
                    0 => [0; 8],
                    i => row.0[(i as usize - 1) * 8..][..8].try_into().unwrap(),
                };
                assert_eq!(sse2, want);
            }
        }

        if HaveBmi2Adx::check().is_some() {
            // The addition is straight-line field arithmetic, so off-curve
            // points exercise it as well as real ones, and a zero `z` or
            // `p2` its infinity cases.
            for i in 0..256 {
                let mut p1: [u64; 12] = rng.field(255);
                let mut p2: [u64; 8] = rng.field(255);
                match i % 8 {
                    0 => p1[8..].fill(0),
                    1 => p2.fill(0),
                    _ => {}
                }
                let (mut mulq, mut mulx) = ([0; 12], [0; 12]);
                // SAFETY: as in `p256_point_add_affine`, on a CPU with BMI2
                // and ADX.
                unsafe {
                    ecp_nistz256_point_add_affine(&mut mulq, &p1, &p2);
                    ecp_nistz256_point_add_affinex(&mut mulx, &p1, &p2);
                }
                assert_eq!(mulq, mulx);

                // Neither is at infinity, nor are they equal, which
                // s2n-bignum's addition requires.
                let mut p2: [u64; 12] = rng.field(255);
                p1[8] |= 1;
                p2[8] |= 1;
                let (mut aws_lc, mut s2n) = ([0; 12], [0; 12]);
                // SAFETY: as in `p256_montjdouble`.
                unsafe { ecp_nistz256_point_double(&mut aws_lc, &p1) };
                super::super::p256_montjdouble::p256_montjdouble(&mut s2n, &p1);
                assert_eq!(aws_lc, s2n);
                // SAFETY: as in `p256_montjadd`.
                unsafe { ecp_nistz256_point_add(&mut aws_lc, &p1, &p2) };
                super::super::p256_montjadd::p256_montjadd(&mut s2n, &p1, &p2);
                assert_eq!(aws_lc, s2n);
            }
        }
    }
}
