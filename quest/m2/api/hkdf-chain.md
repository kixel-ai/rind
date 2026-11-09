# [S] HKDF output keys the next expand

## Goal

A caller turns one HKDF-Expand's output into the PRK of the next expand through rind's types, as QUIC's Initial secrets, TLS 1.3's key schedule, and MLS chain them, without writing HKDF-Expand over `hmac::Context` or re-extracting the bytes, which runs an extra HMAC and derives different keys. rind-ring and rind-aws-lc-rs drop their hand-written copies of Expand.

## Plan

- Recommended shape: `impl KeyType for &'static hkdf::Algorithm` (hash-length output) and `From<Okm<'_, &'static hkdf::Algorithm>> for Prk`, matching the existing `aead::Key::from(okm)` and `hmac::Key::from(okm)`. This keeps rind's sealed `KeyType`, and adds no `Prk::new_less_safe`.
- The copies to delete: `rind-ring/src/hkdf.rs` `expand_into` and `rind-aws-lc-rs/src/hkdf.rs` (around line 123). Check whether either adapter can then map its own `Prk::from(okm)` and `Salt::from(okm)` onto the new conversion.
- Update MIGRATING.md's hkdf rows, which list `Prk::from(okm)` as "none".
- Test a chained expand against RFC 9001's Appendix A Initial secrets, and differentially against aws-lc-rs's `Prk::from(Okm)`.
- [HKDF-SHA256 expand is back to its earlier speed](/quest/m2/speed/hkdf-expand-regression.md) touches the same code for speed; merge with it rather than conflict.
