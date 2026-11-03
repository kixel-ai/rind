# [S] CI actions are pinned and Pullfrog is constrained

## Goal

Every third-party action rind's workflows use is pinned to a commit SHA, so a moved tag or branch can't change what CI runs with rind's credentials, and the Pullfrog workflow has the narrowest permissions and triggers it needs.

## Plan

Planned with the maintainer on 2026-11-03 from an external audit. Unpinned today: `actions/checkout@v4`, `dtolnay/rust-toolchain@master` and `@nightly`, `cargo-bins/cargo-binstall@main`, and `pullfrog/pullfrog@v0` (with `id-token: write`).

- Pin each to a full SHA with the version in a comment, and let a dependency updater keep the pins current.
- `pullfrog.yml` says to edit it only where indicated: constrain it within what its generator allows, or ask the maintainer.
- Add a check, such as in `sh/alert.sh`'s style, that fails on an unpinned third-party `uses:`.

## Related

- [Confine release credentials to publishing](/quest/m0/confine-release-credentials.md) - the credentials a moved action could reach
