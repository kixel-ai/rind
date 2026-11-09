# [S] rind-dimpl, rind-str0m, rind-jsonwebtoken, and rind-object-store match their upstream providers

## Goal

rind-dimpl, rind-str0m, and rind-jsonwebtoken offer exactly what their upstream's own providers offer, and rind-object-store's `default_provider()` can't fail.

## Plan

- rind-dimpl: `default_provider()` returns `CryptoProvider`, as `dimpl::crypto::aws_lc_rs::default_provider()` does. Accept PEM-wrapped PKCS#8 keys, which both of dimpl's providers accept (`aws_lc_rs/sign.rs`), and change the test that asserts the refusal (`tests/provider.rs`).
- rind-str0m: `default_provider()` drops `MissingFeature`. Add `dimpl_crypto_provider()`, which str0m-aws-lc-rs 0.7 exposes for callers who build their own `dimpl::Config`, returning rind-dimpl's provider. Keep returning an error where upstream lets dimpl panic on an empty certificate or a bad key, as AGENTS.md requires; list it in the README.
- rind-jsonwebtoken: replace `default_provider()` with `pub static DEFAULT_PROVIDER: CryptoProvider`, as `jsonwebtoken::crypto::aws_lc` has. It is a function only so it could check the CPU.
- rind-object-store: `default_provider()` returns `Arc<dyn CryptoProvider>` without `MissingFeature`. object_store's own providers are `pub(crate)`, so there is no other shape to copy.
