// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! SHA-1 and SHA-256 on rind's portable code in `generic`, as armv7 runs them
//! without the crypto extension, and SHA-384, SHA-512, and SHA-512/256 on
//! HACL*'s verified `Hacl_Hash_SHA2`, as libcrux-sha2 ships it.

use libcrux_sha2::hacl::sha512_update_nblocks;

pub(crate) use crate::low::generic::sha1::sha1_compress_blocks;
pub(crate) use crate::low::generic::sha256::sha256_compress_blocks;

/// Compresses `message`, padded and closed by the big-endian bit `length`.
#[inline(never)]
pub(crate) fn sha1_compress_padded(state: &mut [u32; 5], message: &[u8], length: [u8; 8]) {
    let (blocks, rest) = crate::low::split_tail::<64, 8>(message);
    sha1_compress_blocks(state, blocks);
    let mut last = [[0u8; 64]; 2];
    sha1_compress_blocks(state, crate::low::pad(rest, length, &mut last));
}

/// The digest of `state` followed by `message`, padded and closed by `length`.
#[inline]
pub(crate) fn sha256_finish(state: &[u32; 8], message: &[u8], length: [u8; 8]) -> [u8; 32] {
    let mut h = *state;
    let (blocks, rest) = crate::low::split_tail::<64, 8>(message);
    sha256_compress_blocks(&mut h, blocks);
    let mut last = [[0u8; 64]; 2];
    sha256_compress_blocks(&mut h, crate::low::pad(rest, length, &mut last));
    crate::low::sha256_digest(&h)
}

/// Compresses whole 128-byte `blocks` into `state`.
pub(crate) fn sha512_compress_blocks(state: &mut [u64; 8], blocks: &[u8]) {
    debug_assert!(blocks.len().is_multiple_of(128));
    // HACL takes a 32-bit length, so longer input goes in pieces of whole
    // blocks below it.
    for chunk in blocks.chunks(1 << 31) {
        sha512_update_nblocks(chunk.len() as u32, chunk, state);
    }
}
