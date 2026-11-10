"""The single-step KDF of NIST SP 800-56A (Concat KDF), on rind's hashes and HMAC."""

from pyrind import digest as _digest
from pyrind import hmac as _hmac

from pyrind_cryptography.hazmat.primitives import hashes
from pyrind_cryptography.hazmat.primitives import hmac as _pyca_hmac
from pyrind_cryptography.hazmat.primitives.kdf import _check_bytes, _OneShot


def _check_length(algorithm, length):
    if length > (2**32 - 1) * algorithm.digest_size:
        raise ValueError(f"Cannot derive keys larger than {(2**32 - 1) * algorithm.digest_size} bits.")


class ConcatKDFHash(_OneShot):
    """Concat KDF with the hash `algorithm`, deriving `length` bytes."""

    def __init__(self, algorithm, length, otherinfo, backend=None):
        self._rind = hashes._rind(algorithm)
        _check_length(algorithm, length)
        self._length = length
        self._otherinfo = _check_bytes("otherinfo", otherinfo)

    def _derive(self, key_material):
        blocks = -(-self._length // self._rind.output_len)
        output = (
            _digest.digest(self._rind, counter.to_bytes(4, "big") + bytes(key_material) + self._otherinfo)
            for counter in range(1, blocks + 1)
        )
        return b"".join(output)[: self._length]


class ConcatKDFHMAC(_OneShot):
    """Concat KDF with HMAC over `algorithm`, keyed by `salt`, deriving `length` bytes."""

    def __init__(self, algorithm, length, salt, otherinfo, backend=None):
        self._rind = hashes._rind(algorithm, _pyca_hmac._RIND)
        _check_length(algorithm, length)
        self._length = length
        self._key = _hmac.Key(self._rind, _check_bytes("salt", salt) or bytes(algorithm.block_size))
        self._otherinfo = _check_bytes("otherinfo", otherinfo)

    def _derive(self, key_material):
        blocks = -(-self._length // self._rind.tag_len)
        output = (
            _hmac.sign(self._key, counter.to_bytes(4, "big") + bytes(key_material) + self._otherinfo)
            for counter in range(1, blocks + 1)
        )
        return b"".join(output)[: self._length]


__all__ = ["ConcatKDFHash", "ConcatKDFHMAC"]
