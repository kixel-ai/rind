# [XS] The weekly bench pins rust2-bench to its commit on rust2's main

## Goal

`flake.nix` pins the `rust2` input, which supplies `rust2-bench` and the Valgrind the weekly bench's `instructions` job counts under, to kixel-ai/rust2's squash commit of its Valgrind runner on `main`, not the head of that PR's branch.

## Plan

[kixel-ai/rind#1013](https://github.com/kixel-ai/rind/pull/1013) moved the weekly instruction counts from CodSpeed to `rust2-bench`, pinned to `af1a76643700cf0314b7a2e02ef159c563712c2e`, the head of [kixel-ai/rust2#995](https://github.com/kixel-ai/rust2/pull/995) before it merged. Once it merges, set `rust2.url` to its squash commit and run `nix flake lock`. If the squash changed the runner, rerun `nix develop .#bench --command rust2-bench run -- -p rind-bench --features __bench_codspeed --bench sha2` and check the fingerprint still reads `x86_64-3059cd1d9e65`; a new one restarts every Kixel Quest series, so say so in the PR.

Public API: none.

## Waiting

- kixel-ai/rust2: [kixel-ai/rust2#995](https://github.com/kixel-ai/rust2/pull/995) merges; check with `gh pr view 995 -R kixel-ai/rust2 --json state,mergeCommit`.
