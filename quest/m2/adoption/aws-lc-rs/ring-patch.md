# [S] A ring patch shim replaces ring across a binary's tree

## Goal

A binary that adds `[patch.crates-io] ring = { git = "https://github.com/moq-dev/rind" }` builds every crate in its tree that depends on ring 0.17 against rind-ring, and CI proves it with a fixture whose dependencies hard-wire ring.

## Plan

- Add an unpublished crate named `ring` to rind's workspace (`publish = false`). It re-exports rind-ring and accepts ring's features as no-ops, as rind-ring does. Give it a 0.17 version that every `^0.17` requirement accepts, and check how Cargo picks among several packages in one git repo.
- Add a fixture binary whose dependencies call ring directly, such as quinn-proto with its `ring` feature and rustls with `ring`. CI builds it with the patch, checks `cargo tree -i ring` resolves to the shim, and runs one handshake or call through it.
- List the ring items rind-ring doesn't offer (README's "not offered") as the reasons a patched build can fail.
- Document the patch route in MIGRATE.md and rind-ring's README, and move the MIGRATING.md rows it unblocks.
