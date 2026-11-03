# [M] Fuzzing covers every hostile-input surface

## Goal

Every API that parses or processes attacker-controlled bytes has a fuzz target, and a nightly job runs them long enough to matter on a corpus it keeps between runs.

## Plan

Planned with the maintainer on 2026-11-03 from an external audit. Today five targets (aead, keys, kx, sha1, sha2) run 30 seconds each on a seeded, ephemeral corpus.

- Add targets for signature verification across every algorithm (hostile keys and signatures), HKDF and PBKDF2 parameters, XChaCha20-Poly1305, and ML-KEM decapsulation of hostile ciphertexts and keys, differential against aws-lc-rs where it has the algorithm.
- Keep the corpus between nightly runs (for example an Actions cache), and run long enough per target to find more than smoke.
- A crash or panic fails the nightly and alerts, as the other nightlies do.
