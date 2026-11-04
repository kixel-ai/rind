# [S] AES-CBC

## Goal

rind encrypts and decrypts AES-CBC with PKCS#7 padding, as WebCrypto,
pyca's `modes.CBC`, and Dart's `AesCbc` use it, with unpadded CBC only if a
consumer needs it.

## Plan

- Decryption reports a padding failure the same way, and in the same time, as
  any other failure, so it is no padding oracle. CBC is unauthenticated; the
  docs say to pair it with a MAC.
- Encryption is serial, decryption parallel: take the fastest permissive
  source per backend (aws-lc's assembly where it exists).
