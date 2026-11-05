# [M] RSA-OAEP

## Goal

rind encrypts and decrypts RSA-OAEP with SHA-1, SHA-256, SHA-384, and SHA-512
(MGF1 on the same hash) and an optional label, as WebCrypto, pyca, and JWE's
`RSA-OAEP*` algorithms use it.

## Plan

- Decryption is constant time through the padding check, and every failure is
  the same error, so it is no Manger oracle; ctgrind covers it.
- Follow aws-lc-rs's API split between a public encrypting key and a private
  decrypting key, under rind's names.
