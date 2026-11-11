# [L] armv7 runs the Rust proofs

## Goal

`admin/prove` translates and checks rind for armv7, `benchmarks/verified.toml` and `admin/bench-report` accept an `armv7` arch, and armv7's Rust-only paths earn the ✓: ChaCha20 header protection, SHA-256 and SHA-1 without the crypto extension, AES-GCM without it, and ML-KEM's arithmetic.

## Plan

- ChaCha20 header protection runs HACL*'s proven rounds on armv7 too, so its proof carries over once the target is translated.
- SHA-256 and SHA-1 without the crypto extension run Graviola's and rind's portable Rust (`low/generic/sha256.rs`, `sha1.rs`): prove them with Aeneas against FIPS 180-4.
- AES-GCM without the crypto extension runs rind's copy of libcrux's bitsliced block cipher, which libcrux marks pre-verification, with rind's port of `gcm_nohw.c`: prove both with Aeneas, or the block cipher by a libcrux proof if one lands first.
- ML-KEM's portable arithmetic is [its own quest](/quest/m4/verified/mlkem-portable.md); its Keccak-f is assembly, in [armv7's assembly](/quest/m5/verified-armv7/assembly.md).
- Poly1305 without NEON is libcrux's HACL\*-compiled Rust, which `benchmarks/verified.toml` counts, under rind's glue.
