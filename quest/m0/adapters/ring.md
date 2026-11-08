# [S] rind-ring is ring 0.17's API

## Goal

rind-ring's public API and Cargo features are ring 0.17's, apart from the omissions its README lists.

## Plan

Found by diffing rustdoc JSON against ring 0.17.14 on 2026-11-08:

- Remove the `cpu` module (`check` and `MissingFeature`), which ring lacks.
- Remove `Eq` from `error::Unspecified`, which ring derives only `PartialEq` on.
- Restore ring's `B: Debug` bound on `Debug` for `agreement::UnparsedPublicKey<B>` and `signature::UnparsedPublicKey<B>`.
- Accept ring's Cargo features as no-ops, as rind-aws-lc-rs accepts aws-lc-rs's: `less-safe-getrandom-custom-or-rdrand`, `less-safe-getrandom-espidf`, `slow_tests`, `test_logging`, `unstable-testing-arm-no-hw`, `unstable-testing-arm-no-neon`, and `wasm32_unknown_unknown_js`. Today a manifest that names one fails to resolve. `wasm32_unknown_unknown_js` stays a no-op because rind doesn't build for wasm32 at all, so no browser build loses entropy.
- Keep the hand-written `PartialEq` on `hmac::Algorithm` and `pbkdf2::Algorithm`; nobody can observe the difference.
