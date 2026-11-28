// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! AES-GCM on VAES and VPCLMULQDQ with pyca/verified-garbage's
//! `vg_aes_gcm_{seal,open}_prepared_vaes_vpclmul_avx512`, and without
//! AVX-512 its `vg_aes_gcm_{seal,open}_prepared_vaes_vpclmul`, imported by
//! `admin/import-vg`, for the CPUs and lengths where they are faster than
//! BoringSSL's kernels.

use alloc::boxed::Box;
use core::ptr;
use core::sync::atomic::{AtomicPtr, Ordering};

use super::aes::HwKey;
use super::cpu::{
    HaveAvx512ForAesGcm, HaveAvx512ForVgAesGcm, HaveVaesAvx2ForAesGcm, HaveVaesAvx2ForVgAesGcm,
};
use super::vg::vg_aes_gcm_open_prepared_vaes_vpclmul::vg_aes_gcm_open_prepared_vaes_vpclmul;
use super::vg::vg_aes_gcm_open_prepared_vaes_vpclmul_avx512::vg_aes_gcm_open_prepared_vaes_vpclmul_avx512;
use super::vg::vg_aes_gcm_prepare_vpclmul::vg_aes_gcm_prepare_vpclmul;
use super::vg::vg_aes_gcm_prepare_vpclmul_avx512::vg_aes_gcm_prepare_vpclmul_avx512;
use super::vg::vg_aes_gcm_seal_prepared_vaes_vpclmul::vg_aes_gcm_seal_prepared_vaes_vpclmul;
use super::vg::vg_aes_gcm_seal_prepared_vaes_vpclmul_avx512::vg_aes_gcm_seal_prepared_vaes_vpclmul_avx512;
use crate::low;

/// Which of VG's routines run: its 512-bit ones or its 256-bit ones, each
/// with the proof that the CPU runs them. The 512-bit width is all-zero
/// bytes, as [`VgKey`]'s `Zeroable` needs.
#[derive(Clone, Copy)]
#[repr(u8)]
pub(crate) enum Width {
    Avx512(HaveAvx512ForVgAesGcm),
    Avx2(HaveVaesAvx2ForVgAesGcm),
}

/// VG's key context for one AES key, made on the first message long enough
/// to run VG's code: preparing it costs more than the rest of the key's
/// setup, which QUIC runs for every connection, and most keys never see such
/// a message.
///
/// All-zero bytes are the empty cell, so the key's whole-value wipe, after
/// [`Self::wipe`] has wiped and freed the context, leaves one. A wipe that
/// skips this cell's drop must call [`Self::wipe`] first, or it leaks the
/// context unwiped: see `GhashTable::release`. The context lives on the heap,
/// not in the key, because 1 KB more to move and wipe took every key's setup
/// and drop from about 80 ns to 105 ns on Zen 5.
pub(crate) struct LazyVgKey {
    ctx: AtomicPtr<VgKey>,
    width: Width,
}

impl LazyVgKey {
    /// An empty cell for VG's 512-bit AES-GCM, on the CPUs where it is
    /// faster: see [`HaveAvx512ForAesGcm::vg`].
    pub(crate) fn avx512(token: HaveAvx512ForAesGcm) -> Option<Self> {
        token.vg().map(|t| Self::with(Width::Avx512(t)))
    }

    /// An empty cell for VG's 256-bit AES-GCM, on the CPUs where it is
    /// faster: see [`HaveVaesAvx2ForAesGcm::vg`].
    pub(crate) fn avx2(token: HaveVaesAvx2ForAesGcm) -> Option<Self> {
        token.vg().map(|t| Self::with(Width::Avx2(t)))
    }

    /// An empty cell, on any CPU `width`'s routines run on.
    pub(crate) fn with(width: Width) -> Self {
        Self {
            ctx: AtomicPtr::new(ptr::null_mut()),
            width,
        }
    }

    /// The context for `key`, the key this cell was made for, making it if
    /// no call has.
    pub(crate) fn get(&self, key: &HwKey) -> &VgKey {
        let ctx = self.ctx.load(Ordering::Acquire);
        if !ctx.is_null() {
            // SAFETY: a non-null pointer is a leaked `Box` this cell owns,
            // freed only by `wipe`, which takes `&mut self`.
            return unsafe { &*ctx };
        }
        self.init(key)
    }

    #[cold]
    #[inline(never)]
    fn init(&self, key: &HwKey) -> &VgKey {
        let new = Box::into_raw(Box::new(VgKey::new(key, self.width)));
        // Two threads may race to make it: the first one stored wins, and
        // the other wipes and frees its own.
        match self
            .ctx
            .compare_exchange(ptr::null_mut(), new, Ordering::AcqRel, Ordering::Acquire)
        {
            // SAFETY: `new` is now this cell's, as above.
            Ok(_) => unsafe { &*new },
            Err(won) => {
                // SAFETY: `new` came from `Box::into_raw` and was never
                // shared; `won` is this cell's, as above.
                unsafe {
                    free(new);
                    &*won
                }
            }
        }
    }

    /// Wipes and frees the context, if any, leaving the cell empty.
    pub(crate) fn wipe(&mut self) {
        let ctx = core::mem::replace(self.ctx.get_mut(), ptr::null_mut());
        if !ctx.is_null() {
            // SAFETY: a non-null pointer is a leaked `Box` this cell owns,
            // and `&mut self` means no reference to it is live.
            unsafe { free(ctx) };
        }
    }
}

impl Drop for LazyVgKey {
    fn drop(&mut self) {
        self.wipe();
    }
}

