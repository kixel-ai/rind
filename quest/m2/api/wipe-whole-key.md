# [XS] Key types wipe their whole value

## Goal

Under `wipe`, every key type's drop wipes its whole value, public parts included, so `rind/tests/zeroing.rs` checks every byte with no per-type skip.
`agreement::PrivateKey`, which [moq-dev/rind#529](https://github.com/moq-dev/rind/pull/529) makes wipe only its private part, goes back to a whole-value wipe, and its zeroing skip goes.
AGENTS.md's wipe rule says a key type wipes its whole value and why; its "wipe nothing else" still covers digest contexts, decrypted messages, and temporaries.

## Plan

Decided with the maintainer on 2026-11-09, while planning #529's follow-up (✅ chosen):

- Rule: ✅ a key type wipes its whole value (rejected: secrets and stored public keys only; secrets only, with per-type skips in the zeroing test; change only `Ed25519KeyPair`; leave #529 as the lone exception).
- Why: six types already wipe non-secret parts so the zeroing test can check every byte (`Ed25519KeyPair`, `EcdsaKeyPair`, `RsaKeyPair`, `oaep::DecryptingKey`, `AesCtr`, `AesCbcEncryptingKey`). That check is what caught the padding and enum-tail leaks fixed in moq-dev/rind#513 and moq-dev/rind#524. FIPS 140-3 (ISO/IEC 19790 7.9.7, NIST IG 9.7) also requires zeroising unprotected public security parameters such as stored public keys. A few more bytes written when a key drops cost nothing measurable.
- AGENTS.md: ✅ state the rule there (rejected: leave its wording alone). This replaces #529's 2026-11-09 decision to wipe only `PrivateKey`'s private part.
- Placement: ✅ m2 api epic (rejected: m0, m3).

Start once #529 has landed. Update REVIEW.md's "Wiped secrets" check to match.
