# [XS] AES-GCM's custom-IV key is proven for 12-byte IVs and full tags on the Vale tier

## Goal

`aead::gcm::Key`'s seal and open are proven on the Vale tier for 12-byte IVs and full 16-byte tags, where they call the proven `aead::Key`, under the same bounds as its theorems. Other IV lengths and truncated tags are out of scope: `proofs/README.md` names them as unproven here and names the quest that owns them.

## Plan

Planned with the maintainer on 2026-11-07, a follow-up of [moq-dev/rind#477](https://github.com/moq-dev/rind/pull/477), which proved `seal_in_place_append_tag` on the Vale tier.

Scope (maintainer, 2026-11-09): ✅ m4 owns the other inputs (rejected: m3 proves every IV and tag length; leave both and let whichever starts first take them). This quest had "prove them if the Vale-tier model reaches, otherwise record the gap", which overlapped [the by-8 intrinsics quest](/quest/m4/verified/aes-gcm-x86-intrinsics.md)'s Goal. Re-sized from S to XS: what is left is glue over theorems that exist.

- In scope: `Key::new`, and the arms of `seal_in_place_separate_tag` and `open` that convert a 12-byte IV to a `Nonce` and call `aead::Key` (`rind/src/aead/gcm.rs:157-161`, `:231-236`), with `seal_in_place_append_tag`, `open_in_place`, and `open_in_place_separate_tag` over them, for a key made with the full tag length. Each theorem restates `aes_gcm_seal`, `aes_gcm_seal_append_tag`, or `aes_gcm_open` of `Rind/X86_64/AesGcm.lean`, with their hypotheses and bounds: `RunsValeAesGcm`, AES-128 or AES-256, AAD and messages under 2^32 bytes, seals of 129 bytes and more.
- Out of scope, and why they are not glue: any other IV length reaches `encrypt_any` or `decrypt_any` (`rind/src/mid/aes_gcm.rs:103`, `:128`), which hash the IV into the counter block and run rind's by-8 kernels, not Vale's routines; a truncated tag opens through `decrypt_any` too, whatever the IV (`gcm.rs:237`). A 12-byte IV sealed under a truncated tag length does take the proven call and keep a prefix of its tag (`gcm.rs:153-161`), but its open does not, so truncated tags stay whole with the quest that owns them.

## Related

- [x86_64's by-8 and by-16 AES-GCM intrinsics are proven](/quest/m4/verified/aes-gcm-x86-intrinsics.md) - owns the other IV lengths and truncated tags: `encrypt_any`, `decrypt_any`, and the `aead::gcm::Key` arms that call them
