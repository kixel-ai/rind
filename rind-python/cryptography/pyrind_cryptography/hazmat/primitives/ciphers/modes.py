"""Cipher modes; rind has CBC and GCM for AES."""

import abc

from pyrind_cryptography.exceptions import UnsupportedAlgorithm, _Reasons
from pyrind_cryptography.hazmat.primitives import _keys
from pyrind_cryptography.hazmat.primitives.ciphers.algorithms import BlockCipherAlgorithm


class Mode(metaclass=abc.ABCMeta):
    """A cipher mode."""

    name: str

    def validate_for_algorithm(self, algorithm):
        """Checks the mode's parameters against `algorithm`."""


class ModeWithInitializationVector(Mode):
    """A mode with an IV."""


class ModeWithTweak(Mode):
    """A mode with a tweak."""


class ModeWithNonce(Mode):
    """A mode with a nonce."""


class ModeWithAuthenticationTag(Mode):
    """A mode with an authentication tag."""


def _check_aes_key_length(mode, algorithm):
    if algorithm.key_size > 256 and algorithm.name == "AES":
        raise ValueError("Only 128, 192, and 256 bit keys are allowed for this AES mode")


def _check_iv_and_key_length(mode, algorithm):
    if not isinstance(algorithm, BlockCipherAlgorithm):
        raise UnsupportedAlgorithm(f"{mode} requires a block cipher algorithm", _Reasons.UNSUPPORTED_CIPHER)
    _check_aes_key_length(mode, algorithm)
    if len(mode.initialization_vector) * 8 != algorithm.block_size:
        raise ValueError(f"Invalid IV size ({len(mode.initialization_vector)}) for {mode.name}.")


class _IV(ModeWithInitializationVector):
    def __init__(self, initialization_vector):
        _keys.check_bytes("initialization_vector", initialization_vector)
        self._initialization_vector = initialization_vector

    @property
    def initialization_vector(self):
        return self._initialization_vector

    validate_for_algorithm = _check_iv_and_key_length


class CBC(_IV):
    """Cipher block chaining, unpadded."""

    name = "CBC"


class OFB(_IV):
    """Output feedback; rind lacks it."""

    name = "OFB"


class CFB(_IV):
    """Cipher feedback; rind lacks it."""

    name = "CFB"


class CFB8(_IV):
    """8-bit cipher feedback; rind lacks it."""

    name = "CFB8"


class ECB(Mode):
    """Electronic codebook; rind lacks it."""

    name = "ECB"
    validate_for_algorithm = _check_aes_key_length


class XTS(ModeWithTweak):
    """XTS; rind lacks it."""

    name = "XTS"

    def __init__(self, tweak):
        _keys.check_bytes("tweak", tweak)
        if len(tweak) != 16:
            raise ValueError("tweak must be 128-bits (16 bytes)")
        self._tweak = tweak

    @property
    def tweak(self):
        return self._tweak


class CTR(ModeWithNonce):
    """Counter mode; rind does not offer it through `Cipher` yet."""

    name = "CTR"

    def __init__(self, nonce):
        _keys.check_bytes("nonce", nonce)
        self._nonce = nonce

    @property
    def nonce(self):
        return self._nonce

    def validate_for_algorithm(self, algorithm):
        _check_aes_key_length(self, algorithm)
        if not isinstance(algorithm, BlockCipherAlgorithm):
            raise UnsupportedAlgorithm("CTR requires a block cipher algorithm", _Reasons.UNSUPPORTED_CIPHER)
        if len(self.nonce) * 8 != algorithm.block_size:
            raise ValueError(f"Invalid nonce size ({len(self.nonce)}) for {self.name}.")


class GCM(ModeWithInitializationVector, ModeWithAuthenticationTag):
    """Galois/counter mode, which rind runs with a 12-byte IV and a 16-byte tag."""

    name = "GCM"
    _MAX_ENCRYPTED_BYTES = (2**39 - 256) // 8
    _MAX_AAD_BYTES = (2**64) // 8

    def __init__(self, initialization_vector, tag=None, min_tag_length=16):
        _keys.check_bytes("initialization_vector", initialization_vector)
        if len(initialization_vector) < 8 or len(initialization_vector) > 128:
            raise ValueError("initialization_vector must be between 8 and 128 bytes (64 and 1024 bits).")
        self._initialization_vector = initialization_vector
        if tag is not None:
            _keys.check_bytes("tag", tag)
            if min_tag_length < 4:
                raise ValueError("min_tag_length must be >= 4")
            if len(tag) < min_tag_length:
                raise ValueError(f"Authentication tag must be {min_tag_length} bytes or longer.")
        self._tag = tag
        self._min_tag_length = min_tag_length

    @property
    def tag(self):
        return self._tag

    @property
    def initialization_vector(self):
        return self._initialization_vector

    def validate_for_algorithm(self, algorithm):
        _check_aes_key_length(self, algorithm)
        if not isinstance(algorithm, BlockCipherAlgorithm):
            raise UnsupportedAlgorithm("GCM requires a block cipher algorithm", _Reasons.UNSUPPORTED_CIPHER)
        block_size_bytes = algorithm.block_size // 8
        if self._tag is not None and len(self._tag) > block_size_bytes:
            raise ValueError(f"Authentication tag cannot be more than {block_size_bytes} bytes.")


__all__ = [
    "CBC", "CFB", "CFB8", "CTR", "ECB", "GCM", "OFB", "XTS", "Mode", "ModeWithAuthenticationTag",
    "ModeWithInitializationVector", "ModeWithNonce", "ModeWithTweak",
]
