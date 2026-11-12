# [L] aarch64's generic RSA Montgomery product is proven

## Goal

aws-lc's aarch64 `bn_mul_mont`, for the widths its width-generic path runs (those not a multiple of four), is proven whole in HOL Light against s2n-bignum's `bignum_montmul` specification: the dispatch, the prologue and stack frame, both passes, the final subtraction and constant-time copy, and the epilogue. `__bn_mul4x_mont` and `__bn_sqr8x_mont` are their own quests ([4x](/quest/m4/verified/rsa-aarch64-mul4x.md), [8x](/quest/m4/verified/rsa-aarch64-sqr8x.md)), and [the Lean import](/quest/m4/verified/rsa-aarch64-mont-import.md) follows all three.

## Plan

- Runs: `low/aarch64/aws_lc/bn_mul_mont.*.s`, aws-lc's `armv8-mont.pl`. The generic path, at offset 0x10, runs for widths that are not a multiple of four, such as 17 or 33 words. RSA-2048, -3072, and -4096 moduli and their CRT primes are multiples of eight words, so they run only the two unrolled routines.
- Route: prove the path in s2n-bignum's aarch64 model, scalar instructions only, against `bignum_montmul`'s specification, with loop invariants like s2n-bignum's generic `bignum_montmul`'s. `proofs/hol-light/x86_64/bn_mul_mont_nohw.ml` proves x86_64's analogue whole, and its composition (`NOHW_BODY`, the top-level theorem) is the template.
- Done in `proofs/hol-light/aarch64/bn_mul_mont.ml`: the first pass's loop and tail (`GEN_LOOP1`, `GEN_SKIP1`) and the outer loop's inner-loop body (`GEN_IN_BODY`). Left: the outer loop's prelude (0xdc to 0x124) and tail (0x170 to 0x1ac), the inner loop around its body, the outer loop's composition, the final subtraction and copy (0x1b0 to 0x224), the prologue and first-pass prelude (0x10 to 0x70) with the 16-byte-aligned frame, the epilogue, and the top-level theorem with the dispatch at 0x0 to 0xc.
- Decided 2026-11-12 (maintainer, /quest-unblock): ✅ split the original quest into three, the generic path, `__bn_mul4x_mont`, and `__bn_sqr8x_mont`, with the Lean import gated on all three (rejected: keep one quest resized to XL). Order: the generic path first, since the 4x routine reuses its lemmas and tactics, then `__bn_mul4x_mont`, then `__bn_sqr8x_mont`. The theorem takes `n * n0 + 1 == 0 (mod 2^64)` as a hypothesis, matching `MontArgs` in `proofs/Rind/X86_64/RsaMont.lean`.
- Upstream: offering this work to awslabs/s2n-bignum is optional, and there is no standing approval: stop and ask the maintainer before posting there or anywhere outside the moq-dev and kixelated orgs (decided with the maintainer on 2026-11-07 on [moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448)).
