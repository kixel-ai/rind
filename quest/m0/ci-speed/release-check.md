# [M] Releases publish only after the full suite passes locally

## Goal

Before a release-plz PR merges, one `just` recipe runs the heavy suites the weekly CI runs, scoped to the crates the release PR versions plus everything depending on them, on a local Linux host at the release PR's head, and the release PR records the result. Nothing publishes that the full suite has not passed.

## Plan

Decided with the maintainer on 2026-11-12:

- ✅ Run it locally, before the release PR merges (rejected: a CI check on the release PR, which would re-run every time release-plz updates the PR; both, through one recipe).
- ✅ Scope: the crates whose version the release PR changes, plus their dependents, using `sh/select.sh`'s selection (rejected: always every crate). A release of `rind` runs everything, since every crate depends on it.
- The recipe covers what a Linux host can run: `just ci --all` for the selection, the SDE CPU tiers, `just armv7`, `just portable`, `just wasm`, `just miri`, ctgrind, fuzz corpus replay, and `SLOW_TESTS=1`. macOS, Windows, and Apple-silicon rows stay with the weekly CI; the release PR links the last green weekly run for them.
- Run it through `quest gate` like any heavy local command.
- Say in CONTRIBUTING.md's Releases section that a release PR merges only after this recipe passes at its head, and where its result goes. `/quest-merge` picking a release PR should run it, so the step needs no person.
- Recommendation: the release PR records the head SHA the recipe passed on, so a later release-plz update visibly needs a re-run.

## Related

- [The heavy suites run weekly and finish](/quest/m0/ci-speed/weekly.md) - the same suites, on every crate, on hosted runners
- [rind 0.4 ships once](/quest/m2/api/release-0.4.md) - the next release this gates
