"""HMAC, on rind's HMAC-SHA1 and HMAC-SHA2."""

import hmac as _std_hmac

from pyrind import hmac as _hmac

from pyrind_cryptography.exceptions import AlreadyFinalized, InvalidSignature, _Reasons
from pyrind_cryptography.hazmat.primitives import hashes

_RIND = {
    "sha1": _hmac.legacy.HMAC_SHA1,
    "sha256": _hmac.HMAC_SHA256,
    "sha384": _hmac.HMAC_SHA384,
    "sha512": _hmac.HMAC_SHA512,
}


class HMAC(hashes.HashContext):
    """An HMAC of a message given in pieces."""

    def __init__(self, key, algorithm, backend=None):
        algorithm_rind = hashes._rind(algorithm, _RIND)
        self._algorithm = algorithm
        self._context = _hmac.Context(_hmac.Key(algorithm_rind, key))

    @property
    def algorithm(self):
        return self._algorithm

    def update(self, data):
        if self._context is None:
            raise AlreadyFinalized("Context was already finalized.")
        self._context.update(data)

    def copy(self):
        if self._context is None:
            raise AlreadyFinalized("Context was already finalized.")
        copy = HMAC.__new__(HMAC)
        copy._algorithm = self._algorithm
        copy._context = self._context.copy()
        return copy

    def finalize(self):
        if self._context is None:
            raise AlreadyFinalized("Context was already finalized.")
        context, self._context = self._context, None
        return context.sign()

    def verify(self, signature):
        if not isinstance(signature, bytes):
            raise TypeError("signature must be bytes.")
        if not _std_hmac.compare_digest(self.finalize(), signature):
            raise InvalidSignature("Signature did not match digest.")


__all__ = ["HMAC"]
