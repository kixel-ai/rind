# [S] AES-GCM's custom-IV key is proven on the Vale tier

## Goal

`aead::gcm::Key`'s seal and open are proven on the Vale tier for 12-byte IVs and full 16-byte tags, where they call the proven `aead::Key`. Its other IV lengths and truncated tags, which run `encrypt_any` and `decrypt_any` (`rind/src/mid/aes_gcm.rs`), are proven too or recorded as a gap with its reason in the proof coverage.

## Plan

Planned with the maintainer on 2026-11-07, a follow-up of [moq-dev/rind#477](https://github.com/moq-dev/rind/pull/477), which proved `seal_in_place_append_tag` on the Vale tier.

- The 12-byte, full-tag case is mostly glue over `aead::Key`'s theorems.
- `encrypt_any`/`decrypt_any` derive the counter block from GHASH over the IV and may truncate the tag; prove them if the Vale-tier model reaches, otherwise record the gap so the ✓ names its scope.
