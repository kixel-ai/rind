# [S] ECDSA's theorems rest on the SHA-256 spec

## Goal

The aarch64 P-256 ECDSA theorems state signatures over FIPS 180-4's SHA-256 of the message, not over the digest rind's implementation computes, by composing with [moq-dev/rind#338](https://github.com/moq-dev/rind/pull/338)'s proof that the two agree.

## Plan

[moq-dev/rind#346](https://github.com/moq-dev/rind/pull/346) proves ECDSA over rind's computed digest because no Lean module can import both `Rind/HashSpec.lean` and the P-256 proofs: their SHA-256 specs share names. Rename one spec's definitions, or merge the two into one, then restate the ECDSA theorems over the spec and pin their axioms. Start once #346 has landed.
