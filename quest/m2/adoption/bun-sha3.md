# [S] Bun's CryptoHasher takes SHA-3 from rind

## Goal

Bun's `CryptoHasher` computes SHA3-256, SHA3-384, and SHA3-512 with rind
instead of RustCrypto. `sha3-224`, outside aws-lc-rs's set, stays on
RustCrypto.

## Plan

Split from [Bun's asymmetric crypto](/quest/m1/bun.md) on 2026-11-05, so that
PR could start before rind has SHA-3. Measure against Bun's current RustCrypto
path on Bun's targets, and move only what rind does faster.

## Required

- [Bun runs its fastest asymmetric crypto on rind](/quest/m1/bun.md) - the Bun integration this extends
- [SHA-3](/quest/m2/adoption/webcrypto/sha3.md) - the digests
