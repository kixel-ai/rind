# [S] An aws-lc-rs patch shim replaces aws-lc-rs across a binary's tree

## Goal

A binary that adds `[patch.crates-io] aws-lc-rs = { git = "https://github.com/moq-dev/rind" }` builds every crate in its tree on aws-lc-rs 1.x against rind-aws-lc-rs, with aws-lc-sys gone from `cargo tree`, and CI proves it with a fixture.

## Plan

- Add an unpublished crate named `aws-lc-rs` (1.x) that re-exports rind-aws-lc-rs, beside the `ring` shim, in [the patch repo](/quest/m2/adoption/aws-lc-rs/patch-repo.md) once it exists.
- Extend `patch/fixture`, which `sh/patch.sh` runs, with rustls's default features, which pull in aws-lc-rs, and quinn-proto's `aws-lc-rs` feature. Check that `cargo tree -i aws-lc-sys` prints nothing, and run its handshake.
- Document it in MIGRATE.md and move the MIGRATING.md rows it unblocks, such as s2n-quic and libp2p.

## Required

- [rind-aws-lc-rs](/quest/m2/adoption/aws-lc-rs/rind-aws-lc-rs.md) - the API the shim wraps
