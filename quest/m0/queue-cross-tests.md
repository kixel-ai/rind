# [S] The merge queue compiles rind's tests for aarch64 and armv7

## Goal

A PR whose merge with main breaks rind's test code on aarch64 or armv7 fails in the merge queue instead of landing. On 2026-11-10, [moq-dev/rind#583](https://github.com/moq-dev/rind/pull/583) (`zero_bytes` became `unsafe fn`) and [moq-dev/rind#564](https://github.com/moq-dev/rind/pull/564) (ABI tests calling it through `call!`) each passed the queue, but together they stopped rind's lib tests compiling on both targets until [moq-dev/rind#593](https://github.com/moq-dev/rind/pull/593) fixes it.

## Plan

Planned with the maintainer on 2026-11-10 from #593's suggested follow-up: ✅ m0, since it guards main against the breakage m0 exists to fix (rejected: m2).

- Why it slipped: the queue runs `just ci` on the self-hosted x86_64 host (`queue-build.yml`), and `check:cross` in `sh/dispatch.sh` clippy-checks aarch64 and armv7 with `--lib` only, so `#[cfg(test)]` code on those targets is never compiled before landing.
- ✅ Try first: widen `check:cross` to cover rind's test code for `aarch64-unknown-linux-gnu` and `armv7-unknown-linux-gnueabihf` on the existing host, with no new runner. The likely obstacle is dev-dependencies that build C (aws-lc-rs) needing a cross C toolchain; measure what it adds to the queue's time. The `cross` selector (`sh/dispatch.sh`) matches only `rind/src/` and build inputs, so widen it to `rind/tests/` too, or `--all-targets` never runs for a test-only change.
- ✅ Fall back: if the dev-dependencies won't cross-check cheaply, add an `ubuntu-24.04-arm` job to the queue running `cargo clippy -p rind --all-targets -- --deny warnings` (about a minute on a runner `lints.yml` already uses), as #593 suggested. armv7 then stays covered only by the nightlies and [#575](https://github.com/moq-dev/rind/pull/575)'s PR-triggered runs; say so in CONTRIBUTING.md.
- The maintainer offered to buy hardware if needed, such as an ARM machine for a native self-hosted queue runner. If neither route works without it, recommend the hardware under `## Waiting` with what it would run and why.
- Rejected: dropping it and relying on the nightlies and PR-triggered runs.
