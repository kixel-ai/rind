# [S] CodSpeed accepts rind's benchmark upload again

## Goal

The `codspeed` job in `.github/workflows/bench.yml` uploads every `rind-bench` benchmark and the "CodSpeed Performance Analysis" check passes, with no benchmark dropped to fit.

## Plan

Decided with the maintainer on 2026-11-11: ✅ split the upload (rejected: drop benchmarks to fit).

The dispatched bench [run 43016732906](https://github.com/moq-dev/rind/actions/runs/43016732906) on [moq-dev/rind#612](https://github.com/moq-dev/rind/pull/612) uploaded about 1,200 benchmarks from 23 suites in one job; CodSpeed's check failed with "Too many benchmarks in a single upload" while the GitHub job passed.
CodSpeed's [sharding docs](https://codspeed.io/docs/features/sharded-benchmarks) recommend under 1,000 benchmarks per shard and merge the shards of one workflow into one report.

- A matrix of CodSpeed jobs, each building and running a subset of the bench targets with `cargo codspeed build --bench`.
- Derive the subsets from `cargo metadata`, so a new bench target joins a shard without editing the workflow.
- Validate by dispatching `bench.yml` on the branch and confirming the CodSpeed check passes.

No single PR caused it: the suite grew past the limit.
