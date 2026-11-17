# [S] rind-fips's fork test finishes on every run

## Goal

`rind-fips/tests/fork.rs`'s `a_child_forked_mid_self_test_tests_and_exits` passes on every run, including the nightly coverage build. The cause of its hang is found and fixed, not hidden by a longer deadline or a retry.

## Plan

Found by [the uncovered-functions quest](https://github.com/kixel-ai/rind/pull/862) while reading main's red nightlies.

- What failed: the nightly `coverage` workflow's Linux job, [run 43770267161](https://github.com/kixel-ai/rind/actions/runs/43770267161) (2026-11-15), `the forked child hung` after the test's 10-second deadline. The other nightlies passed.
- Candidates: a lock the fork copies held by a thread the child lacks, which the module's fork handlers exist to release (a lock they miss, or LLVM's profile runtime, which writes its counters at exit in the instrumented build); or a child that is only slow, running the self-tests in an unoptimized, instrumented build, which a wall-clock deadline cannot tell from a hang.
- Reproduce it first, for example by looping the test under `cargo llvm-cov` on Linux and taking the hung child's stack before the kill, then fix the cause. Replace the wall-clock deadline if the child turns out only slow.

## Related

- [Failures show up on the PR that causes them](/quest/m0/catch-on-pr/README.md) - this failure turns main's nightly red for changes that didn't cause it.
