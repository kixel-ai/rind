# [XS] The Ed25519 verify benchmark times every library the same way

## Goal

`rind-bench`'s `ed25519-verify` group times each library the same way, with the public key parsed outside the timed loop where the library's API allows it, so the report stops charging rind for a key parse the other rows skip.

## Plan

Decided with the maintainer on 2026-11-07: plan it in m2 speed. [moq-dev/rind#415](https://github.com/moq-dev/rind/pull/415) found the rows aren't comparable. In `rind-bench/benches/ed25519.rs`, rind's row builds `PublicKey::new` inside the loop, which costs about 4 µs per verify. aws-lc-rs's `ParsedPublicKey` and dalek's `VerifyingKey` are built once, outside it. With the key parsed once, rind was level with dalek or faster on an i7-8700 with ADX off (25-27 µs against 29-30).

- Move rind's (and graviola's, if its API allows) key parse out of the loop, matching aws-lc-rs and dalek.
- Keep ring, whose `UnparsedPublicKey` parses on every verify, labelled as such.
- If a parsed-per-call comparison is still wanted, add it as its own row for every library that has one, rather than mixing the two.
- Re-render the report from the next nightly, and drop any `benchmarks/gaps.toml` Ed25519 entry the fix explains.
