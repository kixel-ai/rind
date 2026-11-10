"""How every key type writes itself and maps rind's errors, the way pyca's keys do."""

import contextlib

import pyrind

from pyrind_cryptography import _der
from pyrind_cryptography.exceptions import InvalidSignature, _Reasons, unsupported
from pyrind_cryptography.hazmat.primitives._serialization import (
    Encoding,
    KeySerializationEncryption,
    NoEncryption,
    PrivateFormat,
    PublicFormat,
)

DESERIALIZE = (
    "Could not deserialize key data. The data may be in an incorrect format, the provided password may be "
    "incorrect, it may be encrypted with an unsupported algorithm, or it may be an unsupported key type."
)


@contextlib.contextmanager
def loading():
    """Raises pyca's `ValueError` for a key rind refuses, and its `UnsupportedAlgorithm` for one rind lacks."""
    try:
        yield
    except pyrind.Unsupported:
        raise unsupported("This key", _Reasons.UNSUPPORTED_PUBLIC_KEY_ALGORITHM) from None
    except (pyrind.KeyRejected, pyrind.WrongLength) as e:
        raise ValueError(f"{DESERIALIZE} ({e})" if str(e) else DESERIALIZE) from None


@contextlib.contextmanager
def verifying():
    """Raises pyca's `InvalidSignature` for a signature rind refuses."""
    try:
        yield
    except pyrind.BadSignature:
        raise InvalidSignature from None


def check_bytes(name, data):
    """Refuses `data` unless it is bytes-like, as pyca does."""
    try:
        memoryview(data)
    except TypeError:
        raise TypeError(f"{name} must be bytes-like") from None


def private_bytes(encoding, format, encryption_algorithm, *, pkcs8, traditional=None, raw=None):
    """Writes a private key: `pkcs8` returns its PKCS#8 DER, `traditional` is its OpenSSL PEM label and DER, and `raw` its raw bytes."""
    if not isinstance(encoding, Encoding):
        raise TypeError("encoding must be an item from the Encoding enum")
    if not isinstance(format, PrivateFormat):
        raise TypeError("format must be an item from the PrivateFormat enum")
    if not isinstance(encryption_algorithm, KeySerializationEncryption):
        raise TypeError("Encryption algorithm must be a KeySerializationEncryption instance")

    if encoding is Encoding.Raw or format is PrivateFormat.Raw:
        if raw is None:
            raise ValueError("Raw format and encoding are only valid for X25519, Ed25519, X448, and Ed448 keys")
        if encoding is not Encoding.Raw or format is not PrivateFormat.Raw or not isinstance(encryption_algorithm, NoEncryption):
            raise ValueError("When using Raw both encoding and format must be Raw and encryption_algorithm must be NoEncryption()")
        return raw()

    if not isinstance(encryption_algorithm, NoEncryption):
        raise unsupported("Encrypted key serialization", _Reasons.UNSUPPORTED_SERIALIZATION)
    if format is PrivateFormat.PKCS8:
        label, der = "PRIVATE KEY", pkcs8()
    elif format is PrivateFormat.TraditionalOpenSSL:
        if traditional is None:
            raise ValueError("format is invalid with this key")
        label, der = traditional[0], traditional[1]()
    else:
        raise unsupported(f"PrivateFormat.{format.name}", _Reasons.UNSUPPORTED_SERIALIZATION)

    if encoding is Encoding.PEM:
        return _der.pem(label, der)
    if encoding is Encoding.DER:
        return der
    if encoding is Encoding.OpenSSH:
        raise ValueError("OpenSSH encoding is only valid with the OpenSSH format")
    raise ValueError("encoding is invalid with this key")


def public_bytes(encoding, format, *, spki, pkcs1=None, raw=None, point=None, openssh=None):
    """Writes a public key: `spki` returns its `SubjectPublicKeyInfo` DER, and each other argument, where the key has it, that encoding."""
    if not isinstance(encoding, Encoding):
        raise TypeError("encoding must be an item from the Encoding enum")
    if not isinstance(format, PublicFormat):
        raise TypeError("format must be an item from the PublicFormat enum")

    if encoding is Encoding.Raw or format is PublicFormat.Raw:
        if raw is None:
            raise ValueError("Raw format and encoding are only valid for X25519, Ed25519, X448, and Ed448 keys")
        if encoding is not Encoding.Raw or format is not PublicFormat.Raw:
            raise ValueError("When using Raw both encoding and format must be Raw")
        return raw()
    if encoding is Encoding.X962 or format in (PublicFormat.CompressedPoint, PublicFormat.UncompressedPoint):
        if point is None:
            raise ValueError("X962 encoding is only valid for EC keys")
        if encoding is not Encoding.X962 or format not in (PublicFormat.CompressedPoint, PublicFormat.UncompressedPoint):
            raise ValueError("X962 encoding must be used with CompressedPoint or UncompressedPoint format")
        return point(format is PublicFormat.CompressedPoint)
    if encoding is Encoding.OpenSSH or format is PublicFormat.OpenSSH:
        if encoding is not Encoding.OpenSSH or format is not PublicFormat.OpenSSH:
            raise ValueError("OpenSSH format must be used with OpenSSH encoding")
        if openssh is None:
            raise ValueError("OpenSSH encoding is not supported for this key type")
        return openssh()

    if format is PublicFormat.SubjectPublicKeyInfo:
        label, der = "PUBLIC KEY", spki()
    elif format is PublicFormat.PKCS1:
        if pkcs1 is None:
            raise ValueError("PKCS1 format is only valid for RSA keys")
        label, der = "RSA PUBLIC KEY", pkcs1()
    else:
        raise ValueError("format is invalid with this key")

    if encoding is Encoding.PEM:
        return _der.pem(label, der)
    if encoding is Encoding.DER:
        return der
    raise ValueError("encoding is invalid with this key")
