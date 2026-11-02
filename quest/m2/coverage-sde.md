# [S] Coverage runs the pinned SDE

## Goal

`coverage.yml` runs its `sde -dmr` pass through `devShells.sde`, the SDE build pinned by hash in the flake, instead of fetching the latest `ctz/intel-sde`.

## Plan

Planned with the maintainer on 2026-11-02 from [moq-dev/rind#225](https://github.com/moq-dev/rind/pull/225).

- Coverage's Ubuntu-built test binaries link the system OpenSSL, which the SDE sandbox hides, so build the coverage run inside a Nix shell with llvm-tools and cargo-llvm-cov as well.
