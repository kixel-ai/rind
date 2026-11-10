"""The KDF of ANSI X9.63, on rind's hashes."""

from pyrind import digest as _digest

from pyrind_cryptography.hazmat.primitives import hashes
from pyrind_cryptography.hazmat.primitives.kdf import _check_bytes, _OneShot


class X963KDF(_OneShot):
    """X9.63's KDF with the hash `algorithm`, deriving `length` bytes."""

    def __init__(self, algorithm, length, sharedinfo, backend=None):
        self._rind = hashes._rind(algorithm)
        if length > (2**32 - 1) * algorithm.digest_size:
            raise ValueError(f"Cannot derive keys larger than {(2**32 - 1) * algorithm.digest_size} bits.")
        self._length = length
        self._sharedinfo = _check_bytes("sharedinfo", sharedinfo)

    def _derive(self, key_material):
        blocks = -(-self._length // self._rind.output_len)
        output = (
            _digest.digest(self._rind, bytes(key_material) + counter.to_bytes(4, "big") + self._sharedinfo)
            for counter in range(1, blocks + 1)
        )
        return b"".join(output)[: self._length]


__all__ = ["X963KDF"]
