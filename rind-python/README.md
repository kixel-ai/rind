# pyrind

Cryptography for Python from [rind](https://github.com/moq-dev/rind), a
pure-Rust library: AEADs, hashes, HMAC, HKDF, PBKDF2, X25519, Ed25519, ECDSA
and ECDH, RSA, and ML-KEM, with rind's own misuse-resistant API.

```shell
pip install pyrind
```

## Why

A Python call into pyca/cryptography pays OpenSSL 3's per-call setup, which
dwarfs the work on a small message. pyrind's calls go straight to rind's
assembly:

<!-- bench -->

Run `sh/python.sh bench` in the repository for your own machine's numbers.

## Use

Each rind module is a submodule. Algorithms are constants, and a key is
made for one algorithm, so the wrong combination fails before any data
moves: passing a hash where a key wants an AEAD algorithm raises `TypeError`.

```python
import os
from pyrind import aead, digest, hkdf, hmac, signature
from pyrind.signature import sign, verify

# Hashes and MACs.
digest.digest(digest.SHA256, b"hello")
key = hmac.Key(hmac.HMAC_SHA256, b"secret")
tag = hmac.sign(key, b"message")
hmac.verify(key, b"message", tag)  # raises pyrind.BadSignature on a mismatch

# AEAD with the caller's nonces, which must never repeat under one key. The
# associated data is keyword-only, so it can't be swapped with the plaintext.
key = aead.Key(aead.AES_256_GCM, os.urandom(32))
sealed = key.seal(bytes(12), b"plaintext", aad=b"header")
assert key.open(bytes(12), sealed, aad=b"header") == b"plaintext"

# Or random 192-bit nonces, with no nonce state.
key = aead.RandomizedNonceKey(os.urandom(32))
nonce, sealed = key.seal(b"plaintext", aad=b"")
assert key.open(nonce, sealed, aad=b"") == b"plaintext"

# HKDF expands straight into keys, whose bytes never reach Python.
prk = hkdf.Salt(hkdf.HKDF_SHA256, b"salt").extract(b"input key material")
aead_key = prk.expand(b"aead", aead.AES_256_GCM)

# Signatures: a key pair signs with a `sign` algorithm, and a peer's public
# key is parsed for a `verify` algorithm.
key_pair = signature.EcdsaKeyPair.generate(sign.ECDSA_P256_SHA256_ASN1)
signed = key_pair.sign(b"message")
public_key = signature.PublicKey(verify.ECDSA_P256_SHA256_ASN1, bytes(key_pair.public_key()))
public_key.verify(b"message", signed)
```

The modules are `aead`, `agreement` (X25519 and ECDH), `cpu`, `digest`,
`hkdf`, `hmac`, `kem` (ML-KEM-768), `pbkdf2`, `rsa` (RSA-OAEP), and
`signature` (ECDSA, Ed25519, and RSA). Algorithms only legacy protocols
should use, such as SHA-1 and MD5, live in each module's `legacy` submodule.
Keys load from and encode to PKCS#8, SEC1, PKCS#1, and
`SubjectPublicKeyInfo` DER. The package ships type stubs, and
[rind's documentation](https://docs.rs/rind/) describes each operation in
depth.

Every failure raises a subclass of `pyrind.Error`: `WrongLength`,
`KeyRejected` (whose message says why), `BadSignature`, `DecryptFailed`,
`RngFailed`, `Unsupported`, or `Fault`. Arguments take any bytes-like object;
anything but `bytes` is copied first, so no other thread can change it
mid-call. RSA key generation, RSA signing and decryption, and PBKDF2 release
the GIL while they run.

rind wipes keys and keyed state when Python frees them. It cannot wipe the
`bytes` a key was loaded from or exported to; Python owns those.

## Platforms

Wheels cover CPython 3.11 and later through the stable ABI, on Linux (glibc
2.17 and later on x86_64, aarch64, and armv7; musl on x86_64 and aarch64),
macOS on x86_64 and Apple silicon, and Windows on x86_64 and aarch64. PyPy,
free-threaded CPython, and other platforms build the sdist, which needs a
Rust toolchain. rind runs only on x86_64, aarch64, and 32-bit arm, so other
architectures fail to build; there is no pure-Python fallback.

Importing pyrind raises `ImportError` on a CPU missing a feature rind
requires, naming it, rather than failing later.

## License

pyrind carries rind's licenses: rind's own code is Apache-2.0, ISC, or
MIT-0, at your option, and the code it copies keeps its source's license, as
[LICENSE](LICENSE) lists.
