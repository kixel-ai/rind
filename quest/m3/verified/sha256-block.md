# [L] x86_64 SHA-NI SHA-256 block function is proven

## Goal

x86_64 with SHA-NI runs a proven SHA-256 block function at today's speed: a proof of rind's current routine (Graviola's intrinsics), or a switch to a proven routine that measures as fast at every size, small messages and HMAC included. Together with the hash glue, SHA-256, HMAC-SHA256, and HKDF then earn ✓ there.

## Plan

Planned with the maintainer on 2026-11-03 from the audit, which found no SHA-256 block function rind runs is proven on any path. Performance comes first: never take a proven routine that is measurably slower.

Findings (2026-11-03):
- HACL*'s Vale `sha256_update` was tried in [moq-dev/rind#328](https://github.com/moq-dev/rind/pull/328) and lost: on Arrow Lake, against today's routine on the same machine, HMAC-SHA256 with a reused key was 29% slower at 32 bytes and 40% at 64, SHA-256 15% slower at 64 bytes, HKDF's extract and expand 11%, and both 3-9% at 1200-1350 bytes. 8 KiB and up tied.
- [awslabs/s2n-bignum#450](https://github.com/awslabs/s2n-bignum/pull/450) (draft, 2026-09-08) adds a HOL Light proof, constant time included, of an x86_64 SHA-NI routine, `sha256_compress_hw`, with a FIPS 180-4 spec, `sha256_spec.ml`, and models `sha256rnds2`, `sha256msg1`, `sha256msg2`, and `palignr`.

Route, once #450 merges:
1. Measure its `sha256_compress_hw` against today's routine on the GitHub runners and on Arrow Lake, rows up to 64 bytes and HMAC included. Switch only if it ties at every size.
2. Otherwise, freeze LLVM's output for today's routine as assembly and prove it on #450's spec in HOL Light, adding to s2n-bignum's x86_64 model any instruction that output uses and #450 does not add.

aarch64 is accepted for now and revisited once #450 merges, since its FIPS 180-4 spec is what a proof of aws-lc's `sha256_block_data_order_hw` would reuse (see the epic).

## Required

- [s2n-bignum's SHA-256 spec has merged](/quest/m3/s2n-bignum-sha2-spec.md) - the spec and proven routine this route starts from
