# [S] aarch64 P-256 earns its proof

## Goal

On aarch64, rind's P-256 base-point table is generated so the s2n-bignum proof's assumption about it holds by construction, and the benchmark report's ✓ table cites that proof for rind's P-256.

## Plan

Planned with the maintainer on 2026-11-03, from [moq-dev/rind#316](https://github.com/moq-dev/rind/pull/316)'s ✓ research. The s2n-bignum routines rind runs on aarch64 assume a precomputed table that rind generates itself (`admin/p256-precomp`), so the proof doesn't cover rind's path today.

- Match the table's construction to what the proof assumes, for example by importing s2n-bignum's own table or proving the generator's output equal to it, and say in `benchmarks/verified.toml` exactly which proof covers it.
- If the proof also assumes something about callers, check rind meets it.

## Related

- [Every computation rind runs is formally verified](/quest/m3/verified/README.md) - the epic this ✓ contributes to
