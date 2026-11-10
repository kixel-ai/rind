"""pyca/cryptography's exceptions."""

import enum


class _Reasons(enum.Enum):
    BACKEND_MISSING_INTERFACE = 0
    UNSUPPORTED_HASH = 1
    UNSUPPORTED_CIPHER = 2
    UNSUPPORTED_PADDING = 3
    UNSUPPORTED_MGF = 4
    UNSUPPORTED_PUBLIC_KEY_ALGORITHM = 5
    UNSUPPORTED_ELLIPTIC_CURVE = 6
    UNSUPPORTED_SERIALIZATION = 7
    UNSUPPORTED_X509 = 8
    UNSUPPORTED_EXCHANGE_ALGORITHM = 9
    UNSUPPORTED_DIFFIE_HELLMAN = 10
    UNSUPPORTED_MAC = 11


class UnsupportedAlgorithm(Exception):
    """rind does not do this; pyca/cryptography may."""

    def __init__(self, message, reason=None):
        super().__init__(message)
        self._reason = reason


class AlreadyFinalized(Exception):
    """The context has already finished."""


class AlreadyUpdated(Exception):
    """The context has already taken data."""


class NotYetFinalized(Exception):
    """The context has not finished yet."""


class InvalidTag(Exception):
    """An AEAD ciphertext, its tag, or its associated data did not authenticate."""


class InvalidSignature(Exception):
    """A signature or MAC did not verify."""


class InternalError(Exception):
    """An internal consistency check failed."""

    def __init__(self, msg, err_code=()):
        super().__init__(msg)
        self.err_code = err_code


class InvalidKey(Exception):
    """A derived key did not match."""


def unsupported(what, reason=None):
    """The `UnsupportedAlgorithm` this package raises for what rind lacks."""
    return UnsupportedAlgorithm(f"{what} is not supported by rind", reason)
