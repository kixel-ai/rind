"""AEADs: AES-GCM and ChaCha20-Poly1305, on rind's."""

import os

import pyrind
from pyrind import aead as _aead

from pyrind_cryptography.exceptions import InvalidTag, _Reasons, unsupported
from pyrind_cryptography.hazmat.primitives import _keys


def _open(key, nonce, data, associated_data):
    try:
        return key.open(nonce, data, aad=b"" if associated_data is None else associated_data)
    except pyrind.DecryptFailed:
        raise InvalidTag from None


def _into(out, buf):
    view = memoryview(buf).cast("B")
    if len(view) != len(out):
        raise ValueError(f"buffer must be {len(out)} bytes")
    view[:] = out
    return len(out)


class _Aead:
    _name: str
    _nonce_error: str

    def _check_nonce(self, nonce):
        _keys.check_bytes("nonce", nonce)
        if len(memoryview(nonce).cast("B")) != 12:
            self._bad_nonce(len(memoryview(nonce).cast("B")))

    def encrypt(self, nonce, data, associated_data):
        """Encrypts `data` under `nonce`, authenticating `associated_data`, and returns the ciphertext with its tag."""
        self._check_nonce(nonce)
        return self._key.seal(nonce, data, aad=b"" if associated_data is None else associated_data)

    def encrypt_into(self, nonce, data, associated_data, buf):
        """Encrypts into `buf`, which must be 16 bytes longer than `data`."""
        return _into(self.encrypt(nonce, data, associated_data), buf)

    def decrypt(self, nonce, data, associated_data):
        """Decrypts and verifies `data`; raises `InvalidTag` if it does not verify."""
        self._check_nonce(nonce)
        return _open(self._key, nonce, data, associated_data)

    def decrypt_into(self, nonce, data, associated_data, buf):
        """Decrypts into `buf`, which must be 16 bytes shorter than `data`."""
        return _into(self.decrypt(nonce, data, associated_data), buf)


class AESGCM(_Aead):
    """AES-GCM with a 128-, 192-, or 256-bit key; rind takes only 12-byte nonces."""

    _SIZES = {16: _aead.AES_128_GCM, 24: _aead.AES_192_GCM, 32: _aead.AES_256_GCM}

    def __init__(self, key):
        _keys.check_bytes("key", key)
        size = self._SIZES.get(len(memoryview(key).cast("B")))
        if size is None:
            raise ValueError("AESGCM key must be 128, 192, or 256 bits.")
        self._key = _aead.Key(size, key)

    @classmethod
    def generate_key(cls, bit_length):
        if not isinstance(bit_length, int):
            raise TypeError("bit_length must be an integer")
        if bit_length not in (128, 192, 256):
            raise ValueError("bit_length must be 128, 192, or 256")
        return os.urandom(bit_length // 8)

    def _bad_nonce(self, length):
        if length < 8 or length > 128:
            raise ValueError("Nonce must be between 8 and 128 bytes")
        raise unsupported("AES-GCM nonces other than 12 bytes", _Reasons.UNSUPPORTED_CIPHER)


class ChaCha20Poly1305(_Aead):
    """ChaCha20-Poly1305 with a 256-bit key and 12-byte nonces."""

    def __init__(self, key):
        _keys.check_bytes("key", key)
        if len(memoryview(key).cast("B")) != 32:
            raise ValueError("ChaCha20Poly1305 key must be 32 bytes.")
        self._key = _aead.Key(_aead.CHACHA20_POLY1305, key)

    @classmethod
    def generate_key(cls):
        return os.urandom(32)

    def _bad_nonce(self, length):
        raise ValueError("Nonce must be 12 bytes")


def _missing(name):
    class Missing:
        __doc__ = f"{name}, which rind lacks: making a key raises `UnsupportedAlgorithm`."

        def __init__(self, *args, **kwargs):
            raise unsupported(name, _Reasons.UNSUPPORTED_CIPHER)

        @classmethod
        def generate_key(cls, *args, **kwargs):
            raise unsupported(name, _Reasons.UNSUPPORTED_CIPHER)

    Missing.__name__ = Missing.__qualname__ = name
    return Missing


AESCCM = _missing("AESCCM")
AESGCMSIV = _missing("AESGCMSIV")
AESOCB3 = _missing("AESOCB3")
AESSIV = _missing("AESSIV")

__all__ = ["AESCCM", "AESGCM", "AESGCMSIV", "AESOCB3", "AESSIV", "ChaCha20Poly1305"]
