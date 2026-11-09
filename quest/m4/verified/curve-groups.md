# [M] The curve proofs' group assumptions are proven

## Goal

The elliptic-curve theorems stop assuming group facts: P-256 ECDSA verification with a parsed public key drops `P256Order`, that every finite point has order n, and Ed25519's `ed25519_key_pair_verify` drops its assumption that a multiple of the base point is a point of the group. `benchmarks/verified.toml`'s P-256 ECDSA entry then states no assumption.

## Plan

- `P256Order` follows from the group having n points. HOL Light's `P256_GROUP_ELEMENT_ORDER` proves it from the group's size; Mathlib cannot count it yet. n·G = O with G ≠ O and n prime gives n dividing the group's order, and Hasse's bound then leaves only n. Prove Hasse's bound in Lean or find it in Mathlib. Offering it to Mathlib if it is missing is optional, with no standing approval: stop and ask the maintainer before posting there or anywhere outside the moq-dev and kixelated orgs (decided with the maintainer on 2026-11-07 on [moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448)).
- Ed25519's fact is closure of `edwards25519_group` under its power, from the group's definition transliterated under the composition rule, as `P256Group.lean` does for P-256.
- Shape the lemmas so [P-384](/quest/m4/verified/p384.md) and [P-521](/quest/m4/verified/p521.md) reuse them.
