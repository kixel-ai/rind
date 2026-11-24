## 0.1.1

- The unauthenticated ciphers: AES-CBC (`AesCbcEncryptingKey`,
  `AesCbcDecryptingKey`, `CbcIv`), AES-CTR (`AesCtr`), and ChaCha20
  (`ChaCha20`), sized by `CipherAlgorithm`.
- rind wipes a key's native memory when Dart frees the key.
- No call throws `UnsupportedError` for a missing CPU feature: rind runs on
  every CPU of each target it supports.
- An RSA `PublicKey` whose modulus is below its algorithm's floor parses, and
  `verify` throws `RindError.keyRejected`.

## 0.1.0

- rind's AEADs, digests, HMAC, HKDF, PBKDF2, key agreement, signatures,
  ML-KEM-768, and RSA-OAEP, through a prebuilt library the build hook
  downloads and checks against its pinned SHA-256, or built from source with
  the `build_from_source` user-define.
