"""`Cipher`, which pairs an algorithm with a mode, and its contexts.

rind runs AES in CBC and GCM modes. GCM's contexts hold the message until
`finalize`, which returns all of it: rind seals and opens whole messages, and
releases no plaintext before it has authenticated it, where pyca's `update`
and `update_into` return each piece as they go.
"""

import abc

import pyrind
from pyrind import aead as _aead
from pyrind import cipher as _cipher

from pyrind_cryptography.exceptions import AlreadyFinalized, AlreadyUpdated, InvalidTag, NotYetFinalized, _Reasons, unsupported
from pyrind_cryptography.hazmat.primitives.ciphers import algorithms as _algorithms
from pyrind_cryptography.hazmat.primitives.ciphers import modes as _modes

_CBC = {128: _cipher.AES_128, 192: _cipher.AES_192, 256: _cipher.AES_256}
_GCM = {128: _aead.AES_128_GCM, 192: _aead.AES_192_GCM, 256: _aead.AES_256_GCM}


class CipherContext(metaclass=abc.ABCMeta):
    """Encrypts or decrypts a message given in pieces."""

    @abc.abstractmethod
    def update(self, data):
        """Takes `data`, returning what is ready."""

    def update_into(self, data, buf):
        """Takes `data`, writing what is ready into `buf` and returning its length."""
        # Checked before `update`, so a refused buffer leaves the context as it was.
        view = memoryview(buf).cast("B")
        if view.readonly:
            raise TypeError("buffer must be writable")
        needed = len(memoryview(data).cast("B")) + 15
        if len(view) < needed:
            raise ValueError(f"buffer must be at least {needed} bytes for this payload")
        out = self.update(data)
        view[: len(out)] = out
        return len(out)

    @abc.abstractmethod
    def finalize(self):
        """Returns the rest."""

    def reset_nonce(self, nonce):
        """Restarts with `nonce`; rind's modes take no new nonce mid-context."""
        raise unsupported("reset_nonce", _Reasons.UNSUPPORTED_CIPHER)


class AEADCipherContext(CipherContext):
    """A context that also authenticates data."""

    @abc.abstractmethod
    def authenticate_additional_data(self, data):
        """Adds `data` to what the tag authenticates without encrypting it."""


class AEADDecryptionContext(AEADCipherContext):
    """A decrypting AEAD context."""

    @abc.abstractmethod
    def finalize_with_tag(self, tag):
        """Returns the rest, once `tag` authenticates the message."""


class AEADEncryptionContext(AEADCipherContext):
    """An encrypting AEAD context."""

    @property
    @abc.abstractmethod
    def tag(self):
        """The tag, once finalized."""


class _CbcContext(CipherContext):
    """Chains whole blocks through rind's AES-CBC, holding back a partial one."""

    def __init__(self, key, iv, encrypting):
        size = _CBC[len(key) * 8]
        self._key = (_cipher.AesCbcEncryptingKey if encrypting else _cipher.AesCbcDecryptingKey)(size, key)
        self._encrypting = encrypting
        self._iv = bytes(iv)
        self._buffer = b""
        self._done = False

    def update(self, data):
        if self._done:
            raise AlreadyFinalized("Context was already finalized.")
        self._buffer += bytes(data)
        whole = len(self._buffer) // 16 * 16
        if whole == 0:
            return b""
        blocks, self._buffer = self._buffer[:whole], self._buffer[whole:]
        if self._encrypting:
            out = self._key.encrypt_blocks(self._iv, blocks)
            self._iv = out[-16:]
        else:
            out = self._key.decrypt_blocks(self._iv, blocks)
            self._iv = blocks[-16:]
        return out

    def finalize(self):
        if self._done:
            raise AlreadyFinalized("Context was already finalized.")
        self._done = True
        if self._buffer:
            raise ValueError("The length of the provided data is not a multiple of the block length.")
        return b""


