# [S] rind-rcgen's KeyPair is rcgen's

## Goal

rind-rcgen's `KeyPair` has rcgen's built-in `KeyPair` API, so code written against rcgen's `crypto` feature swaps in rind-rcgen's type unchanged.

## Plan

Decided with the maintainer on 2026-11-08: match rcgen's `KeyPair` ✅ (rejected: keep rind-rcgen's names).

- `generate(alg)` becomes `generate_for(alg)`, and `generate()` takes no argument and makes a P-256 key, as rcgen's does.
- `from_pkcs8(alg, der)` becomes `from_pkcs8_der_and_sign_algo(der, alg)`. Add `from_der_and_sign_algo` and the `TryFrom` impls for `&[u8]`, `Vec<u8>`, `&PrivatePkcs8KeyDer`, and `&PrivateKeyDer`.
- `to_pkcs8() -> Zeroizing<PrivatePkcs8KeyDer>` becomes rcgen's `serialize_der() -> Vec<u8>`, `serialized_der() -> &[u8]`, and `From<KeyPair> for PrivatePkcs8KeyDer`. This reverses the 0.2.0 audit's decision to keep `Zeroizing` ([moq-dev/rind#383](https://github.com/moq-dev/rind/pull/383)), and drops a wipe AGENTS.md's `wipe` rule never allowed outside that feature.
- Add the inherent `algorithm()`, `public_key_raw()`, `is_compatible()`, and `compatible_algs()`. The PEM methods need rcgen's `pem` feature; mirror them behind a `pem` feature of rind-rcgen's own if that stays exact, or list them as omitted.
- Remove `check()` and `MissingFeature`.
- Keep `serial_number()` and `key_identifier()`, documented in the README. Without its `crypto` feature, which would compile aws-lc-rs or ring, rcgen can't fill either in, and its built-in provider does both.
