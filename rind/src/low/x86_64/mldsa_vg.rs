// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! ML-DSA signing on pyca/verified-garbage's proven routines
//! (`super::vg`), on CPUs without AVX2.
//!
//! Each routine is a whole FIPS 204 `Sign_internal` over the expanded private
//! key, which it expands itself on every call. Without AVX2 it measured
//! faster than rind's portable arithmetic at all three parameter sets, that
//! expansion included, so those CPUs take it. With AVX2 it measured slower
//! than s2n-bignum's routines, which sign with the expansion rind keeps.
//! A routine returns 0 only if its signing loop reached its bound, which
//! FIPS 204 Appendix C puts at probability below 2^-256.

use super::cpu::HaveAvx2;
use super::vg;
use crate::low;
use alloc::vec;

/// Proof that VG's signing runs here: the CPU has no AVX2.
#[derive(Clone, Copy, Debug)]
pub(crate) struct Sign(());

impl Sign {
    pub(crate) fn check() -> Option<Self> {
        match HaveAvx2::check() {
            Some(_) => None,
            None => Some(Self(())),
        }
    }

    /// Proof for a test, which runs VG's routines on a CPU with AVX2 too.
    #[cfg(test)]
    pub(crate) fn forced() -> Self {
        Self(())
    }

    /// `ML-DSA-44.Sign_internal(sk, M', rnd)` (FIPS 204 Algorithm 7) for the
    /// message `M'` that `mu` represents, or `None` if the signing loop
    /// reached its bound.
    pub(crate) fn sign44(
        self,
        sk: &[u8; 2560],
        mu: &[u8; 64],
        rnd: &[u8; 32],
    ) -> Option<[u8; 2420]> {
        sign::<2560, 2420, 9728>(vg::vg_mldsa44_sign::vg_mldsa44_sign, sk, mu, rnd)
    }

    /// [`Self::sign44`] at ML-DSA-65.
    pub(crate) fn sign65(
        self,
        sk: &[u8; 4032],
        mu: &[u8; 64],
        rnd: &[u8; 32],
    ) -> Option<[u8; 3309]> {
        sign::<4032, 3309, 12928>(vg::vg_mldsa65_sign::vg_mldsa65_sign, sk, mu, rnd)
    }

    /// [`Self::sign44`] at ML-DSA-87.
    pub(crate) fn sign87(
        self,
        sk: &[u8; 4896],
        mu: &[u8; 64],
        rnd: &[u8; 32],
    ) -> Option<[u8; 4627]> {
        sign::<4896, 4627, 18048>(vg::vg_mldsa87_sign::vg_mldsa87_sign, sk, mu, rnd)
    }
}

/// A routine's signature, for the lengths of one parameter set.
type Routine<const SK: usize, const SIG: usize, const SCRATCH: usize> =
    unsafe extern "sysv64" fn(
        sk: *const [u8; SK],
        mu: *const [u8; 64],
        rnd: *const [u8; 32],
        sig: *mut [u8; SIG],
        scratch: *mut [u64; SCRATCH],
    ) -> u32;

/// The words that pad working space so a cache line, which VG's own API
/// aligns it to, starts in it: a `Vec<u64>` is aligned to 8 bytes.
const PAD: usize = 7;

/// Runs `routine` on a key `sk` that rind loaded: its `s1` and `s2` were in
/// range, and its `t0` and `tr` were those its other parts compute.
///
/// The working space holds values derived from the key when the routine
/// returns, so it is wiped before it is freed.
fn sign<const SK: usize, const SIG: usize, const SCRATCH: usize>(
    routine: Routine<SK, SIG, SCRATCH>,
    sk: &[u8; SK],
    mu: &[u8; 64],
    rnd: &[u8; 32],
) -> Option<[u8; SIG]> {
    let mut sig = [0u8; SIG];
    // On the heap, since ML-DSA-87's is 141 KiB, and over-allocated to align.
    let mut space = vec![0u64; SCRATCH + PAD];
    let start = space.as_ptr().align_offset(64);
    let scratch = space[start..start + SCRATCH]
        .as_mut_ptr()
        .cast::<[u64; SCRATCH]>();
    // SAFETY: every pointer is to a distinct Rust object valid for its size,
    // so none overlaps another, the stack, or the end of the address space.
    // The routine needs no CPU feature, and `sk` is a loaded key.
    let ok = unsafe { routine(sk, mu, rnd, &mut sig, scratch) };
    low::zeroise(&mut space);
    // Whether the loop reached its bound is public, as which attempt signs is.
    (low::ct::into_public(ok) == 1).then_some(sig)
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::*;

    // VG's signing is for the CPUs without AVX2, and only them.
    #[test]
    fn runs_without_avx2() {
        assert_eq!(Sign::check().is_some(), HaveAvx2::check().is_none());
    }
}
