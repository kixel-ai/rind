# [L] AES-GCM on aarch64 is proven

## Goal

AES-GCM earns the ✓ on aarch64 with the crypto extension (Graviton, Apple, Ampere, and the other Neoverse cores): rind's key setup, its short-message pass, and its glue around s2n-bignum's proven kernels are proven from the AEAD API down.

## Plan

- Runs (`low/aarch64/aes_gcm.rs`, `aes.rs`, `ghash.rs`): rind's NEON key expansion, PMULL GHASH key table, J0 and counter, AAD GHASH, partial blocks, length block, and tag; s2n-bignum's kernels for whole blocks; and up to 15 blocks sealed or 31 opened, rind's own one-pass Rust, which encrypts every counter block and the tag's and hashes with one reduction per eight blocks.
- Already proven: the kernels, against SP 800-38D, out of place ([aarch64's AES-GCM kernels proven in place](/quest/m4/verified/aes-gcm-aarch64-in-place.md) adds in place). Nothing of rind's Rust.
- Route: Aeneas to Lean, as `Rind/X86_64/AesGcm.lean` proves Vale's tier, with the kernels' theorems as axioms under the composition rule, and NEON intrinsics (`aese`, `aesmc`, `pmull`, `pmull2`, `eor3`, `ext`) modelled from the Arm manual as `Simd.lean` models Intel's. Reuse `Gf128.lean`'s Karatsuba lemmas, and [AES header protection](/quest/m4/verified/aes-header-protection.md)'s aarch64 AES models.
- AES-192, which the kernels lack, runs AES-CTR and GHASH in turn past the short pass's lengths; prove that composition here too.

## Required

- [aarch64's AES-GCM kernels are proven in place](/quest/m4/verified/aes-gcm-aarch64-in-place.md) - the kernels' contract as rind calls them
- [AES and QUIC AES header protection are proven with AES hardware](/quest/m4/verified/aes-header-protection.md) - aarch64's AES intrinsic models and key expansion
