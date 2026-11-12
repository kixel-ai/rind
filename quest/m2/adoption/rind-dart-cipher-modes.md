# [M] AES-CBC, AES-CTR, and ChaCha20 in rind-dart and rind_cryptography

## Goal

rind-dart exposes the unauthenticated ciphers rind's `cipher` module has,
AES-CBC, AES-CTR, and ChaCha20, and
[rind_cryptography](/rind-dart/cryptography/README.md) backs the `cryptography`
package's `AesCbc`, `AesCtr`, and `Chacha20` with a MAC on them, rather than
throwing `UnsupportedError`.

## Plan

- `cryptography`'s `AesCbc` and `AesCtr` always pair the cipher with a
  `MacAlgorithm`, often HMAC, computed over the ciphertext; rind_cryptography
  composes rind's cipher with its own HMAC the way the package's Dart
  implementation does, and `MacAlgorithm.empty` yields the bare cipher.
- Its tests then drop `aes_cbc_test.dart`, `aes_ctr_test.dart`, and
  `chacha20_test.dart` from
  [compat/cryptography.txt](/rind-dart/cryptography/compat/cryptography.txt).
- It needs a rind-dart release before rind_cryptography can depend on it.

## Waiting

- Maintainer: keep this, since apps on `cryptography` use AES-CBC with HMAC
  for stored data and it fails on rind today (recommended), or drop it,
  since unauthenticated ciphers are what rind's API steers away from.
