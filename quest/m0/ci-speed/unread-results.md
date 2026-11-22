# [M] PR checks stop running for results no one reads

## Goal

Pull requests run only fast hosted checks (`pr-check.yml` with scoped `rs`, sub-second repo lints, and path-scoped `site`, skipping drafts and cancelling on close/merge/draft), while heavy suites (`x86-cpu`, `ctgrind`, `prove`, `regenerate`, plus `cross`, `msrv`, `wasm`, `adapters`, and `vartime`) batch asynchronously on their nightly/weekly schedules (and on demand via `workflow_dispatch` and `just release-check`). Hosted runners spend little on cancelled or post-merge work, and the PR records each workflow's change with measured cancelled and post-merge hours before and after.

## Plan

Supersedes the earlier 2026-11-19 recommendation to gate heavy workflows in the merge queue. Maintainer decision, 2026-11-21:

> I'm fine if we catch issues asynchronously instead of wasting CI running every test on every PR too. Nightly/weekly is a batching process basically.

- ✅ Full PR batching for heavy suites: PRs run only fast hosted `pr-check.yml` (scoped `rs` + sub-second lints + path-scoped `site`), while `cross`, `msrv`, `wasm`, `adapters`, `vartime`, `x86-cpu`, `ctgrind`, `prove`, and `regenerate` batch nightly/weekly plus `workflow_dispatch` and `just release-check` (maintainer, 2026-11-21; rejected: keeping `cross`/`msrv`/`wasm`/`adapters`/`vartime` in `pr-check.yml`; gating heavy suites in the merge queue).
- Remove `pull_request` triggers from `x86-cpu.yml`, `ctgrind.yml`, `prove.yml`, and `regenerate.yml` (and any slow PR-only jobs in `build.yml` / `lints.yml` that nightly already covers), keeping their `schedule` and `workflow_dispatch` triggers intact so `just release-check` and manual dispatches still run them.
- In `pr-check.yml`, mirror `moq-dev/moq`'s `.github/workflows/check.yml`: skip draft PRs (`github.event.pull_request.draft == false`), trigger on `types: [opened, synchronize, reopened, edited, ready_for_review, converted_to_draft, closed]` with `if: github.event.action != 'closed'`, and key concurrency on `pr-check-${{ github.event.pull_request.number }}` so closing, merging, or returning a PR to draft cancels any in-flight run (today `github.ref` changes on merge and misses post-merge runs). Limit `pr-check.yml` to the fast PR module set (`rs` + sub-second lints + path-scoped `site`), leaving `cross`, `msrv`, `wasm`, `adapters`, and `vartime` to nightly `check.yml` (`just ci --all`) and `just release-check`.
- Baseline measured on 2026-11-18 from the Actions REST API (hosted job-hours): 43 post-merge hours (`prove` 21, `x86-cpu` 18, `ctgrind` 4) and 197 cancelled hours across 142 runs (`x86-cpu` 71, `prove` 66, `ctgrind` 29, `Site` 8, `PR check` 7, `regenerate` 6, `lints` 4; 72 of the 198 cancelled hours were on drafts before [kixel-ai/rind#906](https://github.com/kixel-ai/rind/pull/906)).
- Update [CONTRIBUTING.md](/CONTRIBUTING.md) and [TESTING.md](/TESTING.md) where they describe which workflows run on pull requests, and make sure `sh/alert.sh check` and `sh/release-check.sh --check` still pass.

## Related

- [Thin the self-hosted merge queue to host rs and fast lints](/quest/m0/ci-speed/thin-merge-queue.md) - removes `sde`, `vg`, `regenerate`, and the heavy `just ci` modules from `queue-build.yml`
- [Scope check:site to site inputs and drop its duplicate PR run](/quest/m0/ci-speed/site-scope.md) - removes the duplicate `site.yml` / `pr-check.yml` site build on non-site PRs
