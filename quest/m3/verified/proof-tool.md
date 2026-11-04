# [M] A Rust proof tool, proven on X25519

## Goal

rind has a chosen tool and CI setup for proving its own Rust, and a rule for composing those proofs with the published proofs of the routines it imports, demonstrated by proving X25519's glue so X25519 earns the report's first ✓ on x86_64 and aarch64.

## Plan

Planned with the maintainer on 2026-11-03 from the [audit](/quest/m3/verified/README.md) ([moq-dev/rind#318](https://github.com/moq-dev/rind/pull/318)). X25519's glue is about 20 lines of byte conversion around s2n-bignum's proven ladder.

- Compare Aeneas→Lean and hax→F* (and any other mature option) on rind's code: what they accept (unsafe, inline asm calls, const generics), CI cost, and maintenance. Recommend one with a decision prompt in the PR.
- Define how a Rust proof relies on an imported routine's theorem (state its contract as an axiom matching the HOL Light or Vale statement), and record that rule in the epic.
- Run the proof in CI, outside the `just ci` gate if it is slow, and add X25519's ✓ entries to `benchmarks/verified.toml`, including x86_64 without BMI2 and ADX, where the proven `_alt` routines run.
