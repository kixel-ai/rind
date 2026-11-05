# [S] SHA-3

## Goal

rind exports SHA3-256, SHA3-384, and SHA3-512 digests on every target,
including armv7, for Bun's `CryptoHasher` and node:crypto hashes, WebCrypto
adopters, pyrind, and Dart.

## Plan

- rind already runs Keccak-f for ML-KEM on every backend (armv7 on OpenSSL's
  assembly), but compiles SHA-3 out on armv7 for want of a consumer
  (maintainer, 2026-10-27). These consumers reverse that: the same API on
  every target, no per-target exclusion.
- SHAKE128 and SHAKE256 join if Bun's slice needs them; check when starting.
- Benchmark against aws-lc-rs and RustCrypto's sha3, which Bun uses today.
