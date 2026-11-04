# [S] ECDSA verification at or below its cost before #324

## Goal

ECDSA verification on P-256, P-384, and P-521, on every target, is at least as fast relative to aws-lc-rs as it was before [moq-dev/rind#324](https://github.com/moq-dev/rind/pull/324) (`ea4381e8`), which made verification compare x-coordinates before each addition (about 6% on P-256 verify).
Close it when every `*-ecdsa-verify` and `*-ecdsa-verify-parsed` row is at or below the pre-#324 run's.

## Plan

[moq-dev/rind#331](https://github.com/moq-dev/rind/pull/331) converts the public key's odd multiples P, 3P, ..., 15P to affine form at key parse (one shared inversion), so each P digit is a mixed addition.

Decided with the maintainer on 2026-11-04. The chosen option is marked ✅.

- Land #331 now as a strict improvement over main ✅ / hold it until fully recovered.
- Convert the multiples at key parse ✅ / per verify.
- For a width-6 NAF over P's digits: defer the extra multiples past a key's first verification ✅ / build them at key parse / drop width 6.

A width-6 NAF over 16 affine multiples built at parse won every `*-ecdsa-verify-parsed` row back to pre-#324 (aarch64 P-256 0.935 vs 0.939), but cost 1-3% over main on the `*-ecdsa-verify` rows, which parse the key for each verification ([width 6](https://github.com/moq-dev/rind/actions/runs/41846927501), [main](https://github.com/moq-dev/rind/actions/runs/41846932619), [pre-#324](https://github.com/moq-dev/rind/actions/runs/41846938684)).
[moq-dev/rind#334](https://github.com/moq-dev/rind/pull/334) keeps #331's parse and builds 17P, ..., 31P on a key's second verification instead, so a key verified once costs what it does on main.

What remains is the `*-ecdsa-verify` rows, still 5-10% over pre-#324 (aarch64 P-256 1.028 vs 0.961): the parse-time table's inversion.
Building the multiples with mixed additions needs 2P affine, which costs an inversion, or an isomorphic curve as libsecp256k1 does, which s2n-bignum's addition proofs do not cover.
