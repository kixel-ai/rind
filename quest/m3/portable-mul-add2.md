# [S] Portable mul_add2 issues its products before its carry chains

## Goal

Portable RSA at 2048 to 8192 bits, whose limb counts are multiples of 4, runs its product and reduction rows through `mul_add2` in `rind/src/low/generic/mont.rs`, never `mul_add`, so the four-product `mul_add` row leaves it unchanged. `mul_add2` issues a block of its products before the carry chains that add them wherever that measures faster for portable RSA signing and verification at those sizes, at both limb widths; otherwise this quest's PR records the measurement and deletes the quest.

## Plan

- Each limb step computes `u * y[j]` and `v * y[j - 1]`, which depend only on `u`, `v`, and `y`, then folds each into its chain before the next step's multiplies. Issue a block of them first, as `mul_add` does, through its `add_product`.
- The loop count comes from the public lengths and the arithmetic wraps, as now, so nothing branches on a secret. The comment states the bound each sum keeps, at most `2^2b - 1`.
- Test it at both limb widths, with an all-ones closed form like `mul_add_ones` covering every remainder, and the existing `karatsuba` and `modular` proptests against s2n-bignum.
- Measure portable RSA sign and verify against `main` and aws-lc-rs, at both limb widths, with `--cfg rind_portable`.
