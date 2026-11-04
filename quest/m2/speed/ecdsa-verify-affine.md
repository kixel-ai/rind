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

Next lever: a width-6 NAF for the key's digits, 16 affine odd multiples (P, 3P, ..., 31P) under the same one shared inversion.
That cuts P additions by about 14% (about 43 to 37 per P-256 verify), at the cost of 8 more Jacobian additions and the larger batch conversion at key parse, and doubles the key's table (P-256's `VerifyingKey` from 512 to 1024 bytes).
Measure it against pre-#324 on the GitHub bench runners, with bench branches for this change and for `ea4381e8` dispatched together, comparing ratios within each run.
Keep #324's equal-point handling; mixed addition has the same proof contract.
