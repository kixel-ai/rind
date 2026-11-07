# [XS] The patch shims live in a small repo of their own

## Goal

`[patch.crates-io] ring = { git = "https://github.com/moq-dev/rind-patch" }` replaces ring with rind-ring, as the line pointing at rind's repo does now, but without cloning rind's test-vector submodules (about 150 MB). The shims there depend on the *published* rind-ring, and every doc gives the new line.

## Plan

Decided with the maintainer on 2026-11-07, following [moq-dev/rind#444](https://github.com/moq-dev/rind/pull/444). Cargo clones a git dependency's whole repo with its submodules, so a consumer patching from rind's repo downloads them once.

- Move `patch/ring` to the new repo's root workspace, depending on rind-ring from crates.io (`0.17`) instead of by path. The [aws-lc-rs shim](/quest/m2/adoption/aws-lc-rs/aws-lc-rs-patch.md) joins it later.
- Keep `patch/fixture` and `sh/patch.sh` in rind, pointed at the new repo, so rind's CI still proves the documented route. Make sure a rind-ring change is tested before its release, for example by having the fixture also patch rind-ring to the checkout.
- Update rind-ring's README and crate docs, MIGRATE.md, and MIGRATING.md.

## Waiting

- Maintainer: create `moq-dev/rind-patch`, or tell the agent to create it. Creating a repository in the org is the maintainer's call. Check: `gh repo view moq-dev/rind-patch` succeeds.
