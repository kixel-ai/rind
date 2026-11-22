# [M] PR checks stop running for results no one reads

## Goal

Every heavy pull-request workflow either gates the merge or returns its result before the PR usually moves on, and the rest run nightly. A check is then rarely cancelled by a newer push, and never still running after its PR merged. The PR records each workflow's choice with its measured cancelled and post-merge hours before and after.

## Plan

The maintainer's decision, 2026-11-19:

> figure out how to avoid canceling. Like these should be required checks if we're cancelling because of a merge. If we're cancelling because of a review, whatever I guess speed up the checks or move them to nightly.

The orchestrator's reading, ✅ confirmed by the maintainer on 2026-11-19 (rejected: another meaning): a check whose PR merged while it ran never gated anything, so it becomes a gating check, required or run in the merge queue. A check that newer pushes, such as review fixes, keep cancelling is made faster or moved to nightly. Since no PR run was cancelled because its PR merged, the merge case is the checks still running when their PR merged, also confirmed by the maintainer. Measure each workflow's causes before choosing for it.

Hosted job-hours per day of `pull_request` runs, from the Actions REST API: cancelled, then still running when their PR merged (whole runs). "Before" is 2026-11-18; "after cuts" is 2026-11-20 06:03 UTC, when [kixel-ai/rind#911](https://github.com/kixel-ai/rind/pull/911) landed after [kixel-ai/rind#906](https://github.com/kixel-ai/rind/pull/906), [kixel-ai/rind#881](https://github.com/kixel-ai/rind/pull/881), and [kixel-ai/rind#843](https://github.com/kixel-ai/rind/pull/843), to 2026-11-22 05:46 UTC.

| workflow | cancelled before | after cuts | post-merge before | after cuts | choice |
| --- | --- | --- | --- | --- | --- |
| prove | 91.0 | 43.0 | 22.9 | 16.0 | sped up; HOL Light gate open below |
| x86-cpu | 75.7 | 1.1 | 26.3 | 1.2 | gates in the queue since #911 |
| ctgrind | 32.7 | 2.3 | 6.7 | 3.6 | weekly only since #958 |
| build, fuzz, timing, lints, ESP32 | part of 29.0 | part of 1.9 | part of 0.4 | part of 1.1 | scheduled only since #958 |
| PR check, Site, regenerate | part of 29.0 | part of 1.9 | part of 0.4 | part of 1.1 | early copies of queue gates: keep |

[kixel-ai/rind#958](https://github.com/kixel-ai/rind/pull/958) sped `prove` up: 64 of its 79 ready runs re-ran HOL Light aarch64 (58 minutes each), because `asm_function`'s objects kept names that a version bump, a lockfile change, or an unrelated edit changes, and with them every cache key. Its keys now change only with the code, and release-plz's release PR, rewritten on each push to `main`, skips `prove` as it already skipped `x86-cpu` and `ctgrind`: it took 23 of `prove`'s hours a day. `lean` (28 minutes) still runs on every ready run that touches `rind/src`.

The maintainer's decisions, 2026-11-22, on #958:

- ✅ Gate in the merge queue only the HOL Light targets whose cache key `main` hasn't already passed, once `lean` has a cache key of its own (rejected: leave `prove` advisory; gate all of `prove`).
- ✅ "A lot of these non blocking PR checks should be nightly or weekly runs": a PR check that doesn't gate the merge moves off pull requests to its nightly or weekly run, and only gating checks stay on PRs (rejected: keeping advisory checks on PRs). This superseded keeping `ctgrind` advisory on PRs. #958 moved `ctgrind`, `build`, `fuzz`, `timing`, aarch64 clippy (`lints`), and the ESP32-S3 layout check (now weekly) off pull requests, and kept PR check, Site, `regenerate`, `x86-cpu`, and `prove`'s `vg` there as early copies of what the queue gates.

Left:

- Gate the uncached HOL Light targets, in the form the maintainer picks under Waiting, and give `lean` its own result key.
- Settle the rest of `prove`'s pull-request jobs (`lean`, `cosim`, `neon`, `spec-tests`) under the 2026-11-22 rule.
- Re-measure `prove` over the week after that lands, the same way (the script is in #958's Validation).

## Waiting

- Maintainer: how the queue gates the HOL Light targets `main` hasn't passed. Running them in the queue build doesn't fit it: that build is one self-hosted job with a 60-minute limit, under the ruleset's 90-minute response window, and the queue builds one group at a time, while aarch64's proofs alone took 3753 s on a Ryzen 9 9950X and 2799 s on a Core Ultra 7 270K (the queue runner is a Ryzen 9 5900XT). Options: (A) run them in the queue build and raise both limits to about 150 and 180 minutes in dotfiles' `repo-settings`, so each such group holds the queue for an hour or more; (B) have the queue require the result rather than run it: a pull request's passing HOL Light job also saves its key on the PR's own ref, and the queue build computes the group's keys (minutes) and fails any target whose key has no passed result on `main` or on that PR, telling the author to let `prove` finish or merge `main`; (C) gate only x86_64 and armv7 in the queue build and leave aarch64 advisory. Recommendation: B, since it gates exactly the uncached targets for minutes of queue time; a forged key would need a PR edit to `prove.yml`, and the queue build already runs the PR's own code.
- Maintainer: what happens to `prove`'s other pull-request jobs, which gate nothing today. Moving `lean` off pull requests would let an edit under `proofs/` land unchecked until the nightly. Options: (a) gate `lean` and `cosim` by key the same way as HOL Light, run `neon`'s vector diff (seconds) in the queue build, and move `spec-tests` to the nightly; (b) move all four to the nightly; (c) keep them advisory on pull requests as an exception. Recommendation: a, since each check then gates only when its inputs change.

## Related

- [The merge queue runs rind's tests natively on aarch64](/quest/m0/mac-mini-runner.md) - a second queue runner, which a queue module must not slow
