# [M] Test coverage audit

## Goal

A table in CONTRIBUTING.md (or a file it links to) lists every primitive rind exports against every backend and CPU tier it runs on. Each cell names the test vectors, differential fuzz target, differential test, and constant-time check that cover it. Every empty cell is either filled in this quest's PR, planned as a quest under the [epic](/quest/m3/confidence/README.md), or recorded with its reason.

## Plan

- Build the table from the code (`rind/tests/`, `fuzz/fuzzer/`, the `ct_*` tests, `admin/x86-cpu`'s SDE scans) rather than from docs, and add a check that fails when a new primitive lands without a row.
- Check that each fuzz target reaches every dispatch tier, for example under SDE or with CPU features masked, not just the host's fastest path.
- Check the nightly fuzz run's per-target time and corpus, and whether CI replays the saved corpus as a regression test.
