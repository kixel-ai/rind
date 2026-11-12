# [S] Mutation survivors in Drops no wipe test reaches

## Goal

Every `Drop` mutant `admin/mutants --workspace` misses on x86_64 and aarch64 is killed by a test or recorded in `.cargo/mutants.toml` with why no test can, so a pull request touching one passes `mutants.yml`.

## Plan

Found by the campaign for [moq-dev/rind#655](https://github.com/moq-dev/rind/pull/655) on x86_64, with `rind/wipe` on:

- `rind/src/low/entry.rs`: `replace <impl Drop for Entry>::drop with ()`.
- `rind/src/low/guard_pages.rs`: `replace <impl Drop for Guarded>::drop with ()`, a test helper's `munmap`.
- `rind-aws-lc-rs/src/buffer.rs` (`Buffer`, both mutants), `rind-aws-lc-rs/src/wipe.rs` (`Wiped<T>`), and `rind-rcgen/src/lib.rs` (`Wiped`): each wipes only under its crate's own `wipe`, which the campaign leaves off, so their `tests/zeroing.rs` never runs. cargo-mutants builds one package at a time, so `--features rind-aws-lc-rs/wipe,rind-rcgen/wipe` fails as a feature the other package lacks, and `--all-features` turns on ctgrind, bench, and test-only features.

## Waiting

- Maintainer: how the adapters' zeroing tests run under mutation. Options: (a) a third matrix entry per adapter, `-p rind-aws-lc-rs --features wipe` and `-p rind-rcgen --features wipe`, with the `--workspace` runs excluding those `Drop`s; (b) record them in `exclude_re` as covered by the adapters' `just ci` zeroing tests. Recommend (a): it keeps the gate testing what it claims, at two small jobs.
