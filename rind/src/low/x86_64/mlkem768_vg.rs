// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! ML-KEM-768 on pyca/verified-garbage's proven routines (`super::vg`).
//!
//! Each routine is a whole FIPS 203 operation, its hashing included. They
//! measured faster than rind's arithmetic at encapsulation on every x86_64
//! CPU, and at key generation and decapsulation with AVX-512, so those are
//! what rind takes. Each picks the widest variant the CPU runs, as VG's own
//! dispatcher does. A routine returns 0 only if a `SampleNTT` reached VG's
//! bound on its loop (FIPS 203 Appendix B), with probability below 2^-261;
//! these return `None` then, and the caller runs rind's arithmetic instead.

use core::mem::MaybeUninit;

use super::cpu::{HaveAvx, HaveAvx2, HaveAvx512ForVgMlKem};
use super::vg;

/// The 32 KiB of working space each routine takes, aligned to a cache line
/// as VG's own API aligns it. The routines accept any initial contents, and
/// leave each byte unchanged or zero.
#[repr(C, align(64))]
struct Scratch(MaybeUninit<[u64; 4096]>);

impl Scratch {
    fn new() -> Self {
        Self(MaybeUninit::uninit())
    }

    fn as_mut_ptr(&mut self) -> *mut [u64; 4096] {
        self.0.as_mut_ptr()
    }
}

/// Proof that VG's encapsulation runs here, as it does on every x86_64 CPU.
#[derive(Clone, Copy, Debug)]
pub(crate) struct Encaps(());

impl Encaps {
    pub(crate) fn check() -> Option<Self> {
        Some(Self(()))
    }

    /// FIPS 203's encapsulation key check (section 7.2): whether every
    /// coefficient `ek` encodes is below q.
    pub(crate) fn check_ek(self, ek: &[u8; 1184]) -> bool {
        // SAFETY: `ek` is valid for reads of its size, and a Rust object, so
        // it neither overlaps the stack nor wraps around the address space.
        // The AVX2 variant runs only where the CPU has AVX and AVX2.
        let ok = unsafe {
            match HaveAvx2::check() {
                Some(_) => vg::vg_mlkem768_check_ek_avx2::vg_mlkem768_check_ek_avx2(ek),
                None => vg::vg_mlkem768_check_ek::vg_mlkem768_check_ek(ek),
            }
        };
        ok == 1
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
        let mut scratch = Scratch::new();
        let (key_ptr, ct_ptr, s) = (&mut key, &mut ct, scratch.as_mut_ptr());
        // SAFETY: every pointer is to a distinct Rust object valid for its
        // size, so none overlaps another, the stack, or the end of the
        // address space. The caller checked `ek` and that `h` is its hash.
        // Each variant runs only where the CPU has its features: the AVX-512
        // one AVX-512 F, BW, and VL with AVX2, the AVX2 one AVX and AVX2, and
        // the AVX one AVX.
        let ok = unsafe {
            match (
                h,
                HaveAvx512ForVgMlKem::check(),
                HaveAvx2::check(),
                HaveAvx::check(),
            ) {
                (Some(h), Some(_), _, _) => {
                    vg::vg_mlkem768_encaps_h_avx512::vg_mlkem768_encaps_h_avx512(
                        ek, h, m, key_ptr, ct_ptr, s,
                    )
                }
                (Some(h), None, Some(_), _) => {
                    vg::vg_mlkem768_encaps_h_avx2::vg_mlkem768_encaps_h_avx2(
                        ek, h, m, key_ptr, ct_ptr, s,
                    )
                }
                (Some(h), None, None, Some(_)) => {
                    vg::vg_mlkem768_encaps_h_avx::vg_mlkem768_encaps_h_avx(
                        ek, h, m, key_ptr, ct_ptr, s,
                    )
                }
                (Some(h), None, None, None) => {
                    vg::vg_mlkem768_encaps_h::vg_mlkem768_encaps_h(ek, h, m, key_ptr, ct_ptr, s)
                }
                (None, Some(_), _, _) => vg::vg_mlkem768_encaps_avx512::vg_mlkem768_encaps_avx512(
                    ek, m, key_ptr, ct_ptr, s,
                ),
                (None, None, Some(_), _) => {
                    vg::vg_mlkem768_encaps_avx2::vg_mlkem768_encaps_avx2(ek, m, key_ptr, ct_ptr, s)
                }
                (None, None, None, Some(_)) => {
                    vg::vg_mlkem768_encaps_avx::vg_mlkem768_encaps_avx(ek, m, key_ptr, ct_ptr, s)
                }
                (None, None, None, None) => {
                    vg::vg_mlkem768_encaps::vg_mlkem768_encaps(ek, m, key_ptr, ct_ptr, s)
                }
            }
        };
        (ok == 1).then_some((key, ct))
    }
}

/// Proof that VG's key generation and decapsulation run here: with
/// AVX-512, where they measured faster than rind's.
#[derive(Clone, Copy, Debug)]
pub(crate) struct KeyPair(HaveAvx512ForVgMlKem);

impl KeyPair {
    pub(crate) fn check() -> Option<Self> {
        HaveAvx512ForVgMlKem::check().map(Self)
    }

    /// `ML-KEM.KeyGen_internal(d, z)` (FIPS 203 Algorithm 16), from the
    /// seed `d || z`: the decapsulation key, which holds the encapsulation
    /// key.
    pub(crate) fn keygen(self, seed: &[u8; 64]) -> Option<[u8; 2400]> {
        let mut ek = [0u8; 1184];
        let mut dk = [0u8; 2400];
        let mut scratch = Scratch::new();
        // SAFETY: every pointer is to a distinct Rust object valid for its
        // size, so none overlaps another, the stack, or the end of the
        // address space; `self` proves the CPU has the routine's features.
        let ok = unsafe {
            vg::vg_mlkem768_keygen_avx512::vg_mlkem768_keygen_avx512(
                seed,
                &mut ek,
                &mut dk,
                scratch.as_mut_ptr(),
            )
        };
        (ok == 1).then_some(dk)
    }

    /// `ML-KEM.Decaps_internal(dk, c)` (FIPS 203 Algorithm 18): the shared
    /// secret, or the implicit rejection key for a ciphertext that does not
    /// re-encrypt to itself.
    ///
    /// `dk` must be [`Self::keygen`]'s output, which VG's contract asks for.
    pub(crate) fn decaps(self, dk: &[u8; 2400], ct: &[u8; 1088]) -> Option<[u8; 32]> {
        let mut key = [0u8; 32];
        let mut scratch = Scratch::new();
        // SAFETY: as for `keygen`, and `keygen` wrote `dk`.
        let ok = unsafe {
            vg::vg_mlkem768_decaps_avx512::vg_mlkem768_decaps_avx512(
                dk,
                ct,
                &mut key,
                scratch.as_mut_ptr(),
            )
        };
        (ok == 1).then_some(key)
    }
}
