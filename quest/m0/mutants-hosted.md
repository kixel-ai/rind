# [M] Whole mutation campaigns run on GitHub-hosted runners

## Goal

A whole `admin/mutants` campaign, over the workspace, a crate, or a backend, runs only on GitHub-hosted runners, as a `workflow_dispatch` of `mutants.yml` whose matrix splits each campaign into `--shard k/n` jobs. On the agent hosts, `admin/mutants` runs only over a diff (`--in-diff`) or named files, and refuses anything wider with an error naming the dispatch command. rind is public, so the hosted minutes are free.

## Plan

Decided with the maintainer on 2026-11-12, from read-only audits of the maintainer's agent hosts: ✅ whole campaigns on hosted runners, sharded in a dispatch matrix; local runs limited to `--in-diff` or single files (rejected: sccache shared across cargo-mutants' build directories, which keeps the CPU on the hosts).

- The cost: in a week, agents ran 48-53 `admin/mutants` campaigns through `quest gate` across the hosts, 277-340 CPU-hours, 14-18% of all gated CPU. Each ran up to 6.5 h at about 15 cores, peaking at 12 GB; an `admin/mutants --portable` campaign took 28.9 CPU-h, and an `--in-diff --iterate -j 6` run 20.7 CPU-h. Each mutant's tests run once per CPU-feature row, four on x86_64. Crashing mutants left about 3,400 segfault coredumps in two days.
- Shards: [moq-dev/rind#657](https://github.com/moq-dev/rind/pull/657) sharded pull requests' runs by mutant count (40 a shard) and [moq-dev/rind#668](https://github.com/moq-dev/rind/pull/668) removed that with the pull request trigger; restore the counting job for dispatches. Size shards by measured time, not 40 mutants: on 2026-11-12 the whole x86_64 campaign listed 11,348 mutants and the portable one 7,223, more than GitHub's 256-job matrix holds at 40 each. The portable campaign's 28.9 CPU-h is about 7 h of a 4-core hosted runner, so a few shards each fit the 300-minute limit.
- Cap the matrix's `max-parallel` so a dispatched campaign leaves room for pull requests' checks under the org's 60 concurrent hosted jobs.
- A dispatch picks its scope: the whole workspace by default, or one crate, such as an adapter, so [the adapters' survivors quest](/quest/m2/confidence/mutants-adapters.md) can check a crate there. The nightly run keeps mutating the last day's diff. `survivors`, and the `avx512` job while it exists, read every shard's output.
- Agents learn the rule from `admin/mutants` itself, which refuses an unscoped run outside GitHub Actions (recommended over an `AGENTS.md` rule, which every task would load though few run mutants). Say it in `admin/mutants`' header and `mutants.yml`'s, and fix CONTRIBUTING.md's line saying pull requests still get a mutation run.
- A crashing mutant counts as caught either way, so `admin/mutants --run` can set the core size limit to zero for its tests; check that the host's coredump handler then stores nothing.
- [moq-dev/rind#690](https://github.com/moq-dev/rind/pull/690) plans a quest to run `mutants.yml` weekly on fewer campaigns. Whichever lands second shards the campaigns the workflow then has.

## Related

- [Every mutants exclusion matches a mutant](/quest/m2/confidence/mutants-pins.md) - also changes `admin/mutants`, in [moq-dev/rind#699](https://github.com/moq-dev/rind/pull/699)
- [Apple-silicon nightlies run on the Mac mini](/quest/m2/confidence/apple-nightlies.md) - may move the macOS DIT campaign to a self-hosted runner, which stays allowed since `admin/mutants` limits it to named files
