# [S] x86_64 AES-GCM's Vale glue is proven

## Goal

On x86_64 CPUs with AVX and MOVBE but no VAES, the Rust around HACL*'s Vale AES-GCM in `rind/src/low/x86_64/aes_gcm_avx.rs` is proven to meet the routines' preconditions and to make their result AES-GCM, so AES-GCM earns the report's ✓ there for messages and AAD under 2^32 bytes.

## Plan

Planned with the maintainer on 2026-11-03 from the audit. [moq-dev/rind#329](https://github.com/moq-dev/rind/pull/329) switched that tier to Vale for the whole AEAD: its key expansion, GHASH key powers, counter block, encryption, and tag check. Vale's proof (`Vale.Wrapper.X64.GCMencryptOpt`) covers it given EverCrypt's Low* wrapper, which rind's Rust mirrors: it copies the nonce and the partial blocks of the message and AAD to scratch, and splits the message into the six-block loop's share, the single blocks, and the partial block. Prove that Rust with the chosen tool, stating the routines' contracts as its axioms, then add the ✓ entries to `benchmarks/verified.toml`.

## Required

- [A Rust proof tool, proven on X25519](/quest/m3/verified/proof-tool.md) - the tool and composition rule this uses
