// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! SHA-512 compression with aws-lc's `sha512-x86_64` routines, imported by
//! `admin/import-aws-lc`: AVX on Intel CPUs that have it, and scalar code
//! elsewhere.
//!
//! The AVX routine is the faster on Intel's cores and the slower on AMD's,
//! so rind picks by vendor as aws-lc does. aws-lc-verification's SAW proof
//! covers the AVX routine, as aws-lc builds it; nothing verifies the scalar
//! one.

use std::sync::OnceLock;

use super::cpu::{HaveAvx, is_intel};

pub(crate) fn sha512_compress_blocks(state: &mut [u64; 8], blocks: &[u8]) {
    debug_assert!(blocks.len().is_multiple_of(128));
    // Both routines run their loop at least once, so zero blocks would read
    // past `blocks`.
    if blocks.is_empty() {
        return;
    }
    match avx() {
        // SAFETY: `blocks` is a whole number of blocks, and not empty.
        Some(avx) => unsafe { compress_avx(avx, state, blocks) },
        // SAFETY: `blocks` is a whole number of blocks, and not empty.
        None => unsafe { compress_nohw(state, blocks) },
    }
}

/// The AVX routine's token, where the CPU is Intel's and has AVX.
fn avx() -> Option<HaveAvx> {
    // Picked once, rather than testing two features on every compression.
    static AVX: OnceLock<Option<HaveAvx>> = OnceLock::new();
    *AVX.get_or_init(|| HaveAvx::check().filter(|_| is_intel()))
}

/// Compresses `blocks`, a whole number of them, into `state` with the AVX
/// routine.
///
/// # Safety
///
/// `blocks` must hold at least one whole block.
unsafe fn compress_avx(_: HaveAvx, state: &mut [u64; 8], blocks: &[u8]) {
    // SAFETY: `blocks` is `len / 128` readable blocks, at least one, and the
    // token proves AVX.
    unsafe { sha512_block_data_order_avx(state, blocks.as_ptr(), blocks.len() / 128) }
}

/// As [`compress_avx`], with the scalar routine.
///
/// # Safety
///
/// `blocks` must hold at least one whole block.
unsafe fn compress_nohw(state: &mut [u64; 8], blocks: &[u8]) {
    // SAFETY: `blocks` is `len / 128` readable blocks, at least one.
    unsafe { sha512_block_data_order_nohw(state, blocks.as_ptr(), blocks.len() / 128) }
}

/// The round constants, each pair twice for the vector additions, then the
/// byte-swap mask, as the routines load them.
#[repr(C, align(64))]
struct Table([u64; 164]);

static K512: Table = Table(include!("aws_lc/sha512-x86_64.K512.rs"));

// Both routines take the System V ABI on every OS, since their text is aws-lc's
// ELF and Mach-O flavors, which read their arguments from its registers.

#[unsafe(naked)]
unsafe extern "sysv64" fn sha512_block_data_order_avx(
    state: *mut [u64; 8],
    data: *const u8,
    blocks: usize,
) {
    #[cfg(not(target_vendor = "apple"))]
    core::arch::naked_asm!(
        include_str!("aws_lc/sha512_block_data_order_avx.linux.s"),
        K512 = sym K512,
        options(att_syntax),
    );
    #[cfg(target_vendor = "apple")]
    core::arch::naked_asm!(
        include_str!("aws_lc/sha512_block_data_order_avx.apple.s"),
        K512 = sym K512,
        options(att_syntax),
    );
}

#[unsafe(naked)]
unsafe extern "sysv64" fn sha512_block_data_order_nohw(
    state: *mut [u64; 8],
    data: *const u8,
    blocks: usize,
) {
    #[cfg(not(target_vendor = "apple"))]
    core::arch::naked_asm!(
        include_str!("aws_lc/sha512_block_data_order_nohw.linux.s"),
        K512 = sym K512,
        options(att_syntax),
    );
    #[cfg(target_vendor = "apple")]
    core::arch::naked_asm!(
        include_str!("aws_lc/sha512_block_data_order_nohw.apple.s"),
        K512 = sym K512,
        options(att_syntax),
    );
}

#[cfg(test)]
#[cfg_attr(coverage_nightly, coverage(off))]
mod tests {
    use super::*;

    // Every other test sees only the routine the vendor picks, so the two are
    // checked against each other here: odd and even block counts, with
    // distinct bytes in every block.
    #[test]
    fn avx_matches_nohw() {
        if HaveAvx::check().is_none() {
            return;
        }
        let blocks: Vec<u8> = (0..5 * 128u32)
            .map(|i| (i.wrapping_mul(0x9e3779b9) >> 24) as u8)
            .collect();
        for n in 1..=5 {
            let mut want = [
                0x6a09e667f3bcc908,
                0xbb67ae8584caa73b,
                0x3c6ef372fe94f82b,
                0xa54ff53a5f1d36f1,
                0x510e527fade682d1,
                0x9b05688c2b3e6c1f,
                0x1f83d9abfb41bd6b,
                0x5be0cd19137e2179,
            ];
            let mut got = want;
            // SAFETY: `blocks` holds at least `n` blocks, and the token proves
            // AVX.
            unsafe {
                sha512_block_data_order_nohw(&mut want, blocks.as_ptr(), n);
                sha512_block_data_order_avx(&mut got, blocks.as_ptr(), n);
            }
            assert_eq!(got, want, "{n} blocks");
        }
    }
}
