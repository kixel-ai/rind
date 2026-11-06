// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

use super::aes::{AesDecKey, AesKey};

/// Encrypts whole blocks in place in CBC mode, the first chained from `iv`.
pub(crate) fn encrypt(key: &AesKey, iv: &[u8; 16], blocks: &mut [[u8; 16]]) {
    if let AesKey::Hw(key) = key {
        return key.cbc_encrypt(iv, blocks);
    }

    let mut prev = *iv;
    for block in blocks {
        for (b, p) in block.iter_mut().zip(prev) {
            *b ^= p;
        }
        *block = key.encrypt_block(block);
        prev = *block;
    }
}

/// Decrypts whole blocks in place in CBC mode, the first chained from `iv`.
///
/// The portable cipher bitslices one block at a time, so blocks go one at a
/// time.
pub(crate) fn decrypt(key: &AesDecKey, iv: &[u8; 16], blocks: &mut [[u8; 16]]) {
    if let AesDecKey::Hw(key) = key {
        return key.cbc_decrypt(iv, blocks);
    }

    let mut prev = *iv;
    for block in blocks {
        let ct = *block;
        key.decrypt_block(block);
        for (b, p) in block.iter_mut().zip(prev) {
            *b ^= p;
        }
        prev = ct;
    }
}
