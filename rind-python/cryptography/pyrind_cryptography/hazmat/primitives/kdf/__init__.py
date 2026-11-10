"""Key derivation functions."""

import abc
import hmac as _std_hmac

from pyrind_cryptography.exceptions import AlreadyFinalized, InvalidKey


class KeyDerivationFunction(metaclass=abc.ABCMeta):
    """A function that derives keys from a secret."""

    @abc.abstractmethod
    def derive(self, key_material):
        """Derives a key from `key_material`."""

    @abc.abstractmethod
    def verify(self, key_material, expected_key):
        """Checks that `key_material` derives `expected_key`; raises `InvalidKey` otherwise."""


class _OneShot(KeyDerivationFunction):
    """A KDF instance that derives once, from `_derive`, as each of pyca's does."""

    _length: int
    _used = False

    def _derive(self, key_material):
        raise NotImplementedError

    def derive(self, key_material):
        if self._used:
            raise AlreadyFinalized
        self._used = True
        return self._derive(key_material)

    def derive_into(self, key_material, buffer):
        view = memoryview(buffer).cast("B")
        if len(view) != self._length:
            raise ValueError(f"buffer must be {self._length} bytes")
        view[:] = self.derive(key_material)
        return self._length

    def verify(self, key_material, expected_key):
        if not _std_hmac.compare_digest(self.derive(key_material), expected_key):
            raise InvalidKey


def _check_bytes(name, value):
    if value is None:
        return b""
    if not isinstance(value, bytes):
        raise TypeError(f"{name} must be bytes.")
    return value


__all__ = ["KeyDerivationFunction"]
