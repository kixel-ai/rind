# [S] Mutation testing of wiping Drops on x86_64 and aarch64

## Goal

Every mutant `mutants.yml`'s x86_64 and aarch64 runs find in a `Drop` that wipes a key is killed by a test or recorded in `.cargo/mutants.toml` with why no test can. rind always wipes, so `rind/tests/zeroing.rs` and the adapters' zeroing tests run under mutation with no feature flag.

## Plan

Kept by the maintainer on 2026-11-10, when picking [moq-dev/rind#538](https://github.com/moq-dev/rind/pull/538) to merge: ✅ keep (rejected: drop).

- Run `admin/mutants --workspace` over `rind/src` and the adapters on each architecture, and kill or record what survives. The `Drop` exclusions under "Wipes a key inside a type whose own `Drop` wipes all of it" stay: `zeroing.rs` checks the outer type, which wipes every byte anyway.
