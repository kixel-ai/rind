# [L] pyrind on PyPI

## Goal

`pip install pyrind` installs rind for Python, with rind's own API: AEADs,
hashes, HMAC, HKDF, PBKDF2, X25519, Ed25519, ECDSA and ECDH, RSA, and ML-KEM,
from wheels for every platform rind supports. A small-message AEAD or HMAC
call costs a fraction of pyca/cryptography's (about 4 µs for HMAC-SHA256 of
21 B on an i7-8700, almost all of it OpenSSL 3's per-call overhead).

## Plan

Decided with the maintainer on 2026-11-04, in a planning interview:

- Name: `pyrind` ✅ (PyPI's `rind` is an unrelated active project) /
  `rind-crypto`.
- Two packages, as rind and rind-ring are: this one with rind's own
  misuse-resistant API, and [a pyca-compatible one](/quest/m2/adoption/pyrind-cryptography.md)
  on top ✅ / one package with both APIs.
- It lives in this workspace as a `rind-python` crate (pyo3, maturin),
  released by this repository's CI ✅ / a separate repository.

Guidance:

- Use the stable ABI (abi3) so one wheel per platform covers every Python;
  publish with PyPI trusted publishing, keeping release credentials as the
  [m0 credentials quest](/quest/m0/confine-release-credentials.md) decides.
- Measure per-call cost from Python against `cryptography`, `hashlib`, and
  `hmac`, and publish the numbers with the package; the pitch is these
  numbers.
- Platforms rind refuses get no wheel; there is no pure-Python fallback.

## Required

- [rind builds on every platform its packages ship](/quest/m2/adoption/platforms.md) - the wheels' targets
