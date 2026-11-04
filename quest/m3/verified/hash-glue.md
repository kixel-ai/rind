# [M] The hash and KDF glue is proven

## Goal

rind's SHA-1 and SHA-256 padding and finalization, HMAC, HKDF, and PBKDF2 are proven with the chosen tool, and the constant-time compare loops in HOL Light (they are inline asm), so these operations earn ✓ wherever their block functions are proven.

## Plan

Planned with the maintainer on 2026-11-03 from the audit. Reuse the composition rule and structure from [SHA-512 padding is proven](/quest/m3/verified/sha512-padding.md) for the shared padding code. HACL*'s HMAC and HKDF proofs are the reference spec to match.

## Required

- [A Rust proof tool, proven on X25519](/quest/m3/verified/proof-tool.md) - the tool and composition rule this uses
