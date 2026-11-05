# [S] Loading an Ed25519 key costs less than a signature

## Goal

Bun's node:crypto path, which loads an Ed25519 key from PEM on every sign call, is no slower on rind than on BoringSSL. Today it is 0.93x, about 2 µs.

## Plan

Found by the Bun prototype ([moq-dev/rind#368](https://github.com/moq-dev/rind/pull/368)). `Ed25519KeyPair::from_seed_and_public_key` and `from_pkcs8` recompute the public key from the seed to check it, which is a base-point multiplication, as costly as signing. BoringSSL's load skips that check.

Find where the time goes, then pick the fix that keeps misuse unrepresentable. For example, a cheaper check, a load that derives the public key once and lets the caller keep the pair, or a reason the check must stay. Don't add a `_unchecked` variant: AGENTS.md rules that out. The Ed25519 proof (`proofs/Rind/X86_64/Ed25519.lean`) covers `from_seed_and_public_key`; keep it passing, or update it. Benchmark against aws-lc-rs and BoringSSL.
