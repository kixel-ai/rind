"""Hash functions."""

from typing import final

from typing_extensions import Buffer

from pyrind.digest import legacy as legacy

@final
class Algorithm:
    """A hash function."""

    @property
    def output_len(self) -> int:
        """The digest's length in bytes."""

SHA256: Algorithm
SHA384: Algorithm
SHA512: Algorithm
SHA512_256: Algorithm
SHA3_256: Algorithm
SHA3_384: Algorithm
SHA3_512: Algorithm

def digest(algorithm: Algorithm, data: Buffer) -> bytes:
    """Returns the digest of `data`."""

@final
class Context:
    """A hash of a message given in pieces."""

    def __init__(self, algorithm: Algorithm) -> None:
        """Starts hashing with `algorithm`."""
    def update(self, data: Buffer) -> None:
        """Adds `data` to the message."""
    def finish(self) -> bytes:
        """Returns the digest of the message, and starts a new one with the same algorithm."""
