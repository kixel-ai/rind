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
| prove | 91.0 | 43.0 | 22.9 | 16.0 | sped up, gating open below |
| x86-cpu | 75.7 | 1.1 | 26.3 | 1.2 | gates in the queue since #911 |
| ctgrind | 32.7 | 2.3 | 6.7 | 3.6 | gating open below |
| PR check, Site, regenerate, lints, timing, build, fuzz, ESP32 | 29.0 | 1.9 | 0.4 | 1.1 | minutes each: keep |

[kixel-ai/rind#958](https://github.com/kixel-ai/rind/pull/958) sped `prove` up: 64 of its 79 ready runs re-ran HOL Light aarch64 (58 minutes each), because `asm_function`'s objects kept names that a version bump, a lockfile change, or an unrelated edit changes, and with them every cache key. Its keys now change only with the code, and release-plz's release PR, rewritten on each push to `main`, skips `prove` as it already skipped `x86-cpu` and `ctgrind`: it took 23 of `prove`'s hours a day. `lean` (28 minutes) still runs on every ready run that touches `rind/src`, and `prove` returned a median 80 minutes after its push, while the newer push that cancelled a run came a median 6 minutes after it started.

Left:

- Re-measure `prove` and `ctgrind` over the week after #958 lands, the same way (the script is in #958's Validation).
- Give `lean` a result key as the HOL Light checks have, so a pull request skips it unless the Rust under proof, the proofs, or their tools change.
- Gate what still runs after its PR merged, as the maintainer decides under Waiting.

## Waiting

- Maintainer: whether `prove`'s and `ctgrind`'s post-merge runs gate in the merge queue, and at what cost. A queue module (`CHECK_QUEUE` in `sh/dispatch.sh`) would add each check's time to every group whose diff reaches it: ctgrind's x86_64 release row and BINSEC rows took a median 28 minutes on hosted runners, `lean` 28 and HOL Light up to an hour, against a median 2.5-minute queue build. Recommendation: gate `prove` in the queue only for the HOL Light targets whose key `main` lacks, once `lean` has a key too, since that is when a proof can break and is rare after #958; leave `ctgrind` advisory on pull requests, since its 3.6 post-merge hours a day do not pay for 20 or more minutes on most groups, and its weekly run catches what slips through.

## Related

- [The merge queue runs rind's tests natively on aarch64](/quest/m0/mac-mini-runner.md) - a second queue runner, which a queue module must not slow
