"""HKDF, on rind's HKDF and HMAC with SHA-1 and SHA-2."""

from pyrind import hkdf as _hkdf
from pyrind import hmac as _hmac

from pyrind_cryptography.hazmat.primitives import hashes
from pyrind_cryptography.hazmat.primitives import hmac as _pyca_hmac
from pyrind_cryptography.hazmat.primitives.kdf import _check_bytes, _OneShot

_RIND = {
    "sha1": _hkdf.legacy.HKDF_SHA1,
    "sha256": _hkdf.HKDF_SHA256,
    "sha384": _hkdf.HKDF_SHA384,
    "sha512": _hkdf.HKDF_SHA512,
}


def _check_length(algorithm, length):
    if length > 255 * algorithm.digest_size:
        raise ValueError(f"Cannot derive keys larger than {255 * algorithm.digest_size} octets.")


class HKDF(_OneShot):
    """HKDF's extract and expand, deriving `length` bytes."""

    def __init__(self, algorithm, length, salt, info, backend=None):
        self._rind = hashes._rind(algorithm, _RIND)
        _check_length(algorithm, length)
        self._length = length
        self._salt = _check_bytes("salt", salt)
        self._info = _check_bytes("info", info)

    def _derive(self, key_material):
        return _hkdf.Salt(self._rind, self._salt).extract(key_material).expand(self._info, self._length)

    @staticmethod
    def extract(algorithm, salt, key_material):
        """HKDF's extract step, returning the pseudorandom key."""
        algorithm_rind = hashes._rind(algorithm, _pyca_hmac._RIND)
        salt = _check_bytes("salt", salt) or bytes(algorithm.digest_size)
        return _hmac.sign(_hmac.Key(algorithm_rind, salt), key_material)


class HKDFExpand(_OneShot):
    """HKDF's expand step alone, from a pseudorandom key."""

    def __init__(self, algorithm, length, info, backend=None):
        self._rind = hashes._rind(algorithm, _pyca_hmac._RIND)
        _check_length(algorithm, length)
        self._length = length
        self._info = _check_bytes("info", info)

    def _derive(self, key_material):
        key = _hmac.Key(self._rind, key_material)
        output, block = [], b""
        for counter in range(1, -(-self._length // self._rind.tag_len) + 1):
            block = _hmac.sign(key, block + self._info + bytes([counter]))
            output.append(block)
        return b"".join(output)[: self._length]


__all__ = ["HKDF", "HKDFExpand"]
