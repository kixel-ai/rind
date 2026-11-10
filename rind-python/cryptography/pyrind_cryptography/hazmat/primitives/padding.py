"""Block padding: PKCS#7 and ANSI X9.23."""

import abc
import hmac

from pyrind_cryptography.exceptions import AlreadyFinalized


class PaddingContext(metaclass=abc.ABCMeta):
    """Pads or unpads a message given in pieces."""

    @abc.abstractmethod
    def update(self, data):
        """Takes `data`, returning what is ready."""

    @abc.abstractmethod
    def finalize(self):
        """Returns the rest."""


def _check_block_size(block_size):
    if not 0 <= block_size <= 2040:
        raise ValueError("block_size must be in range(0, 2041).")
    if block_size % 8 != 0:
        raise ValueError("block_size must be a multiple of 8.")


class _Padder(PaddingContext):
    def __init__(self, block_size, fill):
        self._block_size = block_size // 8
        self._fill = fill
        self._buffer = b""
        self._done = False

    def update(self, data):
        if self._done:
            raise AlreadyFinalized("Context was already finalized.")
        if not isinstance(data, (bytes, bytearray, memoryview)):
            raise TypeError("data must be bytes-like")
        self._buffer += bytes(data)
        whole = len(self._buffer) // self._block_size * self._block_size
        out, self._buffer = self._buffer[:whole], self._buffer[whole:]
        return out

    def finalize(self):
        if self._done:
            raise AlreadyFinalized("Context was already finalized.")
        self._done = True
        count = self._block_size - len(self._buffer)
        return self._buffer + self._fill(count)


class _Unpadder(PaddingContext):
    """Holds back the last block, whose padding it checks with `hmac.compare_digest` alone.

    It compares the block's tail against every possible padding, in a fixed
    order, each in constant time. Which candidate matched is the plaintext's
    length, which is public once returned, and a failure matches none, so no
    timing tells two bad paddings apart.
    """

    def __init__(self, block_size, ansi):
        self._block_size = block_size // 8
        self._ansi = ansi
        self._buffer = b""
        self._done = False

    def update(self, data):
        if self._done:
            raise AlreadyFinalized("Context was already finalized.")
        if not isinstance(data, (bytes, bytearray, memoryview)):
            raise TypeError("data must be bytes-like")
        self._buffer += bytes(data)
        whole = max(len(self._buffer) // self._block_size - 1, 0) * self._block_size
        out, self._buffer = self._buffer[:whole], self._buffer[whole:]
        return out

    def finalize(self):
        if self._done:
            raise AlreadyFinalized("Context was already finalized.")
        self._done = True
        size = self._block_size
        if len(self._buffer) != size:
            raise ValueError("Invalid padding bytes.")
        block = self._buffer
        matches = [
            hmac.compare_digest(block[size - pad :], (bytes(pad - 1) if self._ansi else bytes([pad]) * (pad - 1)) + bytes([pad]))
            for pad in range(1, size + 1)
        ]
        if True not in matches:
            raise ValueError("Invalid padding bytes.")
        return block[: size - 1 - matches.index(True)]


class PKCS7:
    """PKCS#7 padding to `block_size` bits."""

    def __init__(self, block_size):
        _check_block_size(block_size)
        self.block_size = block_size

    def padder(self):
        return _Padder(self.block_size, lambda count: bytes([count]) * count)

    def unpadder(self):
        return _Unpadder(self.block_size, ansi=False)


class ANSIX923:
    """ANSI X9.23 padding to `block_size` bits."""

    def __init__(self, block_size):
        _check_block_size(block_size)
        self.block_size = block_size

    def padder(self):
        return _Padder(self.block_size, lambda count: bytes(count - 1) + bytes([count]))

    def unpadder(self):
        return _Unpadder(self.block_size, ansi=True)


__all__ = ["ANSIX923", "PKCS7", "PaddingContext"]
