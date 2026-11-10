# armv7 is proven

## Goal

Every operation rind exports earns the ✓ on 32-bit Arm, with and without NEON and the crypto extension, so `benchmarks/verified.toml` and the benchmark report carry armv7 cells.

## Plan

Most armv7 paths run assembly (aws-lc's, OpenSSL's, and BoringSSL's) for which no instruction model exists in any proof tool rind uses, so the model comes first. The rest is Rust that Aeneas translates as it does for the other targets.

## Required

- [armv7 runs the Rust proofs](/quest/m5/verified-armv7/prove.md) - `admin/prove` and the report take armv7, and its Rust-only paths earn the ✓
- [armv7's NIST curves are proven](/quest/m5/verified-armv7/nist-curves.md) - P-256, P-384, and P-521 over fiat-crypto and rind's `umaal` products
- [An AArch32 instruction model checks armv7's assembly](/quest/m5/verified-armv7/model.md) - the model every armv7 assembly proof needs
- [armv7's assembly is proven](/quest/m5/verified-armv7/assembly.md) - SHA-2, SHA-1, ChaCha20, Poly1305, AES, GHASH, Keccak, Montgomery products, and the compare
- [armv7's Curve25519 is proven](/quest/m5/verified-armv7/curve25519.md) - X25519 and Ed25519 over curve25519-dalek and BoringSSL's NEON X25519
