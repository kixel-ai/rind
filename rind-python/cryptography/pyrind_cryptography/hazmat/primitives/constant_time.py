"""Constant-time comparison."""

import hmac


def bytes_eq(a, b):
    """Whether `a` and `b` are equal, in time independent of where they differ."""
    if not isinstance(a, bytes) or not isinstance(b, bytes):
        raise TypeError("a and b must be bytes.")
    return hmac.compare_digest(a, b)
