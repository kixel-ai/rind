# [S] Add optional rand_core and zeroize trait implementations on rind

## Goal

Downstream Rust crates that accept generic `rand_core` RNGs or `zeroize::Zeroize` / `ZeroizeOnDrop` bounds can pass `rind`'s RNG and secret key types directly by enabling optional `rand_core` and `zeroize` Cargo features on `rind`, with zero new required dependencies when those features are off.

## Plan

Planned with the maintainer on 2026-11-21 (`/quest-plan`): ✅ add optional `rand_core` and `zeroize` trait impls on `rind` (rejected: skip).

- **Optional `rand_core` feature**:
  - Add an optional `rand_core` dependency (aligned with the `rand_core` major used by `rind-rustcrypto` / current RustCrypto, documented in `rind/Cargo.toml` and `MIGRATE.md`) gated behind a non-default `rand_core` feature.
  - Expose a zero-sized RNG handle under `rind::rand` (wrapping `rind::rand::fill`) implementing `TryRngCore` / `TryCryptoRng` (and `RngCore`/`CryptoRng` if appropriate for the chosen `rand_core` version).
- **Optional `zeroize` feature**:
  - Add an optional `zeroize` dependency (`default-features = false` so `no_std` stays intact; `rind-aws-lc-rs`, `rind-rcgen`, and `rind-openssl` already depend on `zeroize`) gated behind a non-default `zeroize` feature.
  - Implement `zeroize::ZeroizeOnDrop` (and `Zeroize` where appropriate) on `rind`'s secret key types that already wipe themselves in `Drop`, so generic libraries requiring `T: ZeroizeOnDrop` accept `rind` keys without wrapper newtypes.
- Verify `--no-default-features`, default features, `--features rand_core`, `--features zeroize`, and `no_std` builds all compile and pass tests cleanly, and ensure `rind`'s default dependency tree stays unchanged (zero extra default crates).

## Related

- [RustCrypto's traits](/quest/m2/rustcrypto/traits.md)
- [Gate coverage regressions, test feature powersets, and execute wasm32 tests](/quest/m2/confidence/coverage-powerset-wasm-gates.md)
