# [S] ECDSA verification is correct when the two points are equal

## Goal

ECDSA verification gives the right answer when the double multiplication's two intermediate points are equal (or negatives), on P-256, P-384, and P-521 and every backend, instead of relying on `p256_montjadd` and its siblings returning z = 0 for equal inputs, which their proofs don't state.

## Plan

Planned with the maintainer on 2026-11-03 from the audit ([moq-dev/rind#318](https://github.com/moq-dev/rind/pull/318)).

- First reproduce whether an attacker-chosen signature or key can reach the equal-points case, and what the result is today. If it is reachable and wrong, treat it as a security bug: fix it, and add Wycheproof-style vectors.
- Handle the doubling case explicitly in constant time, as aws-lc does, or show it is unreachable and assert that, citing the argument.
- Check the same pattern on every curve and backend.
