# [L] aarch64's RSA Montgomery products are proven

## Goal

aws-lc's aarch64 `bn_mul_mont`, which rind runs for every RSA modulus there, is proven in HOL Light against s2n-bignum's Montgomery specification, so RSA verification and signing earn the ✓ on aarch64 once their glue is proven.

## Plan

- Runs: `low/aarch64/aws_lc/bn_mul_mont.*.s`, aws-lc's `armv8-mont.pl`, which dispatches to its squaring (`__bn_sqr8x_mont`) and 4x routines (`__bn_mul4x_mont`) by width. It measured 1.15 to 2 times as fast as s2n-bignum's generic routines on a Neoverse-N2, and faster than its Karatsuba routines at RSA-2048's sizes, so switching fails the speed rule.
- Route: prove each routine in s2n-bignum's aarch64 model, scalar instructions only, against `bignum_montmul`'s specification. The width-generic loops need loop invariants like s2n-bignum's own generic `bignum_montmul`'s.
- Order: RSA-2048, -3072, and -4096 moduli and their CRT primes are multiples of eight words, so they run only `__bn_sqr8x_mont` (squaring) and `__bn_mul4x_mont`. The generic path runs for widths that are not a multiple of four, such as 17 or 33 words. `proofs/hol-light/aarch64/bn_mul_mont.ml` proves the generic path's first pass and inner-loop body; its outer-loop prelude and tail, final subtraction and copy, and frame remain, then the two unrolled routines and the dispatch.
- Import the theorems into `proofs/Rind/Aarch64/` as axioms under the composition rule, retiring the products hypothesis on aarch64.
- Upstream: offering this work to awslabs/s2n-bignum is optional, and there is no standing approval: stop and ask the maintainer before posting there or anywhere outside the moq-dev and kixelated orgs (decided with the maintainer on 2026-11-07 on [moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448)).
