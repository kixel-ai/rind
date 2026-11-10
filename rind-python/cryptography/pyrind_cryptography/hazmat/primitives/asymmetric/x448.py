"""X448, which rind lacks: every way to make a key raises `UnsupportedAlgorithm`."""

import abc

from pyrind_cryptography.exceptions import _Reasons, unsupported


class X448PublicKey(metaclass=abc.ABCMeta):
    """An X448 public key, which rind cannot load."""

    @classmethod
    def from_public_bytes(cls, data):
        raise unsupported("X448", _Reasons.UNSUPPORTED_PUBLIC_KEY_ALGORITHM)


class X448PrivateKey(metaclass=abc.ABCMeta):
    """An X448 private key, which rind cannot make."""

    @classmethod
    def generate(cls):
        raise unsupported("X448", _Reasons.UNSUPPORTED_PUBLIC_KEY_ALGORITHM)

    @classmethod
    def from_private_bytes(cls, data):
        raise unsupported("X448", _Reasons.UNSUPPORTED_PUBLIC_KEY_ALGORITHM)


__all__ = ["X448PrivateKey", "X448PublicKey"]
