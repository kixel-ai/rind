"""Unions of the key types, for annotations."""

import typing

from pyrind_cryptography.hazmat.primitives.asymmetric import ec, ed448, ed25519, rsa, x448, x25519

PublicKeyTypes = typing.Union[
    rsa.RSAPublicKey, ec.EllipticCurvePublicKey, ed25519.Ed25519PublicKey, ed448.Ed448PublicKey,
    x25519.X25519PublicKey, x448.X448PublicKey,
]
PrivateKeyTypes = typing.Union[
    ed25519.Ed25519PrivateKey, ed448.Ed448PrivateKey, rsa.RSAPrivateKey, ec.EllipticCurvePrivateKey,
    x25519.X25519PrivateKey, x448.X448PrivateKey,
]
CertificateIssuerPrivateKeyTypes = typing.Union[
    ed25519.Ed25519PrivateKey, ed448.Ed448PrivateKey, rsa.RSAPrivateKey, ec.EllipticCurvePrivateKey,
]
CertificateIssuerPublicKeyTypes = typing.Union[
    rsa.RSAPublicKey, ec.EllipticCurvePublicKey, ed25519.Ed25519PublicKey, ed448.Ed448PublicKey,
]
CertificatePublicKeyTypes = PublicKeyTypes

__all__ = [
    "CertificateIssuerPrivateKeyTypes", "CertificateIssuerPublicKeyTypes", "CertificatePublicKeyTypes",
    "PrivateKeyTypes", "PublicKeyTypes",
]
