# [S] ECDSA verification adds in affine form

## Goal

ECDSA verification converts the public key's odd multiples to affine coordinates once (one batched inversion, at key parse or first use), so every addition in its double-multiplication loop is the cheaper mixed form, recovering at least the cost [moq-dev/rind#324](https://github.com/moq-dev/rind/pull/324) added on P-256, P-384, and P-521.

## Plan

Planned with the maintainer on 2026-11-03 as a follow-up of #324, which made verification compare x-coordinates before each addition so s2n-bignum's adders only see inputs their proofs cover (about 6% on P-256 verify).

- Decide whether the conversion happens at key parse (faster repeated verifies, larger key) or per verify; measure both on the GitHub runners with a branch and base branch (not `main`).
- Keep the equal-point handling from #324; mixed addition has the same proof contract.
