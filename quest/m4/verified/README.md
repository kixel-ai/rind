# Every rind path is proven, with the smallest trust base

## Goal

Every operation rind exports, on every backend and CPU tier, earns `benchmarks/verified.toml`'s strict ✓, including what the [m3 verified epic](/quest/m3/verified/README.md) accepted as a gap, and every algorithm m4 adds. What those proofs trust shrinks to the published theorems, Lean, and Aeneas.

## Plan

Decided with the maintainer on 2026-11-07, planning m4's long-term work with no token budget. This reopens the m3 audit's "accepted unless a route changes it" list: VAES AES-GCM, SIMD ChaCha20-Poly1305, SHA-256 and SHA-1 on every tier, RSA end to end, ML-KEM's construction, P-384 and P-521 glue, x86_64 P-256, armv7's curves, the AES and GHASH fallbacks, and the rest.

- Prove the fast code rind runs; never swap in slower verified code to earn a ✓. Where no proof of a routine exists, write one in s2n-bignum's HOL Light or in Lean, and offer it upstream. Ask the maintainer before posting outside the moq-dev and kixelated orgs.
- The m3 epic's settled choices hold: Aeneas to Lean for rind's Rust, and its composition rule.

## Required

- [Audit what's left to prove](/quest/m4/verified/audit.md) - one leaf quest per remaining gap, cheapest route first
- [rind's assembly is byte-identical to the proven object code](/quest/m4/verified/asm-bytes.md) - the transliteration leaves the trust base
- [Aeneas translates function pointers](/quest/m4/verified/aeneas-fn-pointers.md) - the hand models of rind's dispatch retire
