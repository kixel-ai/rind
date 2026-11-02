# [XS] Nightly passes on main

## Goal

Every scheduled workflow on `main` passes, so a red nightly means a new break.

## Plan

Decided with the maintainer on 2026-11-01, from the merge-gate and CI audit. Settled; don't ask again. The chosen option is marked ✅.

- Milestone: m0 ✅ / m1 / m2.
- Cranelift: delete the job ✅ / keep it red until Cranelift supports
  `asm!` sym operands.

Every known cause is fixed on `main` as of `347d1f4`. What remains is
confirming it: these `workflow_dispatch` runs on `31ed599` were still running
on 2026-11-02. Once each is green (or a later scheduled run on `main` is),
delete this quest; a failure is a new break to fix at the source.

- [asan](https://github.com/moq-dev/rind/actions/runs/41386166878)
- [bench](https://github.com/moq-dev/rind/actions/runs/41386169247)
- [build](https://github.com/moq-dev/rind/actions/runs/41386171898)
- [coverage](https://github.com/moq-dev/rind/actions/runs/41386174282)
- [ctgrind](https://github.com/moq-dev/rind/actions/runs/41386176568)
- [fuzz](https://github.com/moq-dev/rind/actions/runs/41386178932)
- [quality lints](https://github.com/moq-dev/rind/actions/runs/41386181082)
- [x86-cpu](https://github.com/moq-dev/rind/actions/runs/41386183524)
