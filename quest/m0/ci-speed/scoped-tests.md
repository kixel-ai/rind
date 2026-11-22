# [M] Scope local tests to changed primitives and skip adapter fan-out on low/ edits

## Goal

When a diff changes only `rind/src/low/` (or private internals that cannot change `rind`'s public API), local `just check` tests only `-p rind` instead of all 19 dependent workspace crates, and maps changed `rind/src/{low,mid,high}/` files to algorithm-level `cargo nextest -E` filters—falling back to the full `-p rind` test suite (or full dependent crates) whenever shared files such as `lib.rs`, `error.rs`, `cpu.rs`, `Cargo.toml`, or public signatures change.

## Plan

Today editing a single backend file such as `rind/src/low/x86_64/chacha20_poly1305.rs` causes `sh/select.sh` to select all 19 workspace crates and run all 1,929 tests (including `rind-aws-lc-rs`, `rind-fips`, `rind-rustls`, `slhdsa`, `argon2`, `voprf`, and `rsa8192`).

- ✅ Skip dependent adapter fan-out locally on `rind/src/low/` edits and filter `rind`'s tests by changed algorithm via `cargo nextest -E`, with conservative fallback to full `-p rind` / dependent crates on shared or public-API files (maintainer, 2026-11-21).
- Extend `sh/select.sh` (or add a companion `sh/test-filter.sh` called by `sh/dispatch.sh` for `check` and optionally fast PR runs) with:
  - A `--no-dependents-on-low` (or local `check`) mode: when every changed file in `rind/` is under `rind/src/low/` (and outside shared CPU/entry files like `low/mod.rs`, `low/entry.rs`, `low/mcdt.rs`, `low/*/cpu.rs`), select `-p rind` without fanning out to the `rind-<consumer>` adapters; `just ci` / nightly `check.yml` still tests every dependent crate.
  - A path-to-primitive-family map from `rind/src/{low,mid,high}/` (e.g., `chacha20*`/`poly1305*` -> `chacha|poly1305|aead`, `aes*`/`gcm*`/`ghash*` -> `aes|gcm|ghash|aead`, `sha2*`/`sha1*`/`sha3*`/`blake2*`/`md5*` -> corresponding hash/hmac/hkdf/pbkdf2 tests, `p256*`/`p384*`/`p521*`/`ed25519*`/`x25519*`/`rsa*`/`mlkem*`/`mldsa*`/`slhdsa*`/`argon2*`/`hpke*`/`oprf*`/`frost*`/`spake2*`/`vrf*`) emitting a `nextest` `-E` filter expression, and emitting no filter (running all tests) whenever any changed file is unmapped or shared.
- Add a self-test (run by `just check` when the script changes, like `admin/mutants --expand-diff-self-test`) verifying that every file under `rind/src/{low,mid,high}/` maps to a non-empty set of tests in `cargo nextest list` or falls back cleanly, so newly added primitives never silently skip tests.

## Required

- [Local just check is a fast test-only loop with single-pass clippy](/quest/m0/ci-speed/local-fast-check.md) - splits local `just check` from `just ci` in `sh/dispatch.sh`

## Related

- [Split rind/tests/crosschecks.rs into per-family test binaries](/quest/m1/split-crosschecks.md) - lets algorithm-scoped runs compile and link only one family's oracle crates
