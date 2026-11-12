# [S] Adapter crates' surviving mutants

## Goal

The adapters' surviving mutants that change behavior a consumer relies on are killed by tests, and their `exclude_re` entries in `.cargo/mutants.toml` are gone: accessors no test compares with the upstream crate's (`tag_len`, `block_len`, `chaining_len`, rustls' `encrypted_payload_len`, QUIC's confidentiality and integrity limits), `PartialEq` on algorithm handles, and survivors such as rind-dimpl's `SecureRandom::fill` replaced with `Ok(())` and a deleted `(Secp384r1, SHA256)` arm in its `verify_signature`. `Debug` and `Display` survivors stay excluded.

## Plan

- Narrowed on 2026-11-12 while planning [the mutants slim-down](/quest/m0/ci-speed/mutants-slim.md): the maintainer chose to drop low-value mutant work, and the `Debug` and `Display` survivors are that; the rest hide real gaps, such as an RNG that fills nothing.
- Where the upstream crate has the same value, such as ring's or rustls' aws-lc-rs provider's, test against it rather than a literal.
- Run `admin/mutants -p <crate>` on each adapter to confirm none survive.
- Start from the list as the adapter PRs leave it. Those PRs rewrite the adapters to their upstreams' exact APIs, and [moq-dev/rind#521](https://github.com/moq-dev/rind/pull/521) and [moq-dev/rind#515](https://github.com/moq-dev/rind/pull/515) already edit this block of `exclude_re`, so recount the survivors, and drop each entry that no longer matches a mutant, before writing tests.

## Required

- [rind-aws-lc-rs passes aws-lc-rs's own test suite](/quest/m2/confidence/aws-lc-rs-upstream-tests.md) - upstream's tests kill rind-aws-lc-rs's mutants first, so none gets a hand-written test
