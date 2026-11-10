"""RSA paddings: PKCS#1 v1.5 and PSS signatures, and OAEP encryption."""

import abc

from pyrind_cryptography.hazmat.primitives import hashes


class AsymmetricPadding(metaclass=abc.ABCMeta):
    """An RSA padding."""

    name: str


class PKCS1v15(AsymmetricPadding):
    """PKCS#1 v1.5 padding, which rind signs and verifies with but never encrypts with."""

    name = "EMSA-PKCS1-v1_5"

    def __eq__(self, other):
        if not isinstance(other, PKCS1v15):
            return NotImplemented
        return True


class _MaxLength:
    "Sentinel value for `MAX_LENGTH`."


class _Auto:
    "Sentinel value for `AUTO`."


class _DigestLength:
    "Sentinel value for `DIGEST_LENGTH`."


class PSS(AsymmetricPadding):
    """PSS padding, whose salt rind makes as long as the digest; it verifies any salt length with `AUTO`."""

    MAX_LENGTH = _MaxLength()
    AUTO = _Auto()
    DIGEST_LENGTH = _DigestLength()
    name = "EMSA-PSS"

    def __init__(self, mgf, salt_length):
        self._mgf = mgf
        if not isinstance(salt_length, (int, _MaxLength, _Auto, _DigestLength)):
            raise TypeError("salt_length must be an integer, MAX_LENGTH, DIGEST_LENGTH, or AUTO")
        if isinstance(salt_length, int) and salt_length < 0:
            raise ValueError("salt_length must be zero or greater.")
        self._salt_length = salt_length

    def __eq__(self, other):
        if not isinstance(other, PSS):
            return NotImplemented
        return self._mgf == other._mgf and self._salt_length == other._salt_length

    @property
    def mgf(self):
        return self._mgf


class OAEP(AsymmetricPadding):
    """OAEP padding with `algorithm` and its MGF1, and a `label`."""

    name = "EME-OAEP"

    def __init__(self, mgf, algorithm, label):
        if not isinstance(algorithm, hashes.HashAlgorithm):
            raise TypeError("Expected instance of hashes.HashAlgorithm.")
        self._mgf = mgf
        self._algorithm = algorithm
        self._label = label

    def __eq__(self, other):
        if not isinstance(other, OAEP):
            return NotImplemented
        return self._mgf == other._mgf and self._algorithm == other._algorithm and self._label == other._label

    @property
    def algorithm(self):
        return self._algorithm

    @property
    def mgf(self):
        return self._mgf


class MGF(metaclass=abc.ABCMeta):
    """A mask generation function."""

    _algorithm: hashes.HashAlgorithm


class MGF1(MGF):
    """MGF1 over `algorithm`."""

    def __init__(self, algorithm):
        if not isinstance(algorithm, hashes.HashAlgorithm):
            raise TypeError("Expected instance of hashes.HashAlgorithm.")
        self._algorithm = algorithm

    def __eq__(self, other):
        if not isinstance(other, MGF1):
            return NotImplemented
        return self._algorithm == other._algorithm


def calculate_max_pss_salt_length(key, hash_algorithm):
    """The longest PSS salt `key` takes with `hash_algorithm`."""
    from pyrind_cryptography.hazmat.primitives.asymmetric import rsa

    if not isinstance(key, (rsa.RSAPrivateKey, rsa.RSAPublicKey)):
        raise TypeError("key must be an RSA public or private key")
    salt_length = (key.key_size + 6) // 8 - hash_algorithm.digest_size - 2
    assert salt_length >= 0
    return salt_length


__all__ = ["AsymmetricPadding", "MGF", "MGF1", "OAEP", "PKCS1v15", "PSS", "calculate_max_pss_salt_length"]
