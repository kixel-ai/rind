# [S] rind-ring builds under no_std + alloc as ring 0.17 does

## Goal

`rind-ring` builds and passes tests with `--no-default-features --features alloc` (and without `std` on `no_std` targets), matching upstream `ring` 0.17's `#![no_std]` + `alloc` support, and CI checks it.

## Plan

Found by the 2026-11-21 repository audit (`/quest-plan`). Decided with the maintainer: ✅ fix `rind-ring` in m0 as a published adapter divergence from upstream `ring` 0.17 (rejected: defer to m2; skip).

- Culprit PR: [kixel-ai/rind#151](https://github.com/kixel-ai/rind/pull/151) (`feat(ring): add rind-ring, ring 0.17's API on rind`), which omitted `#![no_std]` in `rind-ring/src/lib.rs` and imported `std::sync::Arc` unconditionally in `rind-ring/src/aead.rs:8`.
- Core `rind` is already `#![no_std]` + `alloc`, and `rind-ring/src/error.rs` already gates `std::error::Error` on `feature = "std"`.
- Add `#![no_std]` (with `extern crate alloc;` and optional `extern crate std;` when `feature = "std"`) to `rind-ring/src/lib.rs`.
- Replace `std::sync::Arc` in `rind-ring/src/aead.rs`: check whether `UnboundKey` / `LessSafeKey` can hold `rind::aead::Key` directly (matching `ring` and `rind-aws-lc-rs`, eliminating an extra heap allocation per key) or must use `alloc::sync::Arc` for shared ownership (`Clone`/bound keys). Keep `admin/adapter-api` green.
- Add a `no_std` + `alloc` compile check for `rind-ring` to CI (`sh/dispatch.sh` / `build.yml`) so it cannot regress.