/// Wipes and frees `ctx`.
///
/// # Safety
///
/// `ctx` came from `Box::into_raw`, and nothing else refers to it.
unsafe fn free(ctx: *mut VgKey) {
    // SAFETY: as the caller promises.
    let mut ctx = unsafe { Box::from_raw(ctx) };
    low::zeroise_value(&mut *ctx);
}

/// VG's prepared key context for one AES key: its key schedule, H, and 48
/// powers of H for the 512-bit routines or 16 for the 256-bit ones
/// (`VG.Spec.Gcm.PreparedRepr`). Aligned to a cache line, as VG's own key
/// is, so no read of the powers splits one.
#[repr(C, align(64))]
pub(crate) struct VgKey {
    ctx: [u64; 129],
    rounds: usize,
    width: Width,
}

// All-zero is the context of no key, which nothing reads, with the 512-bit
// width, whose token is zero-sized: no zeroed key is ever used.
impl low::Zeroable for VgKey {}

impl VgKey {
    /// The context for `key`.
    fn new(key: &HwKey, width: Width) -> Self {
        // VG's key context of `vg_aes_gcm_init` (`VG.Spec.Gcm.KeyRepr`): the
        // FIPS 197 key schedule, which rind's AES-NI round keys are, from
        // byte 0, and the hash subkey H, the zero block's encryption, at
        // bytes 240 to 255.
        let mut ctx = [0u64; 129];
        let (first, middle, last) = key.round_keys();
        let rounds = middle.len() + 1;
        for (i, rk) in [first].iter().chain(middle).chain([&last]).enumerate() {
            // SAFETY: every bit pattern of an `__m128i` is two valid words,
            // in the order x86_64 stores them.
            let rk: [u64; 2] = unsafe { core::mem::transmute(*rk) };
            ctx[2 * i..2 * i + 2].copy_from_slice(&rk);
        }
        let h = key.encrypt_block(&[0; 16]);
        let (h_lo, h_hi) = h.split_at(8);
        ctx[30] = u64::from_le_bytes(h_lo.try_into().unwrap());
        ctx[31] = u64::from_le_bytes(h_hi.try_into().unwrap());
        // SAFETY: `ctx` is 1032 readable and writable bytes, a key context
        // of `vg_aes_gcm_init` in its first 256, and overlaps nothing on the
        // stack; the token proves the CPU has SSSE3, PCLMULQDQ, AVX, AVX2,
        // VPCLMULQDQ, and, for the 512-bit routine, AVX-512 F.
        unsafe {
            match width {
                Width::Avx512(_) => {
                    asm_call!(unsafe extern "sysv64" vg_aes_gcm_prepare_vpclmul_avx512(&mut ctx))
                }
                Width::Avx2(_) => {
                    asm_call!(unsafe extern "sysv64" vg_aes_gcm_prepare_vpclmul(&mut ctx))
                }
            }
        };
        Self { ctx, rounds, width }
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
        // PCLMULQDQ, AVX, AVX2, VAES, VPCLMULQDQ, AES-NI, and, for the
        // 512-bit routine, AVX-512 F and BW.
        unsafe {
            match self.width {
                Width::Avx512(_) => {
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
                }
                Width::Avx2(_) => {
                    asm_call!(unsafe extern "sysv64" vg_aes_gcm_seal_prepared_vaes_vpclmul(
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
                }
            }
        };
        tag
    }

    /// Decrypts `inout` in place under `nonce` if `tag` is its tag over
    /// `aad` and the ciphertext, and returns whether it is, a secret. If not,
    /// `inout` keeps the ciphertext.
    ///
    /// VG's routine decrypts only once the tag matches, so it branches on the
    /// result: its contract (`VG.Spec.Gcm`'s `openLeak`) lets it reveal
    /// whether the open authenticated, as its ChaCha20-Poly1305's does, and
    /// `mid::aes_gcm` declassifies and branches on that result anyway.
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
            match self.width {
                Width::Avx512(_) => {
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
                }
                Width::Avx2(_) => {
                    asm_call!(unsafe extern "sysv64" vg_aes_gcm_open_prepared_vaes_vpclmul(
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
                }
            }
        };
        valid == 1
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::low::x86_64::aes::AesKey;

    // A thread that loses the race to make the context frees its own and
    // returns the winner's, which every later call returns too.
    #[test]
    fn loser_returns_the_winners_context() {
        let Some(token) = HaveAvx512ForAesGcm::check() else {
            return;
        };
        let key = AesKey::new(&[7; 16]);
        let AesKey::Hw(key) = &key else {
            unreachable!("AVX-512 CPUs have AES-NI");
        };
        let cell = LazyVgKey::with(Width::Avx512(token.vg_anywhere()));
        let won: *const VgKey = cell.get(key);
        assert_eq!(cell.init(key) as *const VgKey, won);
        assert_eq!(cell.get(key) as *const VgKey, won);
    }

    // Wiping frees the context and leaves the cell empty, as a whole-value
    // wipe would.
    #[test]
    fn wipe_empties_the_cell() {
        let Some(token) = HaveAvx512ForAesGcm::check() else {
            return;
        };
        let key = AesKey::new(&[7; 16]);
        let AesKey::Hw(key) = &key else {
            unreachable!("AVX-512 CPUs have AES-NI");
        };
        let mut cell = LazyVgKey::with(Width::Avx512(token.vg_anywhere()));
        let _ = cell.get(key);
        cell.wipe();
        assert!(cell.ctx.get_mut().is_null());
    }
}
