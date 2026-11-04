// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! AES-GCM on AVX and MOVBE without VAES, with aws-lc's `aesni_gcm_encrypt`
//! and `aesni_gcm_decrypt`, imported by `admin/import-aws-lc`, which
//! interleave AES-CTR and GHASH over six blocks at a time.
//!
//! Neither is formally verified: aws-lc-verification's SAW proof of them is
//! disabled, and held only for aws-lc up to 7bdae64, with AES-256, whole
//! blocks, a 12-byte IV, and no additional data. They support in-place use.

use core::arch::x86_64::__m128i;

use super::aes::HwKey;
use super::aes_gcm_vaes::add_to_counter;
use super::cpu::HaveAvxMovbeForAesGcm;
use super::ghash::{ClmulTable, Ghash};

/// The routines with the GHASH key powers they read.
pub(crate) struct AvxKernel {
    htable: [__m128i; 9],
    _token: HaveAvxMovbeForAesGcm,
}

impl AvxKernel {
    /// The kernel for `table`'s GHASH key.
    pub(crate) fn new(table: &ClmulTable, token: HaveAvxMovbeForAesGcm) -> Self {
        Self {
            htable: table.aws_lc_htable(),
            _token: token,
        }
    }

    /// Encrypts (if `ENC`) or decrypts a prefix of `inout` in place, from the
    /// counter block after `y0`, folding the ciphertext into `ghash`, and
    /// returns its length, a multiple of 96 bytes: zero below 288 bytes to
    /// encrypt or 96 to decrypt.
    pub(crate) fn cipher<const ENC: bool>(
        &self,
        key: &HwKey,
        y0: &[u8; 16],
        ghash: &mut Ghash<'_>,
        inout: &mut [u8],
    ) -> usize {
        let mut ivec = add_to_counter(y0, 1);
        let mut xi = ghash.xi();
        let (inout, len, key, htable) = (
            inout.as_mut_ptr(),
            inout.len(),
            key.as_aes_key(),
            &self.htable,
        );
        // SAFETY: `inout` is `len` readable and writable bytes, which the
        // routines support in place, `key` is an `AES_KEY`, and `htable` the
        // nine vectors they read. The token proves the CPU has AES-NI,
        // PCLMULQDQ, AVX, and MOVBE.
        let done = unsafe {
            match ENC {
                true => aesni_gcm_encrypt(inout, inout, len, key, &mut ivec, htable, &mut xi),
                false => aesni_gcm_decrypt(inout, inout, len, key, &mut ivec, htable, &mut xi),
            }
        };
        ghash.set_xi(&xi);
        done
    }
}

/// The routines' constants, which they load at offsets from the first.
#[repr(C, align(64))]
struct Table([u8; 144]);

static BSWAP_MASK: Table = Table(include!("aws_lc/aesni-gcm-x86_64.bswap_mask.rs"));

/// Declares a routine as a naked function over aws-lc's text, binding the
/// table and helpers through the `sym` operands listed. Each takes the System
/// V ABI on every OS, since its text is aws-lc's ELF and Mach-O flavors.
macro_rules! routine {
    ($name:ident($($arg:ident: $ty:ty),*) $(-> $ret:ty)? { $($op:ident = $sym:ident),* }) => {
        #[unsafe(naked)]
        unsafe extern "sysv64" fn $name($($arg: $ty),*) $(-> $ret)? {
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

routine!(aesni_gcm_encrypt(
    input: *const u8,
    output: *mut u8,
    len: usize,
    key: *const u8,
    ivec: *mut [u8; 16],
    htable: *const [__m128i; 9],
    xi: *mut [u8; 16]
) -> usize {
    bswap_mask = BSWAP_MASK,
    aesni_ctr32_6x = aesni_ctr32_6x,
    aesni_ctr32_ghash_6x = aesni_ctr32_ghash_6x
});
routine!(aesni_gcm_decrypt(
    input: *const u8,
    output: *mut u8,
    len: usize,
    key: *const u8,
    ivec: *mut [u8; 16],
    htable: *const [__m128i; 9],
    xi: *mut [u8; 16]
) -> usize {
    bswap_mask = BSWAP_MASK,
    aesni_ctr32_ghash_6x = aesni_ctr32_ghash_6x
});
// Helpers with aws-lc's own register convention, which only the routines
// above call.
routine!(aesni_ctr32_6x() {});
routine!(aesni_ctr32_ghash_6x() {});
