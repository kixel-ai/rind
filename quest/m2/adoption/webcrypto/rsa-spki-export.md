# [S] RSA public keys export as SPKI

## Goal

`rsa::EncryptingKey` and `signature::PublicKey`'s RSA keys export as SubjectPublicKeyInfo, for WebCrypto's `exportKey("spki")`, matching the SPKI import [moq-dev/rind#361](https://github.com/moq-dev/rind/pull/361) added.

## Plan

Today only the private key types export SPKI, and public keys export PKCS#1. Add the export alongside the existing one, with the same `NULL` parameters rind requires on import, and check it round-trips through aws-lc-rs and through rind's own import.
