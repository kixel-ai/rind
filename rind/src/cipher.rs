// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

pub use crate::mid::aes::{Aes, AesCtr};
pub use crate::mid::aes_cbc::{AesCbcDecryptingKey, AesCbcEncryptingKey, CbcIv};
pub use crate::mid::chacha20::ChaCha20;

/// An AES key size, which fixes the key length a key must have.
#[derive(Debug)]
pub struct Algorithm {
    pub(crate) key_len: usize,
}

/// AES with a 16-byte key.
pub static AES_128: Algorithm = Algorithm { key_len: 16 };

/// AES with a 24-byte key.
pub static AES_192: Algorithm = Algorithm { key_len: 24 };

/// AES with a 32-byte key.
pub static AES_256: Algorithm = Algorithm { key_len: 32 };

/// The algorithm of an AES key `key_len` bytes long, 16, 24, or 32.
pub(crate) fn aes(key_len: usize) -> &'static Algorithm {
    match key_len {
        16 => &AES_128,
        24 => &AES_192,
        _ => &AES_256,
    }
}
