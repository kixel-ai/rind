# [S] Benchmark report refresh, end of m2

## Goal

`BENCHMARKS.md` is regenerated on all four hosts at the end of m2, and every new gap is triaged as the [benchmarks epic](/quest/m1/benchmarks/README.md) set out.

## Plan

Decided with the maintainer on 2026-11-03: rerun the report at the end of each milestone.

- Recurring. This run lives in m3 and requires m2, so it is ready once m2's work is done. The PR that finishes it deletes this file and creates the next run at `/quest/m4/bench-report-refresh.md` (creating m4 if needed). That run's `Required` links `/quest/m3/README.md`, m4's `Required` links it, and this Plan carries forward.
- Run `admin/bench-report`, review the diff for regressions, and triage gaps above about 10% into speed quests or recorded reasons.

## Required

- [m2: later work](/quest/m2/README.md) - the milestone this run closes
- [Benchmark report on real hardware](/quest/m1/benchmarks/README.md) - the script and report this reruns
