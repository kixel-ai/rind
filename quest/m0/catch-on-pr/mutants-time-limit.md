# [S] The weekly mutants campaign finishes inside its jobs' limit

## Goal

`mutants.yml`'s weekly run finishes every shard inside its 300-minute job limit, so the run passes or fails on what it finds and its alert names a surviving mutant, not a time limit.

## Plan

Found by [kixel-ai/rind#1028](https://github.com/kixel-ai/rind/pull/1028): the last four scheduled runs were cancelled ([run 44957680650](https://github.com/kixel-ai/rind/actions/runs/44957680650) of 2026-11-21, and those of 2026-11-11, 11-12, and 11-13). On 2026-11-21, 26 of its 59 shard jobs hit the limit after 5 hours, all of them x86_64.

- `SHARD_SECONDS` (10800) splits each campaign by a mean seconds-per-mutant measured in November 2026 (x86_64 68, aarch64 24). Measure the real per-mutant time from the cancelled shards' logs or a dispatched x86_64 campaign over last week's diff, find what grew (a slow test reached by more mutants, such as SLH-DSA's or Argon2's, or the mean itself), and fix that cause: a faster test profile for mutants or a corrected estimate, not a longer limit.
- Record the measured time and what changed in the workflow's comment.
