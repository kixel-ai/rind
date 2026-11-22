# [M] PR checks stop running for results no one reads

## Goal

Every heavy pull-request workflow either gates the merge or returns its result before the PR usually moves on, and the rest run nightly. A check is then rarely cancelled by a newer push, and never still running after its PR merged. The PR records each workflow's choice with its measured cancelled and post-merge hours before and after.

## Plan

The maintainer's decision, 2026-11-19:

> figure out how to avoid canceling. Like these should be required checks if we're cancelling because of a merge. If we're cancelling because of a review, whatever I guess speed up the checks or move them to nightly.

The orchestrator's reading, ✅ confirmed by the maintainer on 2026-11-19 (rejected: another meaning): a check whose PR merged while it ran never gated anything, so it becomes a gating check, required or run in the merge queue. A check that newer pushes, such as review fixes, keep cancelling is made faster or moved to nightly. Since no PR run was cancelled because its PR merged, the merge case is the checks still running when their PR merged, also confirmed by the maintainer. Measure each workflow's causes before choosing for it.

Hosted job-hours per day of `pull_request` runs, from the Actions REST API: cancelled, then still running when their PR merged (whole runs). "Before" is 2026-11-18; "after cuts" is 2026-11-20 06:03 UTC, when [kixel-ai/rind#911](https://github.com/kixel-ai/rind/pull/911) landed after [kixel-ai/rind#906](https://github.com/kixel-ai/rind/pull/906), [kixel-ai/rind#881](https://github.com/kixel-ai/rind/pull/881), and [kixel-ai/rind#843](https://github.com/kixel-ai/rind/pull/843), to 2026-11-22 05:46 UTC.

| workflow | cancelled before | after cuts | post-merge before | after cuts |
| --- | --- | --- | --- | --- |
| prove | 91.0 | 43.0 | 22.9 | 16.0 |
| x86-cpu | 75.7 | 1.1 | 26.3 | 1.2 |
| ctgrind | 32.7 | 2.3 | 6.7 | 3.6 |
| PR check, Site, regenerate, lints, timing, build, fuzz, ESP32 | 29.0 | 1.9 | 0.4 | 1.1 |

[kixel-ai/rind#958](https://github.com/kixel-ai/rind/pull/958) made `prove`'s HOL Light keys change only with the code: 64 of its 79 ready runs had re-run HOL Light aarch64 (58 minutes each), because `asm_function`'s objects kept names that a version bump, a lockfile change, or an unrelated edit changes.

The maintainer's decisions, 2026-11-22, on #958:

- ✅ Gate in the merge queue only the HOL Light targets whose cache key `main` hasn't already passed, once `lean` has a cache key of its own (rejected: leave `prove` advisory; gate all of `prove`).
- ✅ "A lot of these non blocking PR checks should be nightly or weekly runs": a PR check that doesn't gate the merge moves off pull requests to a nightly or weekly run, and only gating checks stay on PRs (rejected: keeping advisory checks on PRs). This supersedes keeping `ctgrind` advisory on PRs, and the 2026-11-18 decisions in the [epic](/quest/m0/ci-speed/README.md) on what pull requests run.

What #958 did with each pull-request check:

| check | now | why that cadence |
| --- | --- | --- |
| `ctgrind` (x86_64 release row, BINSEC) | weekly | already weekly in full |
| `build` (armv7, portable, Dart, openmls) | nightly | already nightly |
| `fuzz` (target builds) | weekly | the weekly fuzz builds them first |
| `timing` (smoke build) | dropped | the weekly Marvin run builds the same crate |
| `lints` (aarch64 clippy) | nightly | the queue already clippies `rind` for aarch64 |
| ESP32-S3 SHA-256 layout | weekly (new) | one 30-minute job on code that rarely moves |
| `x86-cpu` (three SDE models, ACVP on Diamond Rapids) | weekly | the queue runs every path set |
| `regenerate` | nightly | the queue runs it on its inputs |
| `prove` `keys`, HOL Light, `cosim` | nightly and on a push to main | the push checks the keys main lacks, so a failure names its commit |
| `prove` `vg` | nightly | the queue runs x86_64's |
| `prove` `lean`, `neon`, `spec-tests` | nightly | none gates |
| Site | dropped | PR check and the queue run the same `sh/site.sh` |
| PR check | kept, waiting below | |

Left:

- Gate the uncached HOL Light targets, as the maintainer picks under Waiting, and give `lean` its own result key.
- Re-measure over the week after that lands, the same way (the script is in #958's Validation).

## Waiting

- Maintainer: how the queue gates the HOL Light targets `main` hasn't passed. Running them in the queue build doesn't fit it: that build is one self-hosted job with a 60-minute limit, under the ruleset's 90-minute response window, and the queue builds one group at a time, while aarch64's proofs alone took 3753 s on a Ryzen 9 9950X and 2799 s on a Core Ultra 7 270K (the queue runner is a Ryzen 9 5900XT). Options: (A) run them in the queue build and raise both limits to about 150 and 180 minutes in dotfiles' `repo-settings`, so each such group holds the queue for an hour or more; (B) have the queue require the result rather than run it: a pull request runs only the HOL Light targets whose key `main` lacks, saving each passed key on the PR's own ref, and the queue build computes the group's keys (minutes) and fails any target whose key has no passed result on `main` or on that PR; (C) gate only x86_64 and armv7 in the queue build and leave aarch64 to the push to main. Recommendation: B, since it gates exactly the uncached targets for minutes of queue time; a forged key would need a PR edit to `prove.yml`, and the queue build already runs the PR's own code.
- Maintainer: whether `lean` gates the same way once it has a key. Off pull requests, an edit under `proofs/` lands unchecked until the nightly. Recommendation: yes, by the mechanism picked above, since it then runs only when its inputs change.
- Maintainer: whether PR check becomes a required check. It runs on every pull request, unfiltered, so it can be one, and it is the only early copy of the queue's `just ci`; [the catch-on-pr epic](/quest/m0/catch-on-pr/README.md) exists so a failure shows on its PR, not first in the queue. Options: require it in dotfiles' `repo-settings`; drop it, leaving failures to the queue and to agents' local `just ci`. Recommendation: require it, since a group the queue ejects costs a slot in a one-group-at-a-time queue.
- Maintainer: [the catch-on-pr epic](/quest/m0/catch-on-pr/README.md)'s Goal, that a change breaking a check fails on its own pull request and main's nightly runs green, no longer holds for the checks now only scheduled. Recommendation: narrow it to the checks that gate, and leave a scheduled failure to its alert.

## Related

- [The merge queue runs rind's tests natively on aarch64](/quest/m0/mac-mini-runner.md) - a second queue runner, which a queue module must not slow
