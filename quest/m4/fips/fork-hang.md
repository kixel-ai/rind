# [M] A child forked mid-self-test never hangs

## Goal

`rind-fips/tests/fork.rs`'s `a_child_forked_mid_self_test_tests_and_exits` passes every run: a child forked while another thread runs the self-tests always tests and exits, with the cause of the hang it sometimes hits fixed in the module, not the test.

## Plan

- Seen while iterating [kixel-ai/rind#771](https://github.com/kixel-ai/rind/pull/771), which leaves the module's locks and fork handlers as `main` has them: `just ci` failed with "the forked child hung", and `cargo test -p rind-fips --test fork` failed 1 run in 5 on a loaded host. Running the test binary directly, alone or 8 at once, never hung in 160 runs, so load or the cargo-run environment matters.
- Catch a hung child and read its stacks (make the test leave it running, then `gdb -p`), to find which lock it waits on. The module's fork handlers hold only the self-test lock and the DRBGs; a lock outside them, such as one in std or libtest held by another thread at `fork`, would explain a hang the handlers cannot prevent.
