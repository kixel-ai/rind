"""Key serialization's enums and encryption choices."""

import abc
import enum

from pyrind_cryptography.exceptions import _Reasons, unsupported


class Encoding(enum.Enum):
    """How a key's bytes are written."""

    PEM = "PEM"
    DER = "DER"
    OpenSSH = "OpenSSH"
    Raw = "Raw"
    X962 = "ANSI X9.62"
    SMIME = "S/MIME"


class PrivateFormat(enum.Enum):
    """Which structure a private key is written in."""

    PKCS8 = "PKCS8"
    TraditionalOpenSSL = "TraditionalOpenSSL"
    Raw = "Raw"
    OpenSSH = "OpenSSH"
    PKCS12 = "PKCS12"

    def encryption_builder(self):
        """Builds an encryption for this format; rind writes no encrypted keys."""
        raise unsupported("Encrypted key serialization", _Reasons.UNSUPPORTED_SERIALIZATION)


class PublicFormat(enum.Enum):
    """Which structure a public key is written in."""

    SubjectPublicKeyInfo = "X.509 subjectPublicKeyInfo with PKCS#1"
    PKCS1 = "Raw PKCS#1"
    OpenSSH = "OpenSSH"
    Raw = "Raw"
    CompressedPoint = "X9.62 Compressed Point"
    UncompressedPoint = "X9.62 Uncompressed Point"


class ParameterFormat(enum.Enum):
    """Which structure Diffie-Hellman parameters are written in."""

    PKCS3 = "PKCS3"


class KeySerializationEncryption(metaclass=abc.ABCMeta):
    """How a private key is encrypted when written."""


class BestAvailableEncryption(KeySerializationEncryption):
    """Encrypts with `password`; rind writes no encrypted keys, so serializing with it raises `UnsupportedAlgorithm`."""

    def __init__(self, password):
        if not isinstance(password, bytes) or len(password) == 0:
            raise ValueError("Password must be 1 or more bytes.")
        self.password = password


class NoEncryption(KeySerializationEncryption):
    """Writes the key unencrypted."""


class _KeySerializationEncryption(KeySerializationEncryption):
    """A built encryption, which rind never writes."""
