# [XL] An AArch32 instruction model checks armv7's assembly

## Goal

A machine-checked model of the 32-bit Arm instructions armv7's assembly uses, integer, NEON, and the ARMv8 crypto extension's AArch32 forms, in which a routine's object code can be proven against a spec, as s2n-bignum's models do for x86_64 and aarch64.

## Plan

- No proof tool rind uses has one: s2n-bignum models x86_64 and aarch64 only, and aws-lc-verification's NSym aarch64.
- Options, for the maintainer to pick from what this finds: extend s2n-bignum with an AArch32 model in HOL Light (its tactics and specs carry over; asking s2n-bignum whether they would take it is a post outside the moq-dev and kixelated orgs, so stop and ask the maintainer first, with no standing approval), or a Lean model derived from Arm's ASL through Sail if it covers AArch32, so armv7's proofs live beside `proofs/`.
- Validate the model against hardware or qemu by random-instruction testing, as s2n-bignum validates its own.
- Prove the smallest routine first, `low/arm/bignum_eq.rs`'s compare, to exercise the model end to end.
