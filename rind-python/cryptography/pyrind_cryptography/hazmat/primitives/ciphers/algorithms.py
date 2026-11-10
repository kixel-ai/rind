"""Cipher algorithms; rind has AES."""

import abc

from pyrind_cryptography.hazmat.primitives import _keys


class CipherAlgorithm(metaclass=abc.ABCMeta):
    """A cipher."""

    name: str
    key_sizes: frozenset
    key_size: int


class BlockCipherAlgorithm(CipherAlgorithm):
    """A block cipher."""

    key: bytes
    block_size: int


def _verify_key_size(algorithm, key):
    _keys.check_bytes("key", key)
    if len(memoryview(key).cast("B")) * 8 not in algorithm.key_sizes:
        raise ValueError(f"Invalid key size ({len(memoryview(key).cast('B')) * 8}) for {algorithm.name}.")
    return key


class AES(BlockCipherAlgorithm):
    """AES with a 128-, 192-, or 256-bit key (or 512 bits for XTS, which rind lacks)."""

    name = "AES"
    block_size = 128
    key_sizes = frozenset([128, 192, 256, 512])

    def __init__(self, key):
        self.key = _verify_key_size(self, key)

    @property
    def key_size(self):
        return len(memoryview(self.key).cast("B")) * 8


class AES128(BlockCipherAlgorithm):
    """AES with a 128-bit key."""

    name = "AES"
    block_size = 128
    key_sizes = frozenset([128])
    key_size = 128

    def __init__(self, key):
        self.key = _verify_key_size(self, key)


class AES256(BlockCipherAlgorithm):
    """AES with a 256-bit key."""

    name = "AES"
    block_size = 128
    key_sizes = frozenset([256])
    key_size = 256

    def __init__(self, key):
        self.key = _verify_key_size(self, key)


class ChaCha20(CipherAlgorithm):
    """The bare ChaCha20 stream cipher, which rind does not offer through `Cipher` yet."""

    name = "ChaCha20"
    key_sizes = frozenset([256])

    def __init__(self, key, nonce):
        self.key = _verify_key_size(self, key)
        _keys.check_bytes("nonce", nonce)
        if len(nonce) != 16:
            raise ValueError("nonce must be 128-bits (16 bytes)")
        self._nonce = nonce

    @property
    def nonce(self):
        return self._nonce

    @property
    def key_size(self):
        return len(self.key) * 8


__all__ = ["AES", "AES128", "AES256", "BlockCipherAlgorithm", "ChaCha20", "CipherAlgorithm"]
