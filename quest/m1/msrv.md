# [XS] rind builds on its declared rust-version

## Goal

The workspace builds and tests on Rust 1.90, the `rust-version` it declares, and CI fails when it stops doing so.

## Plan

Found on 2026-11-05 by [moq-dev/rind#353](https://github.com/moq-dev/rind/pull/353): the 1.90 build fails on main at `_mm_prefetch` in `rind/src/low/x86_64/cpu.rs`, so a dependent pinned to 1.90 cannot build rind. Fix it at the source, or raise `rust-version` if the fix would cost speed, and check whether CI already runs an MSRV job that missed this; if not, add one to the `just ci` gate only if it stays fast, otherwise to a nightly workflow.
