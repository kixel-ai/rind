// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! AES-GCM on AVX-512, VAES, and VPCLMULQDQ with pyca/verified-garbage's
//! `vg_aes_gcm_{seal,open}_prepared_vaes_vpclmul_avx512`, imported by
//! `admin/import-vg`, for the lengths where they are faster than rind's own
//! AVX-512 path.

use super::aes::HwKey;
use super::cpu::HaveAvx512ForVgAesGcm;
use super::vg::vg_aes_gcm_open_prepared_vaes_vpclmul_avx512::vg_aes_gcm_open_prepared_vaes_vpclmul_avx512;
use super::vg::vg_aes_gcm_prepare_vpclmul_avx512::vg_aes_gcm_prepare_vpclmul_avx512;
use super::vg::vg_aes_gcm_seal_prepared_vaes_vpclmul_avx512::vg_aes_gcm_seal_prepared_vaes_vpclmul_avx512;

/// VG's prepared key context for one AES key: its key schedule, H, and 48
/// powers of H (`VG.Spec.Gcm.PreparedRepr`). Aligned to a cache line, as
/// VG's own key is, so no read of the powers splits one.
#[repr(C, align(64))]
pub(crate) struct VgKey {
    ctx: [u64; 129],
    rounds: usize,
    _token: HaveAvx512ForVgAesGcm,
}

impl VgKey {
    /// The context for `key`, whose hash subkey is `h`, the encryption of
    /// the zero block under it.
    pub(crate) fn new(key: &HwKey, h: &[u8; 16], token: HaveAvx512ForVgAesGcm) -> Self {
        // VG's key context of `vg_aes_gcm_init` (`VG.Spec.Gcm.KeyRepr`): the
        // FIPS 197 key schedule, which rind's AES-NI round keys are, from
        // byte 0, and H at bytes 240 to 255.
        let mut ctx = [0u64; 129];
        let (first, middle, last) = key.round_keys();
        let rounds = middle.len() + 1;
        for (i, rk) in [first].iter().chain(middle).chain([&last]).enumerate() {
            // SAFETY: every bit pattern of an `__m128i` is two valid words,
            // in the order x86_64 stores them.
            let rk: [u64; 2] = unsafe { core::mem::transmute(*rk) };
            ctx[2 * i..2 * i + 2].copy_from_slice(&rk);
        }
        let (h_lo, h_hi) = h.split_at(8);
        ctx[30] = u64::from_le_bytes(h_lo.try_into().unwrap());
        ctx[31] = u64::from_le_bytes(h_hi.try_into().unwrap());
        // SAFETY: `ctx` is 1032 readable and writable bytes, a key context
        // of `vg_aes_gcm_init` in its first 256, and overlaps nothing on the
        // stack; the token proves the CPU has SSSE3, PCLMULQDQ, AVX, AVX2,
        // VPCLMULQDQ, and AVX-512 F.
        unsafe { asm_call!(unsafe extern "sysv64" vg_aes_gcm_prepare_vpclmul_avx512(&mut ctx)) };
        Self {
            ctx,
            rounds,
            _token: token,
        }
    }

    /// Encrypts `inout` in place under `nonce`, and returns its tag over
    /// `aad` and the ciphertext.
    pub(crate) fn seal(&self, nonce: &[u8; 12], aad: &[u8], inout: &mut [u8]) -> [u8; 16] {
        let mut tag = [0u8; 16];
        let (data, len) = (inout.as_mut_ptr(), inout.len());
        // SAFETY: `self.ctx` is a prepared key context for `self.rounds`
        // rounds, 10, 12, or 14 (`new`). Each pointer is to a distinct Rust
        // object of the length the routine reads or writes, none of which
        // overlaps the stack below the return address or wraps the address
        // space, as no object does. The token proves the CPU has SSSE3,
        // PCLMULQDQ, AVX, AVX2, AVX-512 F and BW, VAES, VPCLMULQDQ, and
        // AES-NI.
        unsafe {
            asm_call!(unsafe extern "sysv64" vg_aes_gcm_seal_prepared_vaes_vpclmul_avx512(
                &self.ctx,
                self.rounds,
                nonce.as_ptr(),
                nonce.len(),
                aad.as_ptr(),
                aad.len(),
                data,
                len,
                &mut tag,
            ))
        };
        tag
    }

    /// Decrypts `inout` in place under `nonce` if `tag` is its tag over
    /// `aad` and the ciphertext, and returns whether it is, a secret. If not,
    /// `inout` keeps the ciphertext.
    pub(crate) fn open(
        &self,
        nonce: &[u8; 12],
        aad: &[u8],
        inout: &mut [u8],
        tag: &[u8; 16],
    ) -> bool {
        let (data, len) = (inout.as_mut_ptr(), inout.len());
        // SAFETY: as in `seal`, with `tag` 16 readable bytes.
        let valid = unsafe {
            asm_call!(unsafe extern "sysv64" vg_aes_gcm_open_prepared_vaes_vpclmul_avx512(
                &self.ctx,
                self.rounds,
                nonce.as_ptr(),
                nonce.len(),
                aad.as_ptr(),
                aad.len(),
                data,
                len,
                tag.as_ptr(),
                tag.len(),
            ))
        };
        valid == 1
    }
}
