// Written for Graviola by Joe Birr-Pixton, 2024.
// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

use std::sync::OnceLock;

use crate::low::x86_64;
use crate::low::x86_64::cpu::{HaveAvx, HaveAvx2, HaveSha256, HaveSsse3, is_intel};
use crate::low::{pad, pad_message, split_tail};

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
    match path() {
        Path::Shaext(token) => {
            x86_64::sha256::sha256_compress_blocks_shaext(state, blocks, &[], token)
        }
        Path::Avx(token) => x86_64::sha256::sha256_compress_blocks_avx(state, blocks, token),
        Path::Avx2(token) => x86_64::sha256::sha256_compress_blocks_avx2(state, blocks, token),
        Path::Ssse3(token) => x86_64::sha256::sha256_compress_blocks_ssse3(state, blocks, token),
        Path::Nohw => x86_64::sha256::sha256_compress_blocks_nohw(state, blocks),
    }
}

/// Compresses the end of `message`, padded and closed by `length`.
pub(crate) fn sha256_compress_padded(state: &mut [u32; 8], message: &[u8], length: [u8; 8]) {
    match path() {
        // The routine takes the padding as blocks of its own, so the message's
        // whole blocks run from where they are in the same call. Joining them
        // as the others do would copy the last, and on some cores, such as
        // Arrow Lake, the routine's load of that copy waits for every older
        // store, which costs more than the call it saves.
        Path::Shaext(token) => {
            let mut last = [[0u8; 64]; 2];
            let (blocks, last) = pad_message(message, length, &mut last);
            x86_64::sha256::sha256_compress_blocks_shaext(state, blocks, last, token);
        }
        _ => {
            let (blocks, rest) = split_tail::<64, 8>(message);
            if !blocks.is_empty() {
                sha256_compress_blocks(state, blocks);
            }
            let mut last = [[0u8; 64]; 2];
            sha256_compress_blocks(state, pad(rest, length, &mut last));
        }
    }
}

fn path() -> Path {
    // Picked once, rather than testing up to four features on every compression.
    static PATH: OnceLock<Path> = OnceLock::new();
    *PATH.get_or_init(pick)
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
