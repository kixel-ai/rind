# [XS] Nightly passes on main

## Goal

Every scheduled workflow on `main` passes, so a red nightly means a new break.

## Plan

Decided with the maintainer on 2026-11-01, from the merge-gate and CI audit. Settled; don't ask again. The chosen option is marked ✅.

- Milestone: m0 ✅ / m1 / m2.
- Cranelift: delete the job ✅ / keep it red until Cranelift supports
  `asm!` sym operands.

Every known cause is fixed on `main` as of `347d1f4`, except two quality
lints jobs: aarch64 clippy (generic ChaCha20-Poly1305 `open` dead in aarch64
tests) and the unstable rustfmt, both fixed by this quest's PR. The
`workflow_dispatch` runs on `31ed599` passed for asan, build, coverage,
ctgrind, fuzz, and x86-cpu. What remains is confirming these; once each is
green (or a later scheduled run on `main` is), delete this quest; a failure is
a new break to fix at the source.

- [bench](https://github.com/moq-dev/rind/actions/runs/41386169247) on `main` at `31ed599`
- [quality lints](https://github.com/moq-dev/rind/actions/runs/41388651120) on this quest's branch at `994a3f7`
