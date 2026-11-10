"""PBKDF2 with HMAC, on rind's PBKDF2-HMAC-SHA1 and PBKDF2-HMAC-SHA2."""

from pyrind import pbkdf2 as _pbkdf2

from pyrind_cryptography.exceptions import AlreadyFinalized
from pyrind_cryptography.hazmat.primitives import hashes
from pyrind_cryptography.hazmat.primitives.kdf import _OneShot

_RIND = {
    "sha1": _pbkdf2.legacy.PBKDF2_HMAC_SHA1,
    "sha256": _pbkdf2.PBKDF2_HMAC_SHA256,
    "sha384": _pbkdf2.PBKDF2_HMAC_SHA384,
    "sha512": _pbkdf2.PBKDF2_HMAC_SHA512,
}


class PBKDF2HMAC(_OneShot):
    """PBKDF2 with HMAC over `algorithm`, deriving `length` bytes."""

    def __init__(self, algorithm, length, salt, iterations, backend=None):
        self._rind = hashes._rind(algorithm, _RIND)
        if not isinstance(salt, bytes):
            raise TypeError("salt must be bytes.")
        self._length = length
        self._salt = salt
        self._iterations = iterations

    def _secret(self, key_material):
        if self._used:
            raise AlreadyFinalized("PBKDF2 instances can only be used once.")
        self._used = True
        return _pbkdf2.Secret(self._rind, key_material)

    def derive(self, key_material):
        return self._secret(key_material).derive(self._iterations, self._salt, self._length)


__all__ = ["PBKDF2HMAC"]
