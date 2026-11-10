"""Unauthenticated AES-CBC, for protocols that specify it alongside their own MAC, such as JWE's AES-CBC-HMAC."""

from typing import final

from typing_extensions import Buffer

@final
class Algorithm:
    """An AES key size."""

AES_128: Algorithm
AES_192: Algorithm
AES_256: Algorithm

@final
class AesCbcEncryptingKey:
    """An AES-CBC key that encrypts."""

    def __new__(cls, algorithm: Algorithm, key: Buffer) -> AesCbcEncryptingKey:
        """Expands `key` for `algorithm`; raises `WrongLength` unless it is that size."""
    def encrypt_blocks(self, iv: Buffer, plaintext: Buffer) -> bytes:
        """Encrypts whole 16-byte blocks under the 16-byte `iv`, which an attacker must not be able to predict, without padding; raises `WrongLength` for a partial block."""

@final
class AesCbcDecryptingKey:
    """An AES-CBC key that decrypts, unauthenticated: check a MAC over the IV and ciphertext first."""

    def __new__(cls, algorithm: Algorithm, key: Buffer) -> AesCbcDecryptingKey:
        """Expands `key` for `algorithm`; raises `WrongLength` unless it is that size."""
    def decrypt_blocks(self, iv: Buffer, ciphertext: Buffer) -> bytes:
        """Decrypts whole 16-byte blocks under the 16-byte `iv`, without padding; raises `DecryptFailed` for a partial block."""

__all__ = ["Algorithm", "AesCbcEncryptingKey", "AesCbcDecryptingKey", "AES_128", "AES_192", "AES_256"]
