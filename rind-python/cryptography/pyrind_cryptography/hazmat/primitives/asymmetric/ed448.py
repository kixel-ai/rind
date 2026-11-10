"""Ed448, which rind lacks: every way to make a key raises `UnsupportedAlgorithm`."""

import abc

from pyrind_cryptography.exceptions import _Reasons, unsupported


class Ed448PublicKey(metaclass=abc.ABCMeta):
    """An Ed448 public key, which rind cannot load."""

    @classmethod
    def from_public_bytes(cls, data):
        raise unsupported("Ed448", _Reasons.UNSUPPORTED_PUBLIC_KEY_ALGORITHM)


class Ed448PrivateKey(metaclass=abc.ABCMeta):
    """An Ed448 private key, which rind cannot make."""

    @classmethod
    def generate(cls):
        raise unsupported("Ed448", _Reasons.UNSUPPORTED_PUBLIC_KEY_ALGORITHM)

    @classmethod
    def from_private_bytes(cls, data):
        raise unsupported("Ed448", _Reasons.UNSUPPORTED_PUBLIC_KEY_ALGORITHM)


__all__ = ["Ed448PrivateKey", "Ed448PublicKey"]
