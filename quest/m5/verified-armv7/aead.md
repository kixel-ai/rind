# [M] armv7's AES-GCM AEAD API is proven

## Goal

`aead::Key`'s AES-GCM `new`, seal, and open on armv7, the code the `aes_gcm` benchmark rows call, are proven down to `mid::aes_gcm::AesGcm`, whose theorems `Rind/Armv7/AesGcm.lean` already proves on the tier without NEON or the crypto extension, so the armv7 ✓ needs only the tiers below `AesGcm`.

## Plan

- `admin/prove`'s `extract_armv7` starts from `{impl crate::aead::Cipher for crate::mid::aes_gcm::AesGcm}` and the `aead::Key` entry points x86_64's extraction starts from, keeping `aead::Key`'s other ciphers opaque as far as the translation allows.
- Adapt `Rind/X86_64/AesGcmAead.lean`'s AEAD section (`KeyReady`, `aes_gcm_new`, `aes_gcm_seal`, `aes_gcm_open`, and the tag variants) and the AES-GCM parts of `Rind/X86_64/GcmKey.lean` over armv7's `GcmReady`, and pin them in `Rind/Armv7/Axioms.lean`.
- State them over a `GcmReady` that any tier's proof can supply, so the NEON and crypto-extension quests only prove `AesGcm::new` and their `Parts`.

## Related

- [armv7's NEON AES and GHASH](/quest/m5/verified-armv7/neon-aes.md) - the NEON tier under the same API
- [armv7's assembly](/quest/m5/verified-armv7/assembly.md) - the crypto-extension tier under the same API
