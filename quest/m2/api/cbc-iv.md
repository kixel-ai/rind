# [S] AES-CBC encryption takes a typed IV

## Goal

`cipher::AesCbcEncryptingKey`'s `encrypt` and `encrypt_blocks` take an IV type that is either drawn from the system's random source or explicitly asserted unpredictable by the caller. A zero, constant, or counter IV, which leaks whether a plaintext block equals one an attacker chose, is then never the easy path.

## Plan

- Decided with the maintainer on 2026-11-08: take this breaking change for rind 0.4 ✅ (rejected: document only). aws-lc-rs draws the IV itself and names the caller-IV path `less_safe_encrypt`.
- Recommended shape, following `aead::Nonce::assume_unique_for_key` and `gcm::Iv`: `cbc::Iv::random()?` and `Iv::assume_unpredictable([u8; 16])`, not `Clone`, consumed per call, with the bytes readable so the caller can send them. Decryption keeps a plain `&[u8; 16]`, since a received IV is public. One way per job: no second `encrypt` that takes raw bytes.
- Update every caller: rind-aws-lc-rs (`less_safe_encrypt` maps to `assume_unpredictable`, and its random-IV path to `random`), the benches, the timing cases, the fuzzer, the tests, and MIGRATING.md. The title takes `!` with the migration.
- Unrelated to [Check CBC consumers for padding-oracle exposure](/quest/m3/cbc-padding-oracle.md), which traces decryption.
