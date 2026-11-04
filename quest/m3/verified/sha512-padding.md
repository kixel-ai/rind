# [L] SHA-512 padding is proven

## Goal

rind's SHA-512 (and SHA-384) message padding and finalization are covered by a formal proof that composes with the verified block function it already calls, so the whole SHA-512 computation earns the report's ✓ on the hosts where that block function runs.

## Plan

Planned with the maintainer on 2026-11-03, from [moq-dev/rind#316](https://github.com/moq-dev/rind/pull/316)'s ✓ research. Under the strict rule, aws-lc-rs earns ✓ for SHA-512 on hosts where rind does not, because rind pads in its own Rust around the same verified block function.

- Prefer reusing an existing proof (aws-lc's SAW proofs of its own SHA-512, or HACL*'s) by matching that implementation's padding exactly, over writing a new proof.
- Otherwise, prove rind's padding with Aeneas → Lean in `proofs/`, as X25519 is, the block function entering through one axiom under [the epic's composition rule](/quest/m3/verified/README.md).
