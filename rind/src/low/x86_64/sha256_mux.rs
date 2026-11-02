// Written for Graviola by Joe Birr-Pixton, 2024.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

use std::sync::OnceLock;

use crate::low::x86_64;
use crate::low::x86_64::cpu::{HaveAvx, HaveAvx2, HaveSha256, HaveSsse3, is_intel};

/// The SHA-256 routine this CPU runs, with the proof it may.
#[derive(Clone, Copy)]
enum Path {
    Shaext(HaveSha256),
    Avx(HaveAvx),
    Avx2(HaveAvx2),
    Ssse3(HaveSsse3),
    Nohw,
}

pub(crate) fn sha256_compress_blocks(state: &mut [u32; 8], blocks: &[u8]) {
    // Picked once, rather than testing up to four features on every compression.
    static PATH: OnceLock<Path> = OnceLock::new();
    match *PATH.get_or_init(pick) {
        Path::Shaext(token) => x86_64::sha256::sha256_compress_blocks_shaext(state, blocks, token),
        Path::Avx(token) => x86_64::sha256::sha256_compress_blocks_avx(state, blocks, token),
        Path::Avx2(token) => x86_64::sha256::sha256_compress_blocks_avx2(state, blocks, token),
        Path::Ssse3(token) => x86_64::sha256::sha256_compress_blocks_ssse3(state, blocks, token),
        Path::Nohw => x86_64::sha256::sha256_compress_blocks_nohw(state, blocks),
    }
}

fn pick() -> Path {
    if let Some(token) = HaveSha256::check() {
        Path::Shaext(token)
    } else if let Some(token) = HaveAvx::check().filter(|_| is_intel()) {
        Path::Avx(token)
    } else if let Some(token) = HaveAvx2::check() {
        Path::Avx2(token)
    } else if let Some(token) = HaveSsse3::check() {
        Path::Ssse3(token)
    } else {
        Path::Nohw
    }
}
