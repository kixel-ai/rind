# [S] Release notes are corrected on main, so a regenerated release PR needs no hand commits

## Goal

A correction to a release's changelog lands on `main` in a reviewed PR, in a form release-plz keeps when it regenerates the release PR. A merge to `main` then produces a release PR that is already correct, with only release-plz's own commit, and nobody re-pushes corrections or reruns the release check because of them.

## Plan

Found on 2026-11-25: each of that day's five replaced release PRs ([kixel-ai/rind#1016](https://github.com/kixel-ai/rind/pull/1016), [#1017](https://github.com/kixel-ai/rind/pull/1017), [#1018](https://github.com/kixel-ai/rind/pull/1018), [#1021](https://github.com/kixel-ai/rind/pull/1021), [#1030](https://github.com/kixel-ai/rind/pull/1030)) carried hand-pushed `docs(changelog): correct the 0.4.0 release notes` commits on top of release-plz's `chore: release`. Each merge to `main` that touched a crate, a Cargo file, the flake, or the release config made release-plz open a fresh PR without them, so they were pushed again and the hours-long release check restarted.

- Decided 2026-11-25 (maintainer, /quest-plan): ✅ fix where corrections live, m2 beside the 0.4 release (rejected: holding merges to `main` during the final release check; accepting the churn).
- Find out first why release-plz replaces the PR rather than updating it in place, and whether foreign commits on its branch are what triggers that. Then choose how corrections survive, for example rewriting commit messages through release-plz's changelog config (`commit_preprocessors` or `[changelog]` body templates), or editing `CHANGELOG.md`'s unreleased section on `main` if release-plz keeps those edits. Move the corrections currently on the open release PR to `main` that way.
- Write the rule in `CONTRIBUTING.md`'s Releases section: correct release notes on `main`, never on the release PR's branch.

## Related

- [rind 0.4 ships once](/quest/m2/api/release-0.4.md) - the release whose PR kept being replaced
