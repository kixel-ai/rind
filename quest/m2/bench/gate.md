# [S] The nightly bench fails on a gap nobody decided

## Goal

The nightly `bench` workflow fails, and so alerts through `alert.yml`, when a benchmark on any CPU tier measures rind more than 1.10× the fastest baseline's time and `benchmarks/gaps.toml` holds no quest or reason for it. Every nightly benchmark ID is either ranked or listed as unranked with its reason, so a new benchmark cannot go unwatched.

## Plan

Planned from the 2026-11-09 speed audit. Decided with the maintainer that day:

- Scope: correctness tooling, speed measurement, and portable speed ✅ (rejected: no portable speed work, correctness only).
- Milestone: measurement quests join m2, in this epic ✅.
- The 1.10× threshold (`SLOWER`, `admin/bench-report:808`) stays. It decides what needs a recorded decision, and is separate from AGENTS.md's rule for picking a source.

What the audit found:

- The `native` job only prints each ratio to the step summary (`.github/workflows/bench.yml:265`), and no ratio fails it. The gate (`load_gaps`, `admin/bench-report:995`) runs only when someone runs `admin/bench-report nightly` and `render` by hand, at a milestone's refresh. CodSpeed's job times one x86_64 path in simulation.
- `benchmarks/data/tiers.json` is [run 41932862737](https://github.com/moq-dev/rind/actions/runs/41932862737) of 2026-11-04. It predates the `portable` and `no IFMA` rows, so nothing has gated them.
- `TIER_ROWS` (`admin/bench-report:784`) matched 197 of the 303 benchmark IDs in the x86_64 row of [run 42526977036](https://github.com/moq-dev/rind/actions/runs/42526977036) (2026-11-08). The other 106 fall in 36 groups: AES-192 GCM and CTR, AES-CBC, AES-KW and KWP, RSA-OAEP, RSA key generation, SHA-3, MD5, and JWT.
- Gaps that run showed outside the gate: AES-KW and KWP wrap at 1.09 to 1.20× on x86_64, AES-CBC encrypt at 1.08 to 1.18× on aarch64, armv7 RSA key generation at 1.31× (2048 bits, the same in both runs) and 1.58× (3072), and the whole portable row, which [64-bit limbs](/quest/m3/cold-speed/portable-limbs.md) and [portable AES-GCM](/quest/m3/cold-speed/portable-aes-gcm.md) list.

Guidance:

- Run the gate in a job after `native`, over that run's `bench-*` artifacts, through a `bench-report` subcommand that shares `gaps_of` with `render`, so the nightly and the report cannot disagree. Its failure names each undecided cell with its ratio and baseline.
- `benchmarks/gaps.toml` needs a decision for every gap the current nightly shows before the gate lands, or its first night fails. A gap names its quest once one exists.
- Each ID matches a `TIER_ROWS` pattern or an explicit unranked list that gives the reason, and the tool refuses an ID in neither. Unranked today for a stated reason: RSA key generation, for its variance (`admin/bench-report:783`). Unranked by design: JWT `load`, the part of a `token` spent on the key (`rind-bench/benches/jsonwebtoken.rs:3`); rank `token`.
- A row with no baseline, such as a rind-only row from [the new tiers](/quest/m2/bench/tiers.md), has no ratio. Skip it in the gate and say so in the summary.

Open, with a recommendation:

- Noise. GitHub draws a different CPU each night, and two `gaps.toml` entries already record one-run noise. Recommend failing only on a cell that is over the threshold in two consecutive scheduled runs, read from the previous run's artifacts, rather than raising the threshold.
- A `workflow_dispatch` run on an experiment branch should not alert. Recommend gating only scheduled runs and runs of `main`.

## Related

- [Nightly rows for the tiers nothing times](/quest/m2/bench/tiers.md) - adds the rows this gate then watches
- [Benchmark report refresh, before rind 0.4](/quest/m2/bench/report-refresh.md) - keeps the report once this owns regressions
