# [M] Scope local tests to changed primitives and skip adapter fan-out on low/ edits

## Goal

When a diff changes only `rind/src/low/` (or private internals that cannot change `rind`'s public API), local `just check` tests only `-p rind` instead of all 19 dependent workspace crates, and maps changed `rind/src/{low,mid,high}/` files to algorithm-level `cargo nextest -E` filters—falling back to the full `-p rind` test suite (or full dependent crates) whenever shared files such as `lib.rs`, `error.rs`, `cpu.rs`, `Cargo.toml`, or public signatures change.

## Plan

Today editing a single backend file such as `rind/src/low/x86_64/chacha20_poly1305.rs` causes `sh/select.sh` to select all 19 workspace crates and run all 1,929 tests (including `rind-aws-lc-rs`, `rind-fips`, `rind-rustls`, `slhdsa`, `argon2`, `voprf`, and `rsa8192`).

- ✅ Skip dependent adapter fan-out locally on `rind/src/low/` edits and filter `rind`'s tests by changed algorithm via `cargo nextest -E`, with conservative fallback to full `-p rind` / dependent crates on shared or public-API files (maintainer, 2026-11-21).
- Extend `sh/select.sh` (or add a companion `sh/test-filter.sh` called by `sh/dispatch.sh` for `check` and optionally fast PR runs) with:
  - A `--no-dependents-on-low` (or local `check`) mode: when every changed file in `rind/` is under `rind/src/low/` (and outside shared CPU/entry files like `low/mod.rs`, `low/entry.rs`, `low/mcdt.rs`, `low/*/cpu.rs`), drop only the fan-out from `rind` to the `rind-<consumer>` adapters that depend on it. A crate the diff changes directly, such as an adapter edited alongside `low/`, stays selected beside `-p rind`. `just ci` / nightly `check.yml` still tests every dependent crate.
  - A path-to-primitive-family map from `rind/src/{low,mid,high}/` (e.g., `chacha20*`/`poly1305*` -> `chacha|poly1305|aead`, `aes*`/`gcm*`/`ghash*` -> `aes|gcm|ghash|aead`, `sha2*`/`sha1*`/`sha3*`/`blake2*`/`md5*` -> corresponding hash/hmac/hkdf/pbkdf2 tests, `p256*`/`p384*`/`p521*`/`ed25519*`/`x25519*`/`rsa*`/`mlkem*`/`mldsa*`/`slhdsa*`/`argon2*`/`hpke*`/`oprf*`/`frost*`/`spake2*`/`vrf*`) emitting a `nextest` `-E` filter expression together with Cargo target selectors, since `-E` only picks which built tests run and nextest otherwise builds every test target of `rind`. The selectors name every test target except the crosschecks binaries of untouched families: the library's unit tests (`--lib`), `--test wycheproof`, the other shared integration targets (`aws_lc`, `cctv`, `zeroing`, and the rest under `rind/tests/`), and the touched families' crosschecks binaries once [split-crosschecks](/quest/m1/split-crosschecks.md) lands (until then, the one `crosschecks` binary). Emit neither filter nor selectors (build and run all tests) whenever any changed file is unmapped or shared.
- Add a self-test (run by `just check`, like `admin/mutants --expand-diff-self-test`, when the script, the map, `rind/tests/wycheproof.rs`, or any crosschecks file (`rind/tests/crosschecks.rs`, or every per-family file split from it) changes, or a file under `rind/src/{low,mid,high}/` is added, deleted, or renamed, but not when one is only edited, since an edit changes no mapping and `cargo nextest list` would rebuild every family's test binary that the scoped run skips) verifying that every file under `rind/src/{low,mid,high}/` either falls back cleanly or maps to a filter that `cargo nextest list` shows selecting that family's required tests: its Wycheproof vectors in `rind/tests/wycheproof.rs` and its differential tests in the crosschecks files, listed per family beside the map. A nonempty selection is not enough: a `p256` name filter matches its crosschecks but not `test_verify_ecdsa`, which holds every curve's ECDSA vectors, so a vector test shared across families belongs to each of them. It also fails on any test in `wycheproof.rs` or any crosschecks file that no family lists, so a vector or differential test added without updating the lists is caught rather than skipped. Newly added primitives then never silently skip tests.

## Required

- [Local just check is a fast test-only loop with single-pass clippy](/quest/m0/ci-speed/local-fast-check.md) - splits local `just check` from `just ci` in `sh/dispatch.sh`

## Related

- [Split rind/tests/crosschecks.rs into per-family test binaries](/quest/m1/split-crosschecks.md) - lets algorithm-scoped runs recompile and link only one family's test binary
