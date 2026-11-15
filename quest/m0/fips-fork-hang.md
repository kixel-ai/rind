# [M] rind-fips's fork self-test child never hangs

## Goal

`rind-fips/tests/fork.rs`'s `a_child_forked_mid_self_test_tests_and_exits`
passes under the load `just ci` puts on a host: no forked child deadlocks.
`just ci` runs it for every Rust change, so its hang fails unrelated PRs and
merge-queue builds.

## Plan

Reproduced at `main` 9feb1465 on Linux/x86_64: the test passes alone, but
with 16 copies of its binary running at once (`LD_LIBRARY_PATH` set to the
build's `rind-fips-*/out/lib`), 2 of 128 runs fail with "the forked child
hung". A normal run finishes all 32 forks in 0.11s, so a deadlock is likely,
but a child descheduled past the test's 10s deadline would fail the same way.
Only the self-test variant has been seen to fail.

First capture a hung child's state (attach `gdb` before the test kills it,
or raise its deadline while reproducing) to tell a deadlock from slowness.
If it waits on a lock, fix that at the cause; if it is only slow, say why the
deadline is too short for a loaded host rather than raising it blindly.

Candidate locks: one taken outside the module's `pthread_atfork` handlers
(`rind-fips/module/src/lib.rs`), such as one inside a self-test or the
zeroing allocator, held by the parent's worker thread at the fork; or the
order in which `fork_prepare` takes the self-test and DRBG locks against a
self-test that draws. The test stays as the reproduction.
