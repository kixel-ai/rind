// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! AES-GCM on AVX and MOVBE without VAES, with HACL*'s Vale AES-GCM,
//! imported by `admin/import-hacl`, which interleaves AES-CTR and GHASH over
//! six blocks at a time as OpenSSL's `aesni_gcm` does.
//!
//! Vale proves that `gcm{128,256}_{encrypt,decrypt}_opt` compute AES-GCM, tag
//! check included, for every AAD and message under 2^32 bytes, in place, from
//! the round keys of its key expansion, the GHASH key powers of its
//! `keyhash_init`, and the counter block of its `compute_iv`, which rind runs
//! for them. The Rust here does what EverCrypt's proven Low* wrapper,
//! `Vale.Wrapper.X64.GCMencryptOpt`, does around them: it copies the partial
//! blocks of the message and AAD to scratch, and picks the six-block loop's
//! share of the message.

use core::arch::x86_64::__m128i;

use super::aes::HwKey;
use super::cpu::{HaveAvx512ForAesGcm, HaveAvxMovbeForAesGcm, HaveVaesAvx2ForAesGcm};

/// Where the CPU runs Vale's AES-GCM: with AVX and MOVBE, but without the
/// VAES that BoringSSL's kernels need.
pub(crate) fn token() -> Option<HaveAvxMovbeForAesGcm> {
    match (HaveAvx512ForAesGcm::check(), HaveVaesAvx2ForAesGcm::check()) {
        (None, None) => HaveAvxMovbeForAesGcm::check(),
        _ => None,
    }
}

/// The routines with the GHASH key powers they read.
pub(crate) struct AvxKernel {
    hkeys: [__m128i; 8],
    _token: HaveAvxMovbeForAesGcm,
}

impl AvxKernel {
    /// The kernel for `key`, whose round keys [`expand_128`] or
    /// [`expand_256`] made.
    pub(crate) fn new(key: &HwKey, token: HaveAvxMovbeForAesGcm) -> Self {
        let mut hkeys = [0u8; 128];
        // SAFETY: `key` is its round keys, which the routines read, and
        // `hkeys` the 128 bytes they write. The token proves the CPU has
        // AES-NI, PCLMULQDQ, and AVX.
        unsafe {
            match key {
                HwKey::Aes128(_) => aes128_keyhash_init(key.as_aes_key(), hkeys.as_mut_ptr()),
                HwKey::Aes256(_) => aes256_keyhash_init(key.as_aes_key(), hkeys.as_mut_ptr()),
            };
        }
        Self {
            // SAFETY: any 128 bytes are eight vectors.
            hkeys: unsafe { core::mem::transmute::<[u8; 128], [__m128i; 8]>(hkeys) },
            _token: token,
        }
    }

    /// Encrypts `inout` in place under `nonce`, and returns its tag. `aad`
    /// and `inout` are each shorter than 2^32 bytes.
    pub(crate) fn seal(
        &self,
        key: &HwKey,
        nonce: &[u8; 12],
        aad: &[u8],
        inout: &mut [u8],
    ) -> [u8; 16] {
        let mut tag = [0u8; 16];
        self.cipher::<true>(key, nonce, aad, inout, &mut tag);
        tag
    }

    /// Decrypts `inout` in place under `nonce`, and returns whether `tag` is
    /// its tag. `aad` and `inout` are each shorter than 2^32 bytes.
    pub(crate) fn open(
        &self,
        key: &HwKey,
        nonce: &[u8; 12],
        aad: &[u8],
        inout: &mut [u8],
        tag: &[u8; 16],
    ) -> bool {
        let mut tag = *tag;
        self.cipher::<false>(key, nonce, aad, inout, &mut tag) == 0
    }

    /// Runs the encrypting or decrypting routine, which writes the tag to, or
    /// checks it against, `tag`, and returns the decrypting one's result.
    fn cipher<const ENC: bool>(
        &self,
        key: &HwKey,
        nonce: &[u8; 12],
        aad: &[u8],
        inout: &mut [u8],
        tag: &mut [u8; 16],
    ) -> u64 {
        debug_assert!(u32::try_from(aad.len()).is_ok() && u32::try_from(inout.len()).is_ok());
        let hkeys = self.hkeys.as_ptr().cast::<u8>();

        // The counter block, which `compute_iv` reads a 96-bit nonce from
        // and writes over.
        let mut iv = [0u8; 16];
        iv[..12].copy_from_slice(nonce);
        let iv = iv.as_mut_ptr();
        // SAFETY: `nonce` is 12 bytes, `iv` 16 writable ones, and `hkeys`
        // the GHASH key powers. The token proves the CPU has PCLMULQDQ and
        // AVX.
        unsafe { compute_iv_stdcall(nonce.as_ptr(), 12, 0, iv, iv, hkeys) };

        // The AAD's and message's partial blocks, then the routines' own.
        let mut scratch = [0u8; 16 + 16 + 144];
        let (aad_partial, rest) = scratch.split_at_mut(16);
        let (partial, scratch) = rest.split_at_mut(16);
        let aad_whole = aad.len() / 16 * 16;
        aad_partial[..aad.len() - aad_whole].copy_from_slice(&aad[aad_whole..]);
        let len = inout.len();
        let (blocks, tail) = inout.split_at_mut(len / 16 * 16);
        partial[..tail.len()].copy_from_slice(tail);

        // The six-block loop's share, which must be 18 blocks or more to
        // encrypt, or 6 to decrypt.
        let six = match blocks.len() / 96 * 6 {
            n if n >= if ENC { 18 } else { 6 } => n,
            _ => 0,
        };
        let ones = blocks.len() / 16 - six;
        let blocks = blocks.as_mut_ptr();
        let routine: Aead = match (ENC, key) {
            (true, HwKey::Aes128(_)) => gcm128_encrypt_opt,
            (true, HwKey::Aes256(_)) => gcm256_encrypt_opt,
            (false, HwKey::Aes128(_)) => gcm128_decrypt_opt,
            (false, HwKey::Aes256(_)) => gcm256_decrypt_opt,
        };
        // SAFETY: the routine reads `aad`'s whole blocks and `aad_partial`,
        // and reads and writes in place `inout`'s whole blocks, the first
        // `six` in its six-block loop and the `ones` after them one at a
        // time, then `partial`. `key` is its round keys, `iv` the counter
        // block, and `hkeys` the GHASH key powers; `scratch` is the 144 bytes
        // it may write, and `tag` the 16 it writes or reads. The token proves
        // the CPU has AES-NI, PCLMULQDQ, AVX, and MOVBE.
        let result = unsafe {
            let rest = blocks.add(six * 16);
            routine(
                aad.as_ptr(),
                aad.len() as u64,
                (aad_whole / 16) as u64,
                key.as_aes_key(),
                iv,
                hkeys,
                aad_partial.as_ptr(),
                blocks,
                blocks,
                six as u64,
                rest,
                rest,
                ones as u64,
                partial.as_mut_ptr(),
                len as u64,
                scratch.as_mut_ptr(),
                tag.as_mut_ptr(),
            )
        };
        let tail_len = tail.len();
        tail.copy_from_slice(&partial[..tail_len]);
        result
    }
}

