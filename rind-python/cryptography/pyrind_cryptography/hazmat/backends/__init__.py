"""pyca/cryptography's backend accessor, which pyca has deprecated; rind is the only backend."""


class _Backend:
    """The rind backend; every call ignores it."""


_BACKEND = _Backend()


def default_backend():
    """The rind backend."""
    return _BACKEND


__all__ = ["default_backend"]
