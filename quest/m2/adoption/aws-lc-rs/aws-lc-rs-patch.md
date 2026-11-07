# [S] An aws-lc-rs patch shim replaces aws-lc-rs across a binary's tree

## Goal

A binary that adds `[patch.crates-io] aws-lc-rs = { git = "https://github.com/moq-dev/rind" }` builds every crate in its tree on aws-lc-rs 1.x against rind-aws-lc-rs, with aws-lc-sys gone from `cargo tree`, and CI proves it with a fixture.

## Plan

- Add an unpublished crate named `aws-lc-rs` (1.x) that re-exports rind-aws-lc-rs, alongside the [`ring` shim](/quest/m2/adoption/aws-lc-rs/ring-patch.md).
- The fixture uses rustls with its default features, which pull in aws-lc-rs, plus quinn-proto's `aws-lc-rs` feature. CI builds it with the patch, checks `cargo tree -i aws-lc-sys` prints nothing, and runs a handshake.
- Document it in MIGRATE.md and move the MIGRATING.md rows it unblocks, such as s2n-quic and libp2p.

## Required

- [rind-aws-lc-rs](/quest/m2/adoption/aws-lc-rs/rind-aws-lc-rs.md) - the API the shim wraps
