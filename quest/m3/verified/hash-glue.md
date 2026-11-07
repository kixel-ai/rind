# [M] The hash and KDF glue is proven

## Goal

rind's HMAC, HKDF, and PBKDF2 APIs, and the digest API for SHA-1 and SHA-256, are proven with Aeneas → Lean in `proofs/` down to the hash proofs already there, HMAC over SHA-384 and SHA-512 included, and the constant-time compare loops in HOL Light (they are inline asm), so these operations earn ✓ wherever their block functions are proven.

## Plan

Planned with the maintainer on 2026-11-03 from the audit. Each block function enters under [the epic's composition rule](/quest/m3/verified/README.md). HACL*'s HMAC and HKDF specs are the reference.

`proofs/` already proves SHA-1 and SHA-256's `Hash` impls, and HMAC's `HmacKey` and `Hmac` over any hash meeting `HashSpec`, against `proofs/Rind/HashSpec.lean`, which also transliterates RFC 5869's HKDF and RFC 8018's PBKDF2. Unproven SHA-1 and SHA-256 block functions enter as the hypothesis `ShaBlocks`.

- `hmac::Key`, `hmac::Context`, `hmac::sign`, `hmac::verify`, and `digest::digest` and `digest::Context` reach the hash through function pointers; model that dispatch by hand, as `Rind/X86_64/Dispatch.lean` does the agreement API's, and compose with `HashSpec`.
- HKDF and PBKDF2 call that hand-modelled HMAC API, but Aeneas emits one `Funs.lean` whose external declarations precede it, so translated code cannot call a model built on translated code. Decided with the maintainer on 2026-11-04: translate the KDFs in a second Aeneas pass, with the first pass's items and the HMAC model opaque below it, rather than drop HMAC's function-pointer dispatch or hand-model the KDFs.
- PBKDF2's `blocks` takes a closure that captures `&mut`, which Aeneas mistranslates; rewrite it as `Blockwise` was, keeping release codegen.
- The constant-time compares (`ct_compare_bytes` and `ct_compare_16`, behind `hmac::verify` and `pbkdf2::Secret::verify`).
- HMAC over SHA-384 and SHA-512: their `Hash` impls meet `HashSpec` from `proofs/Rind/X86_64/Sha512.lean`'s theorems, whose SHA-512-specific padding and buffering lemmas `Blockwise.lean`'s generic ones can replace.

## Related

- [x86_64 SHA-NI SHA-256 block function is proven](/quest/m3/verified/sha256-block.md) - discharges `ShaBlocks` for SHA-256 on that tier
