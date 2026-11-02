# [XS] cargo-llvm-cov builds with its tests again

## Goal

`devShells.coverage` stops overriding `cargo-llvm-cov` with `doCheck = false` once nixpkgs' pinned rustc no longer crashes its test programs on exit, so it comes from the binary cache again. Check by building `cargo-llvm-cov` from the flake's nixpkgs without the override after each nixpkgs bump. This quest only waits; delete it once the override is gone.

## Plan

Planned with the maintainer on 2026-11-02 from [moq-dev/rind#236](https://github.com/moq-dev/rind/pull/236).
