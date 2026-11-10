"""DSS signature encoding, and the prehashed marker."""

from pyrind_cryptography import _der
from pyrind_cryptography.hazmat.primitives import hashes


def decode_dss_signature(signature):
    """Splits a DER `Dss-Sig-Value` into its integers `r` and `s`."""
    values = _der.integers(signature)
    if len(values) != 2:
        raise ValueError("Invalid DSS signature")
    return values[0], values[1]


def encode_dss_signature(r, s):
    """Encodes `r` and `s` as a DER `Dss-Sig-Value`."""
    return _der.sequence(_der.encode_integer(r), _der.encode_integer(s))


class NoDigestInfo:
    """Marks an RSA PKCS#1 v1.5 signature over raw data; rind has none."""


class Prehashed:
    """Marks a message as already hashed with `algorithm`; rind signs and verifies only whole messages."""

    def __init__(self, algorithm):
        if not isinstance(algorithm, hashes.HashAlgorithm):
            raise TypeError("Expected instance of HashAlgorithm.")
        self._algorithm = algorithm
        self._digest_size = algorithm.digest_size

    @property
    def digest_size(self):
        return self._digest_size


__all__ = ["NoDigestInfo", "Prehashed", "decode_dss_signature", "encode_dss_signature"]
