# [XS] The bench report has a quiet Arrow Lake run and kixtop's build cost

## Goal

`BENCHMARKS.md`'s `desktop` (Arrow Lake) column comes from a fresh run that `admin/bench-report` doesn't flag as noisy, and `kixtop` (Apple M4) has a build-cost table, before the launch post. Every gap either opens a speed quest or gets a recorded reason in `benchmarks/gaps.toml`.

## Plan

What remains of adding `kixtop` to the report, which [moq-dev/rind#435](https://github.com/moq-dev/rind/pull/435) did. The [end-of-m2 refresh](/quest/m3/bench-report-refresh.md)'s settled choices (libraries, hosts, the ✓ rule, the triage rule) apply here unchanged.

- Re-collect `desktop` with `admin/bench-report collect --host desktop`. The `rustls-bulk/aes128-gcm` and `xchacha20poly1305/1350B` gaps there are recorded as noise awaiting a recheck, so drop or triage them.
- Re-collect `kixtop` too if its run gets a build cost, since `collect` measures both together; rerun noisy rows rather than recording noise.
- On 2026-11-07, `collect` refused `desktop` three times: 16.8, 4.7, and 5.3 of its 24 CPUs were busy, against a limit of 2.4, from other sessions' builds outside any gate. One attempt waited an hour for its host hold: the `quest` those sessions run predates [moq-dev/quest#526](https://github.com/moq-dev/quest/pull/526), so their gated commands were admitted past it. `kixtop` measured quietly on the second of two runs, but both runs' build costs were refused, at 11.6 and 6.6 of its 10 CPUs busy.

- Decided with the maintainer on 2026-11-07: run it at about 5 am Pacific, when no session is building on `desktop` or `kixtop`; a scheduled agent starts it then. Those hosts' `quest` still predates [moq-dev/quest#526](https://github.com/moq-dev/quest/pull/526), so the host hold can't keep other sessions out; if `collect` still refuses a host as busy, record the load and stop, rather than waiting on the hold.
- If [rind's rows with the DIT guard held](/quest/m1/bench-dit-held.md) have landed, the `kixtop` re-collect carries them.
