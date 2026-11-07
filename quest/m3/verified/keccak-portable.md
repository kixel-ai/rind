# [M] The portable backend's Keccak-f is proven or replaced

## Goal

The portable backend's Keccak-f permutation (`rind/src/low/portable/keccak.rs`, hand-ported) is either proven against a Keccak-f[1600] spec, or replaced by a verified implementation (such as libcrux/HACL*'s) that is no more than about 10% slower, so no portable path runs an unverified Keccak-f under SHA-3 and ML-KEM.

## Plan

Planned with the maintainer on 2026-11-07, a follow-up of [moq-dev/rind#458](https://github.com/moq-dev/rind/pull/458), which added the portable backend and left this the only unverified Keccak-f on a portable path.

- Measure the candidates on the portable backend first (forced on x86_64 and on an aarch64 runner); AGENTS.md's rule applies: prefer the verified source unless another is more than about 10% faster.
- If the hand port stays, prove it with Aeneas against the same spec [the SHA-3 sponge quest](/quest/m4/verified/sha3-sponge.md) uses, so the two compose.
