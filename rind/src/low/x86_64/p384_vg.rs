// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! P-384 on pyca/verified-garbage's proven routines (`super::vg`): `d·G`,
//! which ECDSA's key generation and signing take, and ECDSA verification.
//! Each measured faster than rind's on every x86_64 CPU. Each picks VG's BMI2
//! and ADX variant where the CPU has its features, as VG's own dispatcher
//! does.

use core::mem::MaybeUninit;

use super::cpu::{HaveAvx2Adx, HaveBmi2Adx};
use super::vg;

/// The 8 KiB of working space each routine takes, aligned to a cache line as
/// VG's own API aligns it. The routines accept any initial contents. Key
/// derivation leaves secrets in it, which AGENTS.md's wipe rule leaves
/// unwiped, as it is stack scratch.
#[repr(C, align(64))]
struct Scratch(MaybeUninit<[u64; 1024]>);

impl Scratch {
    fn new() -> Self {
        Self(MaybeUninit::uninit())
    }

    fn as_mut_ptr(&mut self) -> *mut [u64; 1024] {
        self.0.as_mut_ptr()
    }
}

/// `d·G` in X9.62's uncompressed encoding, in constant time, for `d` (big
/// endian) in [1, n); `None` for any other `d`.
pub(crate) fn public_key(d: &[u8; 48]) -> Option<[u8; 97]> {
    public_key_with(HaveAvx2Adx::check(), d)
}

/// [`public_key`] on the BMI2 and ADX variant if `adx` holds proof the CPU
/// has its features, or on the baseline one otherwise.
fn public_key_with(adx: Option<HaveAvx2Adx>, d: &[u8; 48]) -> Option<[u8; 97]> {
    use vg::{vg_ec_p384_public_key::*, vg_ec_p384_public_key_adx::*};
    let mut out = [0u8; 97];
    let mut scratch = Scratch::new();
    let (o, s) = (&mut out, scratch.as_mut_ptr());
    // SAFETY: every pointer is to a distinct Rust object valid for its size,
    // so none overlaps another, the stack, or the end of the address space.
    // `adx` proves the CPU has the ADX variant's features.
    let ok = unsafe {
        match adx {
            Some(_) => vg_ec_p384_public_key_adx(o, d, s),
            None => vg_ec_p384_public_key(o, d, s),
        }
    };
    // Whether `d` is in range is public: rind's keys and nonces always are.
    (crate::low::ct::into_public(ok) == 1).then_some(out)
}

/// FIPS 186-5's ECDSA verification (section 6.4.2) of the signature `sig`,
/// `r` then `s` big endian, of the message representative `e`, big endian,
/// under the X9.62 uncompressed key `public`. False for a key off the curve
/// or a coordinate not below p, and for `r` or `s` outside [1, n).
pub(crate) fn ecdsa_verify(public: &[u8; 97], e: &[u8; 48], sig: &[u8; 96]) -> bool {
    ecdsa_verify_with(HaveBmi2Adx::check(), public, e, sig)
}

/// [`ecdsa_verify`] on the BMI2 and ADX variant if `adx` holds proof the CPU
/// has its features, or on the baseline one otherwise.
fn ecdsa_verify_with(
    adx: Option<HaveBmi2Adx>,
    public: &[u8; 97],
    e: &[u8; 48],
    sig: &[u8; 96],
) -> bool {
    use vg::{vg_ecdsa_p384_verify::*, vg_ecdsa_p384_verify_adx::*};
    let mut scratch = Scratch::new();
    let (e, len, s) = (e.as_ptr(), e.len(), scratch.as_mut_ptr());
    // SAFETY: every pointer is to a distinct Rust object valid for its size,
    // `e` for `len` bytes, so none overlaps another, the stack, or the end of
    // the address space. `adx` proves the CPU has the ADX variant's
    // features.
    let ok = unsafe {
        match adx {
            Some(_) => vg_ecdsa_p384_verify_adx(public, e, len, sig, s),
            None => vg_ecdsa_p384_verify(public, e, len, sig, s),
        }
    };
    ok == 1
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::*;

    // The CPU picks one variant, so each runs here: the baseline one always,
    // and the ADX one where the CPU has it, on a secret scalar each, which
    // `admin/ctgrind` checks they handle in constant time.
    #[test]
    fn variants_agree() {
        let d = crate::low::ct::into_secret([0x5a; 48]);
        let base = public_key_with(None, &d).unwrap();
        if let Some(adx) = HaveAvx2Adx::check() {
            assert_eq!(public_key_with(Some(adx), &d), Some(base));
        }
        assert_eq!(public_key_with(None, &[0; 48]), None);
        assert_eq!(public_key_with(HaveAvx2Adx::check(), &[0xff; 48]), None);

        let (public, e, sig) = crate::test::p384_ecdsa_case();
        for adx in [None, HaveBmi2Adx::check()] {
            assert!(ecdsa_verify_with(adx, &public, &e, &sig));
            let mut bad = sig;
            bad[95] ^= 1;
            assert!(!ecdsa_verify_with(adx, &public, &e, &bad));
        }
    }
}