class _GcmEncryptor(AEADEncryptionContext):
    def __init__(self, key, iv):
        self._key = _aead.Key(_GCM[len(key) * 8], key)
        self._iv = bytes(iv)
        self._aad = []
        self._data = []
        self._tag = None
        self._done = False

    def authenticate_additional_data(self, data):
        if self._done:
            raise AlreadyFinalized("Context was already finalized.")
        if self._data:
            raise AlreadyUpdated("Update has been called on this context.")
        self._aad.append(bytes(data))

    def update(self, data):
        if self._done:
            raise AlreadyFinalized("Context was already finalized.")
        self._data.append(bytes(data))
        return b""

    def finalize(self):
        if self._done:
            raise AlreadyFinalized("Context was already finalized.")
        self._done = True
        sealed = self._key.seal(self._iv, b"".join(self._data), aad=b"".join(self._aad))
        self._tag = sealed[-16:]
        return sealed[:-16]

    @property
    def tag(self):
        if self._tag is None:
            raise NotYetFinalized("You must finalize encryption before getting the tag.")
        return self._tag


class _GcmDecryptor(AEADDecryptionContext):
    def __init__(self, key, iv, tag, min_tag_length):
        self._key = _aead.Key(_GCM[len(key) * 8], key)
        self._iv = bytes(iv)
        self._tag = tag
        self._min_tag_length = min_tag_length
        self._aad = []
        self._data = []
        self._done = False

    def authenticate_additional_data(self, data):
        if self._done:
            raise AlreadyFinalized("Context was already finalized.")
        if self._data:
            raise AlreadyUpdated("Update has been called on this context.")
        self._aad.append(bytes(data))

    def update(self, data):
        if self._done:
            raise AlreadyFinalized("Context was already finalized.")
        self._data.append(bytes(data))
        return b""

    def finalize(self):
        if self._tag is None:
            raise ValueError("Authentication tag must be provided when decrypting.")
        return self.finalize_with_tag(self._tag)

    def finalize_with_tag(self, tag):
        if self._done:
            raise AlreadyFinalized("Context was already finalized.")
        if len(tag) < self._min_tag_length:
            raise ValueError(f"Authentication tag must be {self._min_tag_length} bytes or longer.")
        self._done = True
        if len(tag) != 16:
            raise unsupported("GCM tags shorter than 16 bytes", _Reasons.UNSUPPORTED_CIPHER)
        try:
            return self._key.open(self._iv, b"".join(self._data) + bytes(tag), aad=b"".join(self._aad))
        except pyrind.DecryptFailed:
            raise InvalidTag from None


class Cipher:
    """A cipher `algorithm` in `mode`, which makes encryptors and decryptors."""

    def __init__(self, algorithm, mode, backend=None):
        if not isinstance(algorithm, _algorithms.CipherAlgorithm):
            raise TypeError("Expected interface of CipherAlgorithm.")
        if mode is not None:
            if not isinstance(mode, _modes.Mode):
                raise TypeError("Expected interface of Mode.")
            mode.validate_for_algorithm(algorithm)
        self.algorithm = algorithm
        self.mode = mode

    def _key(self):
        if not isinstance(self.algorithm, (_algorithms.AES, _algorithms.AES128, _algorithms.AES256)):
            raise unsupported(f"cipher {self.algorithm.name}", _Reasons.UNSUPPORTED_CIPHER)
        if not isinstance(self.mode, (_modes.CBC, _modes.GCM)):
            name = self.mode.name if self.mode is not None else "no mode"
            raise unsupported(f"cipher {self.algorithm.name} in {name} mode", _Reasons.UNSUPPORTED_CIPHER)
        return bytes(self.algorithm.key)

    def encryptor(self):
        key = self._key()
        if isinstance(self.mode, _modes.GCM):
            if self.mode.tag is not None:
                raise ValueError("Authentication tag must be None when encrypting.")
            if len(self.mode.initialization_vector) != 12:
                raise unsupported("GCM IVs other than 12 bytes", _Reasons.UNSUPPORTED_CIPHER)
            return _GcmEncryptor(key, self.mode.initialization_vector)
        return _CbcContext(key, self.mode.initialization_vector, encrypting=True)

    def decryptor(self):
        key = self._key()
        if isinstance(self.mode, _modes.GCM):
            if len(self.mode.initialization_vector) != 12:
                raise unsupported("GCM IVs other than 12 bytes", _Reasons.UNSUPPORTED_CIPHER)
            return _GcmDecryptor(key, self.mode.initialization_vector, self.mode.tag, self.mode._min_tag_length)
        return _CbcContext(key, self.mode.initialization_vector, encrypting=False)


__all__ = ["AEADCipherContext", "AEADDecryptionContext", "AEADEncryptionContext", "Cipher", "CipherContext"]
