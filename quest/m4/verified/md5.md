# [M] MD5 is proven

## Goal

`digest::legacy::MD5` earns the ✓ on every architecture: rind's portable Rust, the only code that computes it, is proven against RFC 1321 through the digest API.

## Plan

- Runs: `low/generic/md5.rs` and `mid/md5.rs`, about 290 lines, over the shared `Blockwise` padding that [the hash glue](/quest/m3/verified/hash-glue.md) proves.
- Route: Aeneas to Lean, with RFC 1321 transliterated beside `Rind/HashSpec.lean` and checked against its test suite, as `HashSpecTest.lean` checks the others.

## Required

- [The hash and KDF glue is proven](/quest/m3/verified/hash-glue.md) - the digest API's dispatch model and the generic padding
