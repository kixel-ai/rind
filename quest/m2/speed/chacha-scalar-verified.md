# [S] x86_64 scalar ChaCha20 on HACL*'s verified rounds

## Goal

x86_64 ChaCha20 without AVX2 (up to 128 bytes) and without SSSE3 (every length) runs HACL*'s verified rounds instead of aws-lc's unverified integer routine, unless aws-lc's is more than about 10% faster on the runners, and README's justification matches the measurement.

## Plan

Planned with the maintainer on 2026-11-03 from [moq-dev/rind#287](https://github.com/moq-dev/rind/pull/287). README says aws-lc's integer ChaCha20 measured 1.2x faster than HACL*'s at every length, but #287 measured HACL*'s rounds (as copied for HChaCha20 by [#285](https://github.com/moq-dev/rind/pull/285)) within 10% of it at every length on Coffee Lake, Arrow Lake, and Zen 3.

- Start after #287 lands, reusing its generic `chacha20::cipher`.
- Measure on the runners with a branch and a base branch (not `main`, whose concurrency group cancels other runs), noting which CPU each job drew; switch where HACL* is within about 10%, and correct README either way.
- Test against RFC 8439, Wycheproof, and aws-lc-rs at every length; ctgrind.

## Required

- [ChaCha20 header protection on Zen 5 as fast as aws-lc-rs](/quest/m2/speed/chacha-hp-zen5.md) - adds the generic `chacha20::cipher` this reuses
