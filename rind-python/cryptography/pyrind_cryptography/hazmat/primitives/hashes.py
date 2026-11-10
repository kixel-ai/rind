"""Hash functions, on rind's SHA-1, SHA-2, SHA-3, and MD5."""

import abc

from pyrind import digest as _digest

from pyrind_cryptography.exceptions import AlreadyFinalized, _Reasons, unsupported


class HashAlgorithm(metaclass=abc.ABCMeta):
    """A hash function."""

    name: str
    digest_size: int
    block_size: "int | None"


class HashContext(metaclass=abc.ABCMeta):
    """A hash of a message given in pieces."""


class ExtendableOutputFunction(metaclass=abc.ABCMeta):
    """A hash function whose output is any length."""


def _algorithm(cls, name, digest_size, block_size):
    return type(cls, (HashAlgorithm,), {"name": name, "digest_size": digest_size, "block_size": block_size, "__doc__": f"{cls}."})


SHA1 = _algorithm("SHA1", "sha1", 20, 64)
SHA224 = _algorithm("SHA224", "sha224", 28, 64)
SHA256 = _algorithm("SHA256", "sha256", 32, 64)
SHA384 = _algorithm("SHA384", "sha384", 48, 128)
SHA512 = _algorithm("SHA512", "sha512", 64, 128)
SHA512_224 = _algorithm("SHA512_224", "sha512-224", 28, 128)
SHA512_256 = _algorithm("SHA512_256", "sha512-256", 32, 128)
SHA3_224 = _algorithm("SHA3_224", "sha3-224", 28, None)
SHA3_256 = _algorithm("SHA3_256", "sha3-256", 32, None)
SHA3_384 = _algorithm("SHA3_384", "sha3-384", 48, None)
SHA3_512 = _algorithm("SHA3_512", "sha3-512", 64, None)
MD5 = _algorithm("MD5", "md5", 16, 64)
SM3 = _algorithm("SM3", "sm3", 32, 64)


class SHAKE128(HashAlgorithm, ExtendableOutputFunction):
    """SHAKE128, whose output is `digest_size` bytes."""

    name = "shake128"
    block_size = None

    def __init__(self, digest_size):
        if not isinstance(digest_size, int):
            raise TypeError("digest_size must be an integer")
        if digest_size < 1:
            raise ValueError("digest_size must be a positive integer")
        self._digest_size = digest_size

    @property
    def digest_size(self):
        return self._digest_size


class SHAKE256(SHAKE128):
    """SHAKE256, whose output is `digest_size` bytes."""

    name = "shake256"


class BLAKE2b(HashAlgorithm):
    """BLAKE2b with a 64-byte digest."""

    name = "blake2b"
    _max_digest_size = 64
    _min_digest_size = 1
    block_size = 128

    def __init__(self, digest_size):
        if digest_size != 64:
            raise ValueError("Digest size must be 64")
        self._digest_size = digest_size

    @property
    def digest_size(self):
        return self._digest_size


class BLAKE2s(HashAlgorithm):
    """BLAKE2s with a 32-byte digest."""

    name = "blake2s"
    block_size = 64
    _max_digest_size = 32
    _min_digest_size = 1

    def __init__(self, digest_size):
        if digest_size != 32:
            raise ValueError("Digest size must be 32")
        self._digest_size = digest_size

    @property
    def digest_size(self):
        return self._digest_size


_RIND = {
    "sha1": _digest.legacy.SHA1,
    "md5": _digest.legacy.MD5,
    "sha256": _digest.SHA256,
    "sha384": _digest.SHA384,
    "sha512": _digest.SHA512,
    "sha512-256": _digest.SHA512_256,
    "sha3-256": _digest.SHA3_256,
    "sha3-384": _digest.SHA3_384,
    "sha3-512": _digest.SHA3_512,
}


def _rind(algorithm, table=_RIND):
    """rind's algorithm for the pyca hash `algorithm`, from `table`."""
    if not isinstance(algorithm, HashAlgorithm):
        raise TypeError("Expected instance of hashes.HashAlgorithm.")
    try:
        return table[algorithm.name]
    except KeyError:
        raise unsupported(f"{algorithm.name}", _Reasons.UNSUPPORTED_HASH) from None


class Hash(HashContext):
    """A hash of a message given in pieces."""

    def __init__(self, algorithm, backend=None):
        self._algorithm = algorithm
        self._context = _digest.Context(_rind(algorithm))

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
        copy = Hash.__new__(Hash)
        copy._algorithm = self._algorithm
        copy._context = self._context.copy()
        return copy

    def finalize(self):
        if self._context is None:
            raise AlreadyFinalized("Context was already finalized.")
        context, self._context = self._context, None
        return context.finish()


class XOFHash:
    """An extendable-output hash; rind has none."""

    def __init__(self, algorithm):
        raise unsupported(getattr(algorithm, "name", "XOF"), _Reasons.UNSUPPORTED_HASH)


__all__ = [
    "MD5", "SHA1", "SHA3_224", "SHA3_256", "SHA3_384", "SHA3_512", "SHA224", "SHA256", "SHA384",
    "SHA512", "SHA512_224", "SHA512_256", "SHAKE128", "SHAKE256", "SM3", "BLAKE2b", "BLAKE2s",
    "ExtendableOutputFunction", "Hash", "HashAlgorithm", "HashContext", "XOFHash",
]
