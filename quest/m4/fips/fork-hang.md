# [S] A child forked mid self-test never hangs

## Goal

`rind-fips/tests/fork.rs`'s `a_child_forked_mid_self_test_tests_and_exits`
passes every run: a child forked while another thread runs the module's
self-tests always finishes its own self-test and exits.

## Plan

Found by [kixel-ai/rind#641](https://github.com/kixel-ai/rind/pull/641) on
2026-11-15: on x86_64 Linux, about one run in 35 hangs past the test's
10 s deadline (the test otherwise takes 0.13 s), on main (`381ba596`) as on
that PR's head. Reproduce with
`cargo nextest run -p rind-fips --test fork --stress-count 300 a_child_forked_mid_self_test`.

- Find which lock the hung child waits on (attach `gdb` to the child before
  the parent's `SIGKILL`, or dump its stacks from the test), and fix the
  module's `pthread_atfork` handlers (`rind-fips/module/src/lib.rs`) or
  `selftest.rs`'s lock at the root, not the test's deadline.
- If the hang is in the test harness or `std` rather than the module, such
  as a lock a forked child of a multithreaded process inherits held, fix the
  test so the child only does what is async-signal-safe beyond the module
  call it checks.
