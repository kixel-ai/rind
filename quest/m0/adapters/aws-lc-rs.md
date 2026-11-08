# [M] rind-aws-lc-rs's signatures are aws-lc-rs 1.x's

## Goal

Code written for aws-lc-rs 1.x builds unchanged against rind-aws-lc-rs wherever rind backs the algorithm, and the adapter adds nothing upstream lacks.

## Plan

Found by diffing rustdoc JSON against aws-lc-rs 1.19.0 on 2026-11-08:

- `aead::LessSafeKey::open_in_place_separate_tag` (`src/aead.rs:262`) takes ring's `(nonce, aad, tag: Tag, in_out, ciphertext: RangeFrom<usize>)`; aws-lc-rs 1.17 and later take `(nonce, aad, tag: &[u8], in_out)`. Code written for aws-lc-rs fails to build against the adapter, so fix this first.
- `cipher::OperatingMode` and `rsa::KeySize` lack upstream's `#[non_exhaustive]`.
- Remove the `Debug` impl on `pbkdf2::Algorithm`, which upstream lacks.
- Implement `TryInto<PublicEncryptingKey> for PublicKeyComponents<B>` directly, as upstream does, instead of `TryFrom`.
- Add `kem::AlgorithmIdentifier::nid()`, returning AWS-LC's `NID_MLKEM768`.
- Make `kem::DecapsulationKey::{generate, encapsulation_key}`, `EncapsulationKey::new`, and `key_wrap::KeyEncryptionKey::new` generic, as upstream's are.
- Override `Error::description()` and `cause()` as upstream does.
- Remove the `cpu` module (`check` and `MissingFeature`).
- Gate `io`, `VerificationAlgorithm::verify`, and `From<untrusted::EndOfInput>` behind upstream's `ring-io` and `ring-sig-verify` features.
- Keep the `wipe` feature, documented in the README: aws-lc-rs always wipes, so rind needs the switch.
