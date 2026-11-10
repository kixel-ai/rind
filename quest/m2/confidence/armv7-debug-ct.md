# [S] armv7 debug ctgrind runs weekly

## Goal

A scheduled workflow runs armv7 ctgrind on debug builds every week and alerts when it fails, so armv7 stays constant-time in debug builds without anyone remembering to check.

## Plan

Decided with the maintainer on 2026-11-09: ✅ a weekly CI job (rejected: a manual run before each minor release; the 2026-11-02 choice of a manual run at the end of each milestone, which m2's outside waits may never reach). This replaces the recurring quest that ran it by hand.

- The nightly `ctgrind.yml` runs armv7 with `--release` (`.github/workflows/ctgrind.yml:214`), so no scheduled job checks debug builds. The manual run dropped `--release` from the armv7 jobs and added `--no-fail-fast` on a throwaway branch, as [moq-dev/rind#208](https://github.com/moq-dev/rind/pull/208) did.
- It last passed on 2026-11-02 (run 41349429240), before the portable backend and the `wipe` feature landed, so expect the first run to find something. rind's secret arithmetic wraps, and dependencies' debug checks are turned off in the workspace dev profile.
- Weekly, as `timing.yml` is, and reported through `alert.yml` like the nightlies. Fix what it reports here when it's small; otherwise it is a follow-up for `/quest-plan`.

## Related

- [A PR that would redden a nightly learns before it merges](/quest/m2/confidence/nightlies-on-prs.md) - decides which scheduled checks also run on pull requests
