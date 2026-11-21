# [S] The prove workflow's lean job stops compiling Mathlib's C on every run

## Goal

The `lean` job in `.github/workflows/prove.yml` stays well inside its 60-minute timeout on a slow hosted runner, because a pull request no longer compiles Mathlib's and Aeneas's modules to C objects on every run.

## Plan

Decided 2026-11-21 (orchestrator, for the maintainer, in [kixel-ai/rind#949](https://github.com/kixel-ai/rind/pull/949)'s merge pick): ✅ keep this quest (rejected: accept occasional timeouts and rerun by hand).

- Found on [kixel-ai/rind#949](https://github.com/kixel-ai/rind/pull/949), whose `lean` job was cancelled at its 60-minute timeout ([run 44906833080](https://github.com/kixel-ai/rind/actions/runs/44906833080)). The diff touched no Lean.
- Caused by [kixel-ai/rind#919](https://github.com/kixel-ai/rind/pull/919) (found by check), which the fixing PR lists under `## Caused by`: it added the `spec-server` executable (`proofs/lakefile.toml`), which `admin/prove lean`'s spec tests build. Linking it compiles every imported Mathlib and Aeneas module to a `.c.o`: 1789 objects, which Mathlib's cache (`lake exe cache get`) doesn't ship. Pull-request runs of the job went from about 24 minutes to 41 to 48. On #949's runner, about 1.6× slower than usual, it reached module 4516 of 4775 when the timeout cancelled it.
- Options, best first: narrow `spec-server`'s imports to the spec modules and what they need, so it links little or no Mathlib; or keep its compiled objects between runs in a cache keyed on `lake-manifest.json` and the toolchain, with a pull request reading only what main wrote, as the HOL Light caches do (the security note at the top of `prove.yml`). Raising the timeout is not a fix.
- Measure the job's time before and after on a few pull-request runs, and record them in the PR.
