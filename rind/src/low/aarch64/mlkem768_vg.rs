// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! ML-KEM-768 on pyca/verified-garbage's proven routines (`super::vg`).
//!
//! Each routine is a whole FIPS 203 operation, its hashing included. Its
//! encapsulation measured faster than rind's with the SHA-3 instructions, so
//! rind takes it there; without them, and for key generation and
//! decapsulation, rind's own was faster. A routine returns 0 only if a
//! `SampleNTT` reached VG's bound on its loop (FIPS 203 Appendix B), with
//! probability below 2^-261; these return `None` then, and the caller runs
//! rind's arithmetic instead.

use core::mem::MaybeUninit;

use super::cpu::HaveSha3;
use super::vg;
pub(crate) use crate::low::generic::mlkem768_vg::KeyPair;

/// The 32 KiB of working space each routine takes, aligned to a cache line
/// as VG's own API aligns it. The routines accept any initial contents, and
/// leave each byte unchanged or zero.
#[repr(C, align(64))]
struct Scratch(MaybeUninit<[u64; 4096]>);

/// Proof that VG's encapsulation runs here: the CPU has the SHA-3
/// instructions.
#[derive(Clone, Copy, Debug)]
pub(crate) struct Encaps(HaveSha3);

impl Encaps {
    pub(crate) fn check() -> Option<Self> {
        HaveSha3::check().map(Self)
    }

    /// FIPS 203's encapsulation key check (section 7.2): whether every
    /// coefficient `ek` encodes is below q.
    pub(crate) fn check_ek(self, ek: &[u8; 1184]) -> bool {
        // SAFETY: `ek` is valid for reads of its size, and a Rust object, so
        // it neither overlaps the stack nor wraps around the address space.
        unsafe { vg::vg_mlkem768_check_ek::vg_mlkem768_check_ek(ek) == 1 }
    }

    /// `ML-KEM.Encaps_internal(ek, m)` (FIPS 203 Algorithm 17): the shared
    /// secret and ciphertext, given `H(ek)` as `h` where the caller has it.
    ///
    /// `ek` must have passed [`Self::check_ek`], and `h` be its hash.
    pub(crate) fn encaps(
        self,
        ek: &[u8; 1184],
        h: Option<&[u8; 32]>,
        m: &[u8; 32],
    ) -> Option<([u8; 32], [u8; 1088])> {
        let mut key = [0u8; 32];
        let mut ct = [0u8; 1088];
        let mut scratch = Scratch(MaybeUninit::uninit());
        let (key_ptr, ct_ptr, s) = (&mut key, &mut ct, scratch.0.as_mut_ptr());
        // SAFETY: every pointer is to a distinct Rust object valid for its
        // size, so none overlaps another, the stack, or the end of the
        // address space. The caller checked `ek` and that `h` is its hash.
        // `self` proves the CPU has the SHA-3 instructions both variants
        // need. Apple's cores take the variant that also runs Keccak on them,
        // as VG's dispatcher picks.
        let ok = unsafe {
            match h {
                #[cfg(target_vendor = "apple")]
                Some(h) => vg::vg_mlkem768_encaps_h_x2_sha3_keccak_sha3::vg_mlkem768_encaps_h_x2_sha3_keccak_sha3(ek, h, m, key_ptr, ct_ptr, s),
                #[cfg(target_vendor = "apple")]
                None => vg::vg_mlkem768_encaps_x2_sha3_keccak_sha3::vg_mlkem768_encaps_x2_sha3_keccak_sha3(ek, m, key_ptr, ct_ptr, s),
                #[cfg(not(target_vendor = "apple"))]
                Some(h) => vg::vg_mlkem768_encaps_h_x2_sha3::vg_mlkem768_encaps_h_x2_sha3(ek, h, m, key_ptr, ct_ptr, s),
                #[cfg(not(target_vendor = "apple"))]
                None => vg::vg_mlkem768_encaps_x2_sha3::vg_mlkem768_encaps_x2_sha3(ek, m, key_ptr, ct_ptr, s),
            }
        };
        (ok == 1).then_some((key, ct))
    }
}
