"""X.509, which rind does not parse: every loader raises `UnsupportedAlgorithm`."""

from pyrind_cryptography.exceptions import _Reasons, unsupported


def _refuse(name):
    def load(*args, **kwargs):
        raise unsupported("X.509", _Reasons.UNSUPPORTED_X509)

    load.__name__ = load.__qualname__ = name
    load.__doc__ = f"pyca's {name}; rind has no X.509 parser, so this raises `UnsupportedAlgorithm`."
    return load


load_der_x509_certificate = _refuse("load_der_x509_certificate")
load_pem_x509_certificate = _refuse("load_pem_x509_certificate")
load_pem_x509_certificates = _refuse("load_pem_x509_certificates")
load_der_x509_csr = _refuse("load_der_x509_csr")
load_pem_x509_csr = _refuse("load_pem_x509_csr")
load_der_x509_crl = _refuse("load_der_x509_crl")
load_pem_x509_crl = _refuse("load_pem_x509_crl")

__all__ = [
    "load_der_x509_certificate", "load_der_x509_crl", "load_der_x509_csr", "load_pem_x509_certificate",
    "load_pem_x509_certificates", "load_pem_x509_crl", "load_pem_x509_csr",
]
