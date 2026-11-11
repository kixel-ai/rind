# [S] Mutate a large pull request within the job limit

## Goal

mutants.yml's pull request run finishes on any pull request's diff, so a missed mutant fails it rather than a 300-minute cancellation hiding it. ML-DSA's diff ([moq-dev/rind#610](https://github.com/moq-dev/rind/pull/610)) had 1275 mutants on x86_64 and 1495 on aarch64: at 70 to 240 seconds a mutant on a hosted runner, about 30 to 80 hours, so both runs were cancelled with most mutants untested.

## Plan

- Shard the pull request run with cargo-mutants' `--shard k/n`, choosing `n` from `--list`'s count so each shard fits well inside the limit, and combine the shards' `mutants.out` with `admin/mutants --survivors` as the architectures' already are.
- The nightly run, which mutates one day's changes, keeps its single job.
