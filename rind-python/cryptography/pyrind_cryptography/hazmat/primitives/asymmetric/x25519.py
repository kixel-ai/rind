"""X25519 key agreement, on rind's X25519."""

import abc

import pyrind
from pyrind import agreement as _agreement

from pyrind_cryptography.hazmat.primitives import _keys


class X25519PublicKey(metaclass=abc.ABCMeta):
    """An X25519 public key."""

    def __init__(self, key):
        self._key = key

    @classmethod
    def from_public_bytes(cls, data):
        """Loads a 32-byte public key."""
        _keys.check_bytes("data", data)
        if len(memoryview(data).cast("B")) != 32:
            raise ValueError("An X25519 public key is 32 bytes long")
        with _keys.loading():
            return X25519PublicKey(_agreement.PublicKey(_agreement.X25519, data))

    def public_bytes(self, encoding, format):
        """Writes the key as `encoding` and `format`."""
        return _keys.public_bytes(encoding, format, spki=self._key.to_spki, raw=self.public_bytes_raw)

    def public_bytes_raw(self):
        """The key's 32 bytes."""
        return bytes(self._key)

    def __eq__(self, other):
        if not isinstance(other, X25519PublicKey):
            return NotImplemented
        return bytes(self._key) == bytes(other._key)

    def __copy__(self):
        return self

    def __deepcopy__(self, memo):
        return self


class X25519PrivateKey(metaclass=abc.ABCMeta):
    """An X25519 private key."""

    def __init__(self, key):
        self._key = key

    @classmethod
    def generate(cls):
        """Generates a key."""
        return X25519PrivateKey(_agreement.PrivateKey.generate(_agreement.X25519))

    @classmethod
    def from_private_bytes(cls, data):
        """Loads a 32-byte private key."""
        _keys.check_bytes("data", data)
        if len(memoryview(data).cast("B")) != 32:
            raise ValueError("An X25519 private key is 32 bytes long")
        with _keys.loading():
            return X25519PrivateKey(_agreement.PrivateKey.from_scalar(_agreement.X25519, data))

    def public_key(self):
        """The key's public key."""
        return X25519PublicKey(self._key.public_key())

    def private_bytes(self, encoding, format, encryption_algorithm):
        """Writes the key as `encoding` and `format`."""
        return _keys.private_bytes(encoding, format, encryption_algorithm, pkcs8=self._key.to_pkcs8, raw=self._key.to_scalar)

    def private_bytes_raw(self):
        """The key's 32 bytes."""
        return self._key.to_scalar()

    def exchange(self, peer_public_key):
        """The shared secret with `peer_public_key`; raises `ValueError` if it is all zeros."""
        if not isinstance(peer_public_key, X25519PublicKey):
            raise TypeError("peer_public_key must be an X25519PublicKey")
        try:
            return self._key.agree(bytes(peer_public_key._key))
        except pyrind.KeyRejected:
            raise ValueError("Error computing shared key.") from None

    def __copy__(self):
        return self

    def __deepcopy__(self, memo):
        return self


__all__ = ["X25519PrivateKey", "X25519PublicKey"]
