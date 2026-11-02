# [S] armv7 P-384 multiply without carry-flag spills

## Goal

armv7 P-384's field multiply stops spilling the carry flag, if a non-spilling multiply is more than about 10% faster than fiat-crypto's verified one; otherwise the quest closes with the numbers.

## Plan

Planned with the maintainer on 2026-11-02 from [moq-dev/rind#253](https://github.com/moq-dev/rind/pull/253), whose `umaal`-accumulator P-256 multiply avoided the spills fiat-crypto's armv7 build has (68 `mrs`/`msr` in 2252 instructions for P-384).

- Prefer verified code unless another is more than about 10% faster (`AGENTS.md`); P-384 is already about 1.03x.
- Measure on the GitHub arm64 runner (armv7 in 32-bit mode) or with instruction counts, and test against fiat-crypto on every target.
