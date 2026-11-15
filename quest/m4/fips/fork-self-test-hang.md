# [S] A child forked mid self-test never hangs

## Goal

`rind-fips/tests/fork.rs`'s `a_child_forked_mid_self_test_tests_and_exits`
passes every run: a child forked while another thread runs the module's
self-tests completes its own self-test and exits.

## Plan

It hangs about one run in eight on `main` (2 of 12 runs of
`cargo test -p rind-fips --test fork` at 3aab7616, on an x86_64 Core
Ultra 7 270K, panicking "the forked child hung" after 10 s), so a lock or
once-state the self-tests hold survives the fork in the child. Reproduce
it in a loop, find which state the child inherits held (the self-test
module's, or one rind's tests or `fips_rng`'s fork handlers miss), and
release or reset it in the module's fork handlers, as the DRBG's are.
