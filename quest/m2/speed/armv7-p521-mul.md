# [S] armv7 P-521 multiply without carry-flag spills

## Goal

armv7 P-521's field arithmetic stops spilling the carry flag, if a non-spilling multiply is more than about 10% faster than fiat-crypto's verified one; otherwise the quest closes with the numbers.

## Plan

Planned with the maintainer on 2026-11-03 from [moq-dev/rind#273](https://github.com/moq-dev/rind/pull/273), whose `umaal`-accumulator Montgomery multiply made every armv7 P-384 operation 2.3-2.5x faster than fiat-crypto's.

- P-521 reads 1.04 on armv7 today. Check fiat-crypto's armv7 build for the same `mrs`/`msr` spills first; P-521's Mersenne-like prime reduces differently from P-384's, so reuse #273's multiply only where it fits.
- Prefer verified code unless another is more than about 10% faster (`AGENTS.md`); default to fiat-crypto when close.
- Measure on the GitHub arm64 runner (armv7 in 32-bit mode), test against fiat-crypto on every target, and check constant time with armv7 ctgrind.
