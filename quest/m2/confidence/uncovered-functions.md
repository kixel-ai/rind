# [S] Every published function runs under a test

## Goal

The nightly coverage report, on both Linux/x86_64 and macOS/aarch64, lists no function in the published code that never runs. Each one it listed gets a test that reaches it, or is deleted as dead code. A function only another architecture compiles counts as covered when that architecture's run reaches it.

## Plan

Planned with the maintainer on 2026-11-12, with the coverage report's goal: no percentage target, just no unrun function left without a reason.

[kixel-ai/rind#862](https://github.com/kixel-ai/rind/pull/862) reached every function the report listed in `rind` and the Rust adapters. It also deleted dead code, and listed in TESTING.md's Coverage section what stays unrun and why. What remains is the bindings that pyrind's and rind for Dart's 0.4 reshapes rewrite. Testing their current code would only conflict with those rewrites.

- pyrind: the `rsa.rs` and `signature.rs` functions no test calls, such as `to_spki` on each key, `rsa::DecryptingKey::from_pkcs1` and `to_pkcs8`, `rsa::EncryptingKey::from_components`, `rsa::KeySize`'s default, `EcdsaKeyPair::to_sec1`, and `Ed25519KeyPair::to_seed` and `from_seed_and_public_key`, or whatever their reshaped successors are.
- rind for Dart: `PublicKey::to_spki` and the two closures in `rind_dart_public_key_new`, or their successors.
- Then recount with a dispatched `coverage` run on both runners. That run also confirms what kixel-ai/rind#792's adapter tests reach, since #862 left those functions to it.

## Required

- [pyrind takes rind 0.4's shape](/quest/m2/api/pyrind-shape.md) - rewrites the pyrind functions left unrun
- [rind for Dart takes rind 0.4's shape](/quest/m2/api/rind-dart-shape.md) - rewrites the rind-dart functions left unrun
