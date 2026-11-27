# [S] Bound hung tests with a nextest config

## Goal

A deadlocked test anywhere in rind's CI or local runs ends after a bounded time. The repository has a `.config/nextest.toml` with a hang bound, every workflow and recipe that runs Rust tests goes through `cargo nextest run` (doctests under `timeout <bound> cargo test --doc`), and nextest comes from the dev shell. Once the config exists, kixel-ai/quest's `quest hook` denies plain `cargo test` here and points agents at the recipe.

## Plan

Decided 2026-11-26 (maintainer, /quest-run in kixel-ai/quest, from [kixel-ai/quest#924](https://github.com/kixel-ai/quest/pull/924)): ✅ keep it for rind. On 2026-11-25 two deadlocked tests in moq ran 40 and 49 minutes under plain `cargo test`, which has no hang bound (rejected: leaving rind as it is; dropping the quest). rind's `just check` and `just ci` already run `cargo nextest run` ([kixel-ai/rind#210](https://github.com/kixel-ai/rind/pull/210)), but with no config, so no run has a bound, and `.github/workflows/build.yml`, `asan.yml`, and `x86-cpu.yml` still run plain `cargo test`.

- moq's bound is `slow-timeout = { period = "30s", terminate-after = 2 }`, but it kills healthy tests here: the slowest, such as `slhdsa::acvp_sig_gen`, ran 59 s unoptimized, `SLOW_TESTS=1` runs and the `--release` runs are longer, and the valgrind, QEMU, SDE, and Miri rows are many times slower. Measure each row's slowest passing test and set the period from it, with a profile or per-test override for the slow rows (nextest's `[profile.<name>]` and `[[profile.default.overrides]]`), not a retry or one long default.
- nextest does not run doctests, so its hang bound does not reach `cargo test --doc`. Bound each doctest step with coreutils `timeout`, set to a generous multiple of the slowest healthy doctest run (a failure exits 124), so the Goal holds for doctests too.
- `admin/ctgrind`, `admin/x86-cpu`, `sh/miri.sh`, and `admin/mutants` already run nextest, each with its own wrapper or thread split; keep them working under the config, and say in the PR which profile each uses.
- Where a workflow builds with `cargo test --no-run` for a cross target, nextest's `--archive-file` or `--target` is the equivalent; keep a row that must run under an emulator on its own runner command.
- Update `CONTRIBUTING.md` and `TESTING.md` where they name `cargo test`. Run `just ci` before pushing.
