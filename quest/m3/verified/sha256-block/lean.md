# [M] x86_64 SHA-NI SHA-256's padding and composition are proven in Lean

## Goal

`proofs/Rind/X86_64/` proves the SHA-NI finish's plain-Rust padding gives the last block's words of FIPS 180-4's padded message, and composes it, through one axiom per frozen block that restates its HOL Light theorem under the epic's composition rule, into `Sha256Blocks`'s `shaext` and `shaext_finish`, so neither remains a hypothesis.

## Plan

- Follow aarch64's `Rind/Aarch64/Sha256Hw.lean`, which composes `SHA256_HW_SUBROUTINE_CORRECT` with `Rind.S2nSha256`'s transliterated spec.
- The axioms name the HOL Light proof's file at rind's commit; `Axioms.lean` and `HashAxioms.lean` pin them.

## Required

- [Frozen assembly](/quest/m3/verified/sha256-block/frozen.md) - the padding function and the blocks' interface
- [HOL Light proof](/quest/m3/verified/sha256-block/hol-light.md) - the theorems the axioms restate
