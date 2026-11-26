# Failures show up on the PR that causes them

## Goal

A change that breaks a check that gates the merge and runs on pull requests fails on its own pull request, not first in the merge queue, so a red result names the PR that caused it. The queue's build runs only checks the PR check runs too. A check that gates nothing runs only on its schedule, and its alert reports a failure there, but for the few the PR check also runs, advisory, since their result rests on the PR's own diff (`pr` in `sh/dispatch.sh`).

## Plan

✅ Narrowed to the checks that gate on 2026-11-22, once those that gate nothing left pull requests for their schedules (maintainer, on [kixel-ai/rind#958](https://github.com/kixel-ai/rind/pull/958); rejected: keeping it over every check and main's nightly).

Planned with the maintainer on 2026-11-15 from the `/quest-run` of 2026-11-14 and 2026-11-15, in which kixel-ai/rind#748 and kixel-ai/rind#758 passed every PR check and then failed only in the queue, and main's mutants check broke twice on stale line pins.

- ✅ These quests sit in m0: a check that fails only after review blocks every PR behind it in the queue, and a failing main is m0 work (rejected: m1, m2).
- ✅ The `admin/prove` cache fix joins this epic in m0 although it is a local tool: it cost several proof agents a failed run in one night and is tiny (rejected: m2; dropping it and relying on agents knowing to delete `target/prove`).
- ✅ The armv7 `heap_scratch::detects_a_leak` failure seen once is not planned: one failure, not reproduced (rejected: a flake quest).
- ✅ The portable BINSEC ML-KEM timeout, seen twice, gets a quest that finds its cause (maintainer, 2026-11-17; rejected: not planning it; raising the timeout).
- ✅ The macOS ML-DSA zeroing failure, seen once on main's coverage nightly, gets a quest, since a missed wipe would break AGENTS.md's zeroing requirement (maintainer, 2026-11-18, on kixel-ai/rind#862).
- ✅ The rind-fips fork test hang, seen once on the same nightly, is not planned: it meets the single-failure bar above (maintainer, 2026-11-18; rejected: a quest).
- The macOS ML-DSA zeroing failure was already fixed by [kixel-ai/rind#803](https://github.com/kixel-ai/rind/pull/803), which merged hours after the failing nightly ([kixel-ai/rind#957](https://github.com/kixel-ai/rind/pull/957)).
- [kixel-ai/rind#1028](https://github.com/kixel-ai/rind/pull/1028) fixed the red nightlies of 2026-11-21 no quest owned (`python`'s sdist, `dart-libraries`, and ctgrind's aarch64 release rows; `asan`'s leaks went with [kixel-ai/rind#974](https://github.com/kixel-ai/rind/pull/974)) and runs rind's debug tests on macOS on each pull request that touches rind (`pr-macos.yml`). The merge queue's macOS run is [the Mac mini runner quest](/quest/m0/mac-mini-runner.md)'s.

The epic's own work is done; it finishes with its children, the two nightly time limits that cancel a scheduled run every week.
