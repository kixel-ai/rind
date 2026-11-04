# [M] The README sells rind and links the details

## Goal

The README is a short marketing page for a visitor deciding whether to try
rind: why to use it (pure Rust with no C toolchain, verified where it counts,
and as fast as aws-lc-rs and ring), a headline of about six common operations
plus build time and binary size, how to use it (rind-rustls, the direct API,
and the other adapters), the copy-paste migration prompt, and an invitation
to AI reviews and contributions through the quest skills. Everything a
visitor doesn't need to decide (the Algorithms table and its sources, CPU
requirements and tiers, the technical details, and the architecture) moves to
linked docs, and `BENCHMARKS.md` is the only place the numbers live.

## Plan

See the [epic](/quest/m1/benchmarks/README.md) for the benchmark decisions.
Decided with the maintainer on 2026-11-04, in a planning interview. Settled;
don't ask again (✅ is the chosen option):

- Scope: this quest owns the whole README restructure, not only its headline
  ✅ / a separate restructure quest.
- Timing: wait for the report, so the headline is its generated SVG from the
  start ✅ / restructure now on the nightly CI ratios and swap the SVG in
  later.
- Migration: the README carries the [migration prompt](/quest/m1/migration-prompt.md)
  as is.
- Contributing: the README says AI reviews and contributions are welcome:
  run `/quest-plan` to propose a change, or `/quest-start` to take a backlog
  quest, and links `CONTRIBUTING.md` for the rest (maintainer, 2026-11-04).

Guidance:

- Lead with the pitch and the headline; usage follows within a screen. The
  credits to Graviola, aws-lc-rs, and the other sources stay, short.
- The headline is a small generated SVG from the same results, regenerated
  by `admin/bench-report`.
- The moved sections keep their content: the Algorithms table keeps its
  sources and ✓ columns and drops its ratios, which move to the report's
  CPU-tier section. Pick the files and names; fix every link into the moved
  sections, including from quests, `MIGRATING.md`, and crate READMEs.
- Update the speed epic's scoreboard decision to name the report.

## Required

- [BENCHMARKS.md is generated](/quest/m1/benchmarks/report.md) - the report and results the headline comes from
- [A prompt migrates a repo to rind](/quest/m1/migration-prompt.md) - the copy-paste prompt the README carries
