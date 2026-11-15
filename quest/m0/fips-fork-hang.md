# [M] rind-fips's fork self-test child never hangs

## Goal

`rind-fips/tests/fork.rs`'s `a_child_forked_mid_self_test_tests_and_exits`
passes under any load: no forked child deadlocks. `just ci` runs it for every
Rust change, so its hang fails unrelated PRs and merge-queue builds.

## Plan

Reproduced at `main` 9feb1465 on Linux/x86_64: the test passes alone, but
with 16 copies of its binary running at once (`LD_LIBRARY_PATH` set to the
build's `rind-fips-*/out/lib`), 2 of 128 runs fail with "the forked child
hung". A normal run finishes all 32 forks in 0.11s, so a child that has not
exited after the test's 10s deadline is deadlocked, not slow. Only the
self-test variant has been seen to fail.

Find the lock the child waits on (attach `gdb` to a hung child before the
test kills it, or raise its deadline while reproducing), and fix it at the
cause. Candidates: a lock taken outside the module's `pthread_atfork`
handlers (`rind-fips/module/src/lib.rs`), such as one inside a self-test or
the zeroing allocator, held by the parent's worker thread at the fork; or the
order in which `fork_prepare` takes the self-test and DRBG locks against a
self-test that draws. Keep the test as it is; it is the reproduction.
