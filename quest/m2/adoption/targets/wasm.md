# [S] wasm32 compiles on every PR

## Goal

Every PR that changes rind's code compiles the `rind` library for `wasm32-unknown-unknown` (with `getrandom/wasm_js`) and `wasm32-wasip2`, with and without `wipe`, in `just check`'s `cross` module, so a wasm build break fails before merging rather than in a nightly run.
The flake's pinned toolchain gains both targets.
The nightly `wasm` job in `build.yml` that [moq-dev/rind#543](https://github.com/moq-dev/rind/pull/543) added is deleted as redundant, and [PLATFORMS.md](/PLATFORMS.md) says PRs check it.

Non-goals: the adapters on wasm, and speed. Runtime tests are [their own quest](/quest/m2/adoption/targets/wasm-tests.md) (maintainer, 2026-11-09).

## Plan

Decided with the maintainer on 2026-11-09, while landing moq-dev/rind#543 (✅ chosen):

- Gate: ✅ check wasm on every PR in a follow-up quest (rejected: extend #543 to do it; keep wasm nightly-only).
- Scope: ✅ wasm32 is a compile-only target on the portable backend, checked on every PR (rejected: nightly best-effort and unsupported; stay a non-goal and strip #543 to the MD5 fix). An outside user needs wasm, and a compile check is cheap.
- Goal: ✅ the `rind` library only, both targets, with and without `wipe` (rejected: also compile rind-rustls; keep #543's nightly job too).
- Placement: ✅ this epic (rejected: m0, m3).

[moq-dev/rind#412](https://github.com/moq-dev/rind/pull/412) broke the wasm build with MD5's inline-asm optimizer barrier, and only a user noticed. #543 fixed it with `core::hint::black_box` on the wasm target family. Start once #543 has landed.

Library builds only: the differential tests link native aws-lc, so `cargo test` cannot cross-compile to wasm.
