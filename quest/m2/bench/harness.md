# [L] Benches move from Criterion to swole

## Goal

Every bench target in `rind-bench` is written as [swole](https://github.com/kixel-ai/swole) `#[bench]` functions, which swole counts and the native rows, the weekly gate, and the benchmark report time through the harness. Criterion, `codspeed-criterion-compat`, and the `__bench_codspeed` feature leave the workspace, so nothing in rind names CodSpeed.

Non-goals: what each row measures, the weekly cadence, the report's hosts, and the libraries rind is compared against.

## Plan

Decided 2026-11-25 (maintainer, `/quest-plan` in kixel-ai/rust2, [kixel-ai/rust2#1031](https://github.com/kixel-ai/rust2/pull/1031)):

- ✅ No CodSpeed service, app, or code in moq-dev or kixel-ai (rejected: the service and app only; drop the work). [kixel-ai/rind#1013](https://github.com/kixel-ai/rind/pull/1013) ends the service; this ends the crate.
- ✅ Rewrite the benches to `#[bench]` (rejected: a Criterion-API count layer in the harness, deleted later by this rewrite; wait for rust2's m2 harness epic).
- ✅ The harness's wall-clock timing ships first, so each bench is written once and Criterion leaves with CodSpeed's crate (rejected: rewrite now and stop the native rows' timing until it ships; keep a Criterion copy of each bench for timing). Paired timing, which shipped in [kixel-ai/rust2#1033](https://github.com/kixel-ai/rust2/pull/1033), is required to time one build's rows against each other, as the native rows compare rind with aws-lc-rs and ring.

Decided 2026-11-25 (maintainer, `/quest-plan` in kixel-ai/rust2, [kixel-ai/rust2#1041](https://github.com/kixel-ai/rust2/pull/1041)): ✅ rust2-bench and its harness move to [kixel-ai/swole](https://github.com/kixel-ai/swole) as `swole` before this rewrite, so the benches are written against `swole` once instead of renamed afterward. The move is [kixel-ai/rust2#1046](https://github.com/kixel-ai/rust2/pull/1046); the harness is `swole = { git = "https://github.com/kixel-ai/swole" }` in `[dev-dependencies]` until its first crates.io release, and the runner is the `swole` flake's default package.

Recommendations for the implementer:

- One PR: Criterion can leave only once every target has moved, and `admin/bench-report` would otherwise read two formats.
- `admin/bench-report`, the weekly `gate`, and `BENCHMARKS.md`'s refresh read Criterion's IDs and `target/criterion/**/benchmark.json`. Move them to the harness's output in the same PR, and keep each row's operation and library recoverable from its name.
- Keep each benchmark's name where the harness can, so Kixel Quest's instruction series and the gate's `--previous` comparison continue. Name in the PR the ones that change; a gate across the rename compares nothing for them for one run.
- The Graviola rows that #1013 leaves out of the count build, since Valgrind hides ADX, and `rsa_gen`'s `NOISY_BENCHMARKS` gate need a home in the harness's terms, without a cargo feature to switch harnesses, as does the count build's skip of rustls's threaded rows, whose setup's threads would move the heap under the rows after it.
- Update `TESTING.md`, `CONTRIBUTING.md`, and every comment that names CodSpeed.

Public API: none.
