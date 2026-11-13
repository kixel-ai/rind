# [XS] Dependabot proposes Cargo dependency updates

## Goal

`.github/dependabot.yml` also covers the `cargo` ecosystem: one grouped weekly PR of minor and patch updates across the workspace, with the same 7-day cooldown the GitHub Actions updates use.

## Plan

Planned with the maintainer on 2026-11-13: ✅ Dependabot bumps crates (rejected: the [upstream run](/quest/m2/upstream-updates.md) bumps them by hand), ✅ ignore semver-major updates (rejected: propose majors too). Each `rind-<consumer>` version matches the upstream major it adapts, so a major bump there is an adapter release the upstream run plans, not a routine update.

- Cargo treats a `0.x` minor bump as breaking, and Dependabot groups it with minors, so the grouped PR's CI is what catches those.
