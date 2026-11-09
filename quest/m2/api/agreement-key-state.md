# [S] Agreement keys keep their public key and algorithm

## Goal

`agreement::PrivateKey::public_key()` and `to_pkcs8()` return the public key computed when the key was generated or loaded, instead of a fresh base-point multiplication on every call. Agreement keys report their algorithm, and their `Debug` shows it, as the other key types' do. rind-rustls and rind-aws-lc-rs drop the public-key caches they keep to work around the cost. `signature::EcdsaKeyPair::public_key()` likewise stops re-parsing its cached point.

## Plan

- Today X25519's `public_key()` runs a full scalar multiplication (`mid/x25519.rs`), each NIST curve's runs `base_multiply`, and `to_pkcs8()` repeats it. PKCS#8 and SEC1 loaders that carry a public key already compute it to check consistency, then discard it.
- Store the encoded public key (at most 133 bytes) in the key at generate and load time, and reuse it for `public_key()`, `to_pkcs8()`, and the loaders' consistency check. It is public, so it is not wiped.
- Add `algorithm()` to `agreement::PrivateKey` and `PublicKey`, and `PartialEq`/`Eq` to `agreement::Algorithm`, as aws-lc-rs and ring have. `PrivateKey`'s `Debug` shows the algorithm, the 0.2.0 audit's open follow-up ([moq-dev/rind#383](https://github.com/moq-dev/rind/pull/383)).
- Adapter caches to remove: `rind-rustls/src/kx_group.rs` (around line 73), and the `algorithm` tracking and cached public key in `rind-aws-lc-rs/src/agreement.rs`.
- `EcdsaKeyPair::public_key()` re-parses its point and returns a `PublicKey` with empty verify caches. Build it directly from the cached point.
- Additive. Measure `public_key()` and a rind-rustls handshake before and after, against aws-lc-rs.
