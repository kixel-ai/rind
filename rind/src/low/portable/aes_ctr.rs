// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

use super::aes::AesKey;
use crate::low::generic::ctr;

/// XORs AES-CTR keystream into `inout`.
///
/// The counter blocks are `nonce` followed by the big-endian `counter`,
/// `counter + 1`, and so on, wrapping within 32 bits.
pub(crate) fn apply(key: &AesKey, nonce: &[u8; 12], counter: u32, inout: &mut [u8]) {
    ctr::blocks(nonce, counter, inout, |ivec, blocks| {
        // `mid::aes` passes up to 2^32 blocks, and a `u32` range's iterator
        // overflows on the last, so count with a wrapping `u32` instead.
        let mut counter = u32::from_be_bytes(ivec[12..].try_into().unwrap());
        for block in blocks {
            let mut keystream = *ivec;
            keystream[12..].copy_from_slice(&counter.to_be_bytes());
            for (b, k) in block.iter_mut().zip(key.encrypt_block(&keystream)) {
                *b ^= k;
            }
            counter = counter.wrapping_add(1);
        }
    })
}
