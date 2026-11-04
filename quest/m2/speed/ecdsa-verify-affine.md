# [S] ECDSA verification at or below its cost before #324

## Goal

ECDSA verification on P-256, P-384, and P-521, on every target, is at least as fast relative to aws-lc-rs as it was before [moq-dev/rind#324](https://github.com/moq-dev/rind/pull/324) (`ea4381e8`), which made verification compare x-coordinates before each addition (about 6% on P-256 verify).
Close it when every `*-ecdsa-verify` and `*-ecdsa-verify-parsed` row is at or below the pre-#324 run's.

## Plan

[moq-dev/rind#331](https://github.com/moq-dev/rind/pull/331) converts the public key's odd multiples P, 3P, ..., 15P to affine form at key parse (one shared inversion), so each P digit is a mixed addition.
It beats main on every curve and target, but in its bench runs (rind / aws-lc-rs within each run) a few rows still trail pre-#324: aarch64 `p256-ecdsa-verify` 1.034 vs 0.960, and x86_64 no-ADX `p256-ecdsa-verify-parsed` 1.069 vs 0.974, the latter across different CPUs.

Decided with the maintainer on 2026-11-04. The chosen option is marked ✅.

- Land #331 now as a strict improvement over main ✅ / hold it until fully recovered.
- Convert the multiples at key parse ✅ / per verify.

[moq-dev/rind#334](https://github.com/moq-dev/rind/pull/334) takes the key's digits from a width-6 NAF over 16 affine odd multiples (P, 3P, ..., 31P) under the same one shared inversion, cutting P additions by about a seventh (about 43 to 37 per P-256 verify), and keeps #324's equal-point handling.
Its bench runs, dispatched together, measure it against main and pre-#324: [this change](https://github.com/moq-dev/rind/actions/runs/41846927501), [main](https://github.com/moq-dev/rind/actions/runs/41846932619), and [pre-#324](https://github.com/moq-dev/rind/actions/runs/41846938684).
By count it should win the `*-ecdsa-verify-parsed` rows by about 2% and lose about as much on the `*-ecdsa-verify` rows, which also parse the key and so pay 8 more full additions and the larger batch conversion; the aarch64 `p256-ecdsa-verify` row is one of those.

If width 6 does not pay overall, the parse-time table is the remaining cost: building the multiples with mixed additions needs 2P affine, which costs an inversion, or an isomorphic curve as libsecp256k1 does, which s2n-bignum's addition proofs do not cover.
