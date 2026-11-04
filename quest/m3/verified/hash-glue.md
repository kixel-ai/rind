# [M] The hash and KDF glue is proven

## Goal

rind's HMAC, HKDF, and PBKDF2 APIs, and the digest API for SHA-1 and SHA-256, are proven with Aeneas → Lean in `proofs/` down to the hash proofs already there, and the constant-time compare loops in HOL Light (they are inline asm), so these operations earn ✓ wherever their block functions are proven.

## Plan

Planned with the maintainer on 2026-11-03 from the audit. Each block function enters under [the epic's composition rule](/quest/m3/verified/README.md). HACL*'s HMAC and HKDF specs are the reference.

Done: SHA-1 and SHA-256's padding, finalization, and `Hash` impls, and HMAC's `HmacKey` and `Hmac` over any hash meeting `HashSpec`, against `proofs/Rind/HashSpec.lean`'s transliterations of FIPS 180-4, RFC 2104, RFC 5869, and RFC 8018. No SHA-1 or SHA-256 block function rind runs is proven, so those theorems take the routines' contracts as a hypothesis, `ShaBlocks`, rather than an axiom.

What remains:
- `hmac::Key`, `hmac::Context`, `hmac::sign`, `hmac::verify`, and `digest::digest` and `digest::Context` reach the hash through function pointers; model that dispatch by hand, as `Rind/X86_64/Dispatch.lean` does the agreement API's, and compose with `HashSpec`.
- HKDF and PBKDF2 call that hand-modelled HMAC API, but Aeneas emits one `Funs.lean` whose external declarations precede it, so translated code cannot call a model built on translated code. A second translation pass for the KDFs, with the first pass and the model opaque below it, avoids hand-modelling them.
- PBKDF2's `blocks` takes a closure that captures `&mut`, which Aeneas mistranslates; rewrite it as `Blockwise` was, keeping release codegen.
- The constant-time compares (`ct_compare_bytes`, behind `hmac::verify` and `pbkdf2::Secret::verify`).

## Related

- [x86_64 SHA-NI SHA-256 block function is proven](/quest/m3/verified/sha256-block.md) - discharges `ShaBlocks` for SHA-256 on that tier
- [SHA-512 padding is proven](/quest/m3/verified/sha512-padding.md) - SHA-384 and SHA-512 can meet `HashSpec` the same way, for HMAC over them
