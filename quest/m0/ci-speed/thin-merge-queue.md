# [M] Thin the self-hosted merge queue to host rs and fast lints

## Goal

`queue-build.yml` on the self-hosted `rind-queue` runner runs only host `rs` checks and sub-second repository lints, dropping `sde`, `vg`, `regenerate`, `cross`, `wasm`, `msrv`, `adapters`, `vartime`, and `site` from the merge queue so a merge group completes in ~1–2 minutes (once warm under `mbx`) instead of 15 minutes and 5.5 CPU-hours. Nightly/weekly workflows (`check.yml`, `x86-cpu.yml`, `prove.yml`, `regenerate.yml`) and `just release-check` continue to run the full unscoped suite asynchronously.

## Plan

Measured across the 15 merge-queue runs ending 2026-11-22: median 15.0 min wall (max 17.7 min) and 5.5 CPU-hours per run. `check sde` (added in [kixel-ai/rind#911](https://github.com/kixel-ai/rind/pull/911)) consumed 72.7% of all runner CPU (14.1m median wall), followed by `check cross` (11.4m), `check rs` (11.1m), `check vg` (5.9m, added in [kixel-ai/rind#881](https://github.com/kixel-ai/rind/pull/881)), `check wasm` (4.7m), `check adapters` (4.6m), `check msrv` (4.0m), `check vartime` (2.8m), `check regenerate` (2.2m, `#881`), and `check site` (1.0m on every run). Hosted runner waits have since dropped back to 2–5s.

- ✅ Keep `rind-queue` strictly minimal (`mbx`-warmed host `rs` + sub-second repo lints) and move `sde`, `vg`, `regenerate`, `cross`, `wasm`, `msrv`, `adapters`, `vartime`, and `site` off the merge queue into nightly/weekly batching (maintainer, 2026-11-21; rejected: retiring `rind-queue` completely onto hosted runners; removing only `sde`/`vg`/`regenerate`).
- ✅ Rare two-PR merge interactions in the offloaded checks are caught asynchronously by nightly/weekly runs and fixed in `m0` rather than gated in `merge_group` (maintainer, 2026-11-21; rejected: parallel hosted `merge_group` jobs; gating `cross`/`msrv`/`wasm`/`adapters`/`vartime` in `merge_group`).
- Remove `CHECK_QUEUE=1` (and the `vg`, `regenerate`, `sde` queue modules in `sh/dispatch.sh`) from `queue-build.yml`, and select only the fast host modules (`rs`, `py`, `dart`, `openssl`, `patch`, `deny`, `versions`, `license`, `testing`, `audit`, `compat`, `bench`, `quest`, `gh`, `shell`, `nix`, plus `structure`/`mutants`/`fixtures` only if kept under a few seconds—measure and drop slow ones to nightly `check.yml`). Keep `just ci --all` (`check.yml`) running every module nightly.
- Upload `target/cargo-timings/cargo-timing-*.html` from `queue-build.yml` (like `moq-dev/moq`'s `.github/workflows/queue.yml`) so future compile regressions show up without manual profiling.
- Note that `queue-build.yml` runs main's copy, so edits to `queue-build.yml` take effect on the merge group after this PR lands, and `queue-build.yml` must use no local actions (`sh/dispatch.sh`'s `check:gh` enforces this).
- Update [CONTRIBUTING.md](/CONTRIBUTING.md) where it documents what the merge queue runs.

## Related

- [The merge queue builds through mbx, warm across groups](/quest/m0/queue-warm-target.md) - eliminates the cold-build penalty on `rind-queue`
- [The merge queue runs rind's tests natively on aarch64](/quest/m0/mac-mini-runner.md) - benefits directly from the thinner queue gate
- [PR checks stop running for results no one reads](/quest/m0/ci-speed/unread-results.md) - moves the heavy PR workflows to nightly/weekly batching too
