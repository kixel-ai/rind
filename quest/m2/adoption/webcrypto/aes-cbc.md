# [S] AES-CBC

## Goal

rind encrypts and decrypts AES-CBC with PKCS#7 padding, as WebCrypto,
pyca's `modes.CBC`, and Dart's `AesCbc` use it, with unpadded CBC only if a
consumer needs it.

## Plan

- Decryption checks the padding in constant time and reports its failure as
  any other failure. That leaks nothing beyond the result, but unauthenticated
  CBC is still a padding oracle to anyone who can submit ciphertexts, so the
  docs say to verify a MAC over the ciphertext first, or use an AEAD.
- Encryption is serial, decryption parallel: take the fastest permissive
  source per backend (aws-lc's assembly where it exists).
