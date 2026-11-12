# [XL] aarch64's 4x RSA Montgomery product is proven

## Goal

aws-lc's aarch64 `__bn_mul4x_mont`, which `bn_mul_mont` runs for widths that are a multiple of four unless it squares at a multiple of eight, is proven in HOL Light against s2n-bignum's `bignum_montmul` specification, through `bn_mul_mont`'s dispatch to it. RSA verification and every non-squaring product at RSA's sizes run it.

## Plan

- Runs: the `__bn_mul4x_mont` part of `low/aarch64/aws_lc/bn_mul_mont.*.s` (aws-lc's `armv8-mont.pl`), about 380 instructions, entered from offset 0xc. It measured 1.15 to 2 times as fast as s2n-bignum's generic routines on a Neoverse-N2, and faster than its Karatsuba routines at RSA-2048's sizes, so switching fails the speed rule.
- Route: extend `proofs/hol-light/aarch64/bn_mul_mont.ml` in s2n-bignum's aarch64 model, scalar instructions only, with the same statement as the generic path's top-level theorem for widths that are a multiple of four, reusing its carry lemmas (`PROD_BOUND`, `CARRY_ZERO_TAC`) and frame lemmas.
- Decided 2026-11-12 (maintainer, /quest-unblock): ✅ its own quest, after the generic path and before `__bn_sqr8x_mont` (rejected: one quest for all of `bn_mul_mont`). The theorem takes `n * n0 + 1 == 0 (mod 2^64)` as a hypothesis, matching `MontArgs` in `proofs/Rind/X86_64/RsaMont.lean`.
- Upstream: offering this work to awslabs/s2n-bignum is optional, and there is no standing approval: stop and ask the maintainer before posting there or anywhere outside the moq-dev and kixelated orgs (decided with the maintainer on 2026-11-07 on [moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448)).

## Required

- [Generic path](/quest/m4/verified/rsa-aarch64-mont.md) - the lemmas, tactics, and top-level statement this extends