/// Expands `key` into `out` by Vale's key expansion, which the AES-GCM
/// routines' proofs assume made their round keys.
pub(crate) fn expand_128(key: &[u8; 16], out: &mut [__m128i; 11], _: HaveAvxMovbeForAesGcm) {
    // SAFETY: `key` is 16 readable bytes and `out` the 176 the routine
    // writes. The token proves the CPU has AES-NI and AVX.
    unsafe { aes128_key_expansion(key.as_ptr(), out.as_mut_ptr().cast()) };
}

/// [`expand_128`] for AES-256.
pub(crate) fn expand_256(key: &[u8; 32], out: &mut [__m128i; 15], _: HaveAvxMovbeForAesGcm) {
    // SAFETY: `key` is 32 readable bytes and `out` the 240 the routine
    // writes. The token proves the CPU has AES-NI and AVX.
    unsafe { aes256_key_expansion(key.as_ptr(), out.as_mut_ptr().cast()) };
}

/// Declares a routine as a naked function over Vale's text. Each takes the
/// System V ABI on every OS, since its text is Vale's ELF and Mach-O flavors.
macro_rules! routine {
    ($name:ident($($arg:ident: $ty:ty),*) $(-> $ret:ty)?) => {
        #[unsafe(naked)]
        unsafe extern "sysv64" fn $name($($arg: $ty),*) $(-> $ret)? {
            #[cfg(not(target_vendor = "apple"))]
            core::arch::naked_asm!(
                include_str!(concat!("hacl/", stringify!($name), ".linux.s")),
                options(att_syntax),
            );
            #[cfg(target_vendor = "apple")]
            core::arch::naked_asm!(
                include_str!(concat!("hacl/", stringify!($name), ".apple.s")),
                options(att_syntax),
            );
        }
    };
}

routine!(aes128_key_expansion(key: *const u8, round_keys: *mut u8));
routine!(aes256_key_expansion(key: *const u8, round_keys: *mut u8));
routine!(aes128_keyhash_init(round_keys: *const u8, hkeys: *mut u8));
routine!(aes256_keyhash_init(round_keys: *const u8, hkeys: *mut u8));
routine!(compute_iv_stdcall(
    iv: *const u8,
    iv_len: u64,
    iv_blocks: u64,
    j0: *mut u8,
    extra: *const u8,
    hkeys: *const u8
));

/// The AEAD routines' arguments: the AAD, its length and whole blocks, the
/// round keys, the counter block, the GHASH key powers, and the AAD's
/// partial block; the six-block loop's input, output, and blocks, then the
/// one-block loop's; the message's partial block, the message's length,
/// scratch, and the tag. Decryption returns zero if the tag matches.
type Aead = unsafe extern "sysv64" fn(
    *const u8,
    u64,
    u64,
    *const u8,
    *mut u8,
    *const u8,
    *const u8,
    *mut u8,
    *mut u8,
    u64,
    *mut u8,
    *mut u8,
    u64,
    *mut u8,
    u64,
    *mut u8,
    *mut u8,
) -> u64;

macro_rules! aead {
    ($($name:ident),*) => {$(
        routine!($name(
            aad: *const u8,
            aad_len: u64,
            aad_blocks: u64,
            round_keys: *const u8,
            iv: *mut u8,
            hkeys: *const u8,
            aad_partial: *const u8,
            six_in: *mut u8,
            six_out: *mut u8,
            six_blocks: u64,
            one_in: *mut u8,
            one_out: *mut u8,
            one_blocks: u64,
            partial: *mut u8,
            len: u64,
            scratch: *mut u8,
            tag: *mut u8
        ) -> u64);
    )*};
}

aead!(
    gcm128_encrypt_opt,
    gcm256_encrypt_opt,
    gcm128_decrypt_opt,
    gcm256_decrypt_opt
);
