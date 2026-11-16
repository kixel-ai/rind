## 0.2.0

- Breaking: ECDSA, Ed25519, and RSA each have a key pair and a public key of
  their own, as rind 0.4's `ecdsa`, `ed25519`, and `rsa` modules do, in place
  of one `PublicKey` for every algorithm. A public key's constructor takes the
  algorithm's own encoding, `fromSpki` a `SubjectPublicKeyInfo`, and `toSpki`
  lives only on the public key. An RSA public key takes PKCS#1, is bound to no
  algorithm, and refuses a modulus below the algorithm's floor at `verify`.
  Each key pair's `publicKey` returns the same object each time.
- Breaking: `RsaEncryptingKey(algorithm, der)` takes PKCS#1 only, and
  `RsaEncryptingKey.fromSpki` a `SubjectPublicKeyInfo`.
- The unauthenticated ciphers: AES-CBC (`AesCbcEncryptingKey`,
  `AesCbcDecryptingKey`, `CbcIv`), AES-CTR (`AesCtr`), and ChaCha20
  (`ChaCha20`), sized by `CipherAlgorithm`.

| 0.1.0 | 0.2.0 |
|---|---|
| `PublicKey` | `EcdsaPublicKey`, `Ed25519PublicKey`, or `RsaPublicKey` |
| `VerificationAlgorithm` | `EcdsaVerificationAlgorithm` or `RsaVerificationAlgorithm`; Ed25519 takes none |
| `VerificationAlgorithm.ecdsaP256Sha256Asn1`, and each `ecdsa…` constant | `EcdsaVerificationAlgorithm.p256Sha256Asn1`, without `ecdsa` |
| `VerificationAlgorithm.ed25519` | none |
| `VerificationAlgorithm.rsaPkcs1Sha256`, and each `rsa…` constant | `RsaVerificationAlgorithm.pkcs1Sha256`, without `rsa` |
| `RsaVerificationAlgorithm`, a `VerificationAlgorithm` | `RsaVerificationAlgorithm`, a class of its own |
| `rsaPkcs1Sha1`, `rsaPkcs1Min1024Sha1`, `rsaPkcs1Min1024Sha256`, `rsaPkcs1Min1024Sha512`, `rsaPkcs1Min3072Sha384` | unchanged, in `package:rind/legacy.dart` |
| `PublicKey(ecdsaAlgorithm, point)` | `EcdsaPublicKey(algorithm, point)` |
| `PublicKey.fromSpki(ecdsaAlgorithm, der)` | `EcdsaPublicKey.fromSpki(algorithm, der)` |
| `PublicKey(VerificationAlgorithm.ed25519, bytes)` | `Ed25519PublicKey(bytes)` |
| `PublicKey.fromSpki(VerificationAlgorithm.ed25519, der)` | `Ed25519PublicKey.fromSpki(der)` |
| `PublicKey(rsaAlgorithm, der)`, PKCS#1 or SPKI | `RsaPublicKey(der)`, PKCS#1, or `RsaPublicKey.fromSpki(der)` |
| `PublicKey.fromSpki(rsaAlgorithm, der)` | `RsaPublicKey.fromSpki(der)` |
| `PublicKey.fromComponents(rsaAlgorithm, n: n, e: e)` | `RsaPublicKey.fromComponents(n: n, e: e)` |
| `rsaPublicKey.verify(message, signature)` | `rsaPublicKey.verify(algorithm, message, signature)` |
| none | `RsaPublicKey.modulusLength` |
| `EcdsaKeyPair.publicKey`, a new `PublicKey` each time | `EcdsaKeyPair.publicKey`, the same `EcdsaPublicKey` each time |
| `Ed25519KeyPair.publicKey`, a new `PublicKey` each time | `Ed25519KeyPair.publicKey`, the same `Ed25519PublicKey` each time |
| `RsaKeyPair.publicKey(algorithm)` | `RsaKeyPair.publicKey`, the same `RsaPublicKey` each time |
| `RsaDecryptingKey.publicKey`, a new `RsaEncryptingKey` each time | `RsaDecryptingKey.publicKey`, the same one each time |
| `EcdsaKeyPair.toSpki()`, `Ed25519KeyPair.toSpki()`, `RsaKeyPair.toSpki()`, `RsaDecryptingKey.toSpki()` | `publicKey.toSpki()` |
| `RsaEncryptingKey(algorithm, der)`, PKCS#1 or SPKI | `RsaEncryptingKey(algorithm, der)`, PKCS#1, or `RsaEncryptingKey.fromSpki(algorithm, der)` |

## 0.1.0

- rind's AEADs, digests, HMAC, HKDF, PBKDF2, key agreement, signatures,
  ML-KEM-768, and RSA-OAEP, through a prebuilt library the build hook
  downloads and checks against its pinned SHA-256, or built from source with
  the `build_from_source` user-define.
