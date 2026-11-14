//! Key wrap (RFC 3394) and key wrap with padding (RFC 5649) with AES.

use core::fmt;

use crate::error::{Unspecified, unspecified};
use crate::sealed::Sealed;
use crate::wipe::Wiped;

/// A block cipher's identity.
#[non_exhaustive]
#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum BlockCipherId {
    /// AES with a 128-bit key.
    Aes128,
    /// AES with a 256-bit key.
    Aes256,
}

/// A block cipher a key encryption key can use.
pub trait BlockCipher: 'static + fmt::Debug + Sealed {
    /// The cipher's identity.
    fn id(&self) -> BlockCipherId;

    /// The cipher's key length in bytes.
    fn key_len(&self) -> usize;
}

/// AES as a key wrap block cipher.
pub struct AesBlockCipher {
    id: BlockCipherId,
    key_len: usize,
}

impl BlockCipherId {
    /// rind's algorithm for this cipher, with padding (RFC 5649) or without
    /// (RFC 3394).
    fn rind(self, padded: bool) -> &'static rind::key_wrap::Algorithm {
        match (self, padded) {
            (Self::Aes128, false) => &rind::key_wrap::AES_128_KW,
            (Self::Aes128, true) => &rind::key_wrap::AES_128_KWP,
            (Self::Aes256, false) => &rind::key_wrap::AES_256_KW,
            (Self::Aes256, true) => &rind::key_wrap::AES_256_KWP,
        }
    }
}

impl BlockCipher for AesBlockCipher {
    fn id(&self) -> BlockCipherId {
        self.id
    }

    fn key_len(&self) -> usize {
        self.key_len
    }
}

impl Sealed for AesBlockCipher {}

impl fmt::Debug for AesBlockCipher {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Debug::fmt(&self.id, f)
    }
}

/// AES with a 128-bit key.
pub const AES_128: AesBlockCipher = AesBlockCipher {
    id: BlockCipherId::Aes128,
    key_len: 16,
};

/// AES with a 256-bit key.
pub const AES_256: AesBlockCipher = AesBlockCipher {
    id: BlockCipherId::Aes256,
    key_len: 32,
};

/// Key wrap (RFC 3394).
pub trait KeyWrap: Sealed {
    /// Wraps `plaintext`, a multiple of 8 bytes from 16, into the start of
    /// `output`, which must be at least 8 bytes longer, returning the wrapped
    /// key.
    fn wrap<'output>(
        self,
        plaintext: &[u8],
        output: &'output mut [u8],
    ) -> Result<&'output mut [u8], Unspecified>;

    /// Unwraps `ciphertext` into the start of `output`, which must be at
    /// least 8 bytes shorter, returning the unwrapped key.
    fn unwrap<'output>(
        self,
        ciphertext: &[u8],
        output: &'output mut [u8],
    ) -> Result<&'output mut [u8], Unspecified>;
}

/// Key wrap with padding (RFC 5649).
pub trait KeyWrapPadded: Sealed {
    /// Wraps `plaintext`, of any length from 1 byte, into the start of
    /// `output`, which must hold it padded to 8 bytes plus 8, returning the
    /// wrapped key.
    fn wrap_with_padding<'output>(
        self,
        plaintext: &[u8],
        output: &'output mut [u8],
    ) -> Result<&'output mut [u8], Unspecified>;

    /// Unwraps `ciphertext` into the start of `output`, which must be at
    /// least 8 bytes shorter, returning the unwrapped key.
    fn unwrap_with_padding<'output>(
        self,
        ciphertext: &[u8],
        output: &'output mut [u8],
    ) -> Result<&'output mut [u8], Unspecified>;
}

/// An AES key encryption key.
pub type AesKek = KeyEncryptionKey<AesBlockCipher>;

/// A key encryption key, which wraps other keys.
pub struct KeyEncryptionKey<Cipher: BlockCipher> {
    cipher: &'static Cipher,
    /// The key, its first [`BlockCipher::key_len`] bytes, which rind binds
    /// to a mode only as each call picks one.
    key: Wiped<[u8; 32]>,
}

impl<Cipher: BlockCipher> KeyEncryptionKey<Cipher> {
    /// Makes a key encryption key from `key`, which must be `cipher`'s key
    /// length.
    pub fn new(cipher: &'static Cipher, key: &[u8]) -> Result<Self, Unspecified> {
        let mut bytes = Wiped::new([0; 32]);
        bytes
            .get_mut(..cipher.key_len())
            .filter(|_| key.len() == cipher.key_len())
            .ok_or(Unspecified)?
            .copy_from_slice(key);
        Ok(Self { cipher, key: bytes })
    }

    /// rind's key encryption key, with padding or without.
    fn rind(&self, padded: bool) -> Result<rind::key_wrap::AesKek, Unspecified> {
        let key = &self.key[..self.cipher.key_len()];
        rind::key_wrap::AesKek::new(self.cipher.id().rind(padded), key).map_err(unspecified)
    }

    /// The block cipher's identity.
    pub fn block_cipher_id(&self) -> BlockCipherId {
        self.cipher.id()
    }
}

impl<Cipher: BlockCipher> Sealed for KeyEncryptionKey<Cipher> {}

impl KeyWrap for KeyEncryptionKey<AesBlockCipher> {
    fn wrap<'output>(
        self,
        plaintext: &[u8],
        output: &'output mut [u8],
    ) -> Result<&'output mut [u8], Unspecified> {
        let len = plaintext.len().checked_add(8).ok_or(Unspecified)?;
        let output = output.get_mut(..len).ok_or(Unspecified)?;
        self.rind(false)?
            .wrap_key(plaintext, output)
            .map_err(unspecified)?;
        Ok(output)
    }

    fn unwrap<'output>(
        self,
        ciphertext: &[u8],
        output: &'output mut [u8],
    ) -> Result<&'output mut [u8], Unspecified> {
        let len = ciphertext.len().checked_sub(8).ok_or(Unspecified)?;
        let output = output.get_mut(..len).ok_or(Unspecified)?;
        self.rind(false)?
            .unwrap_key(ciphertext, output)
            .map_err(unspecified)
    }
}

impl KeyWrapPadded for KeyEncryptionKey<AesBlockCipher> {
    fn wrap_with_padding<'output>(
        self,
        plaintext: &[u8],
        output: &'output mut [u8],
    ) -> Result<&'output mut [u8], Unspecified> {
        let len = plaintext
            .len()
            .checked_next_multiple_of(8)
            .and_then(|len| len.checked_add(8))
            .ok_or(Unspecified)?;
        let output = output.get_mut(..len).ok_or(Unspecified)?;
        self.rind(true)?
            .wrap_key(plaintext, output)
            .map_err(unspecified)?;
        Ok(output)
    }

    fn unwrap_with_padding<'output>(
        self,
        ciphertext: &[u8],
        output: &'output mut [u8],
    ) -> Result<&'output mut [u8], Unspecified> {
        let len = ciphertext.len().checked_sub(8).ok_or(Unspecified)?;
        let output = output.get_mut(..len).ok_or(Unspecified)?;
        self.rind(true)?
            .unwrap_key(ciphertext, output)
            .map_err(unspecified)
    }
}

impl<Cipher: BlockCipher> fmt::Debug for KeyEncryptionKey<Cipher> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("KeyEncryptionKey")
            .field("cipher", self.cipher)
            .finish_non_exhaustive()
    }
}
