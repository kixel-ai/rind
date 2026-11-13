# [XS] Dependabot proposes Cargo dependency updates

## Goal

`.github/dependabot.yml` also covers the `cargo` ecosystem: one grouped weekly PR of the workspace's routine crate updates, with the same 7-day cooldown the GitHub Actions updates use.

## Plan

Planned with the maintainer on 2026-11-13: ✅ Dependabot bumps crates (rejected: the [upstream run](/quest/m2/upstream-updates.md) bumps them by hand), ✅ in m2 (rejected: m0, which its README keeps for urgent work), ✅ ignore semver-major updates (rejected: propose majors too).

- An update that changes the version an adapter tracks is an adapter release, not a routine update, which is why majors are ignored. Below 1.0 that version is major.minor (`sh/adapter-versions.sh`), so for each adapter upstream still below 1.0, such as rustls and openmls, also ignore minor updates. The upstream run reviews what Dependabot skips.
- Cargo treats any `0.x` minor bump as breaking, and Dependabot calls it a minor, so for crates that are not adapter upstreams, such as libcrux's, the grouped PR's CI is what catches the break.
