## Unreleased

- `AesCbc`, `AesCtr`, and `Chacha20` with a MAC, such as `Hmac`, on rind's
  ciphers, which need the rind release after 0.1.0.
- `AesGcm` takes nonces of any length but zero, and `RsaPss` signs and
  verifies with its `nonceLengthInBytes`, its default 16 bytes included,
  where it signed only with a salt as long as the hash and verified any
  salt otherwise. Both need the rind release after 0.1.0.

## 0.1.0

- The cryptography package's `Cryptography` on rind 0.1.0: SHA-1 and
  SHA-2, HMAC, HKDF, PBKDF2, AES-GCM, ChaCha20-Poly1305 and
  XChaCha20-Poly1305, X25519, Ed25519, ECDH, ECDSA, and RSA signatures.
