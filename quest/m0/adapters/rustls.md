# [M] rind-rustls is rustls's aws-lc-rs provider

## Goal

rind-rustls's public API is `rustls::crypto::aws_lc_rs`'s, item for item, apart from what rind cannot back yet (ML-KEM-1024, ML-DSA, and `hpke`).

## Plan

- Match upstream exactly ✅ (rejected: keep the lean-provider items as a documented superset). Remove what [moq-dev/rind#332](https://github.com/moq-dev/rind/pull/332) added to build a provider that links fewer algorithms: `empty_provider()`, the `sign` module's `KeyProvider` statics (`ANY_SUPPORTED_TYPE`, `RSA`, `ECDSA_P256`, `ECDSA_P384`, `ECDSA_P521`, `ED25519`), `sign::AnyOf`, and the public `verify` module and `SUPPORTED_SIG_ALGS` static. Upstream's provider has no `verify` module (its verification algorithms live in `rustls_webpki::aws_lc_rs`) and keeps its `SUPPORTED_SIG_ALGS` private. Binaries go back to linking every algorithm, as upstream's do; #332 measured 2.89 MB against ring's 1.94 MB. Update MIGRATING.md's trim row.
- Add upstream's missing items: `sign::any_supported_type`, `any_ecdsa_type`, `any_eddsa_type`, and `RsaSigningKey`, with upstream's signatures. Upstream marks `RsaSigningKey` `#[doc(hidden)]`; mirror that.
- Remove `kx_group::SECP521R1`, which neither of rustls's providers offers.
- `default_provider()` and `Ticketer::new()` return what upstream's do, without `MissingFeature`.
- `aws_lc_rs_parity` in `rind-rustls/src/lib.rs` already checks the algorithm lists against upstream's; extend it, or a test beside it, to cover the item names, doc-hidden items included, so a new divergence fails CI.
