# [L] x86_64 SHA-NI SHA-256 block function is proven

## Goal

x86_64 with SHA-NI runs a proven SHA-256 block function at today's speed: a proof of rind's current routine (Graviola's intrinsics), or a switch to a proven routine that measures as fast at every size, small messages and HMAC included. Together with the hash glue, SHA-256, HMAC-SHA256, and HKDF then earn ✓ there.

## Plan

Planned with the maintainer on 2026-11-03 from the audit, which found no SHA-256 block function rind runs is proven on any path. Performance comes first: never take a proven routine that is measurably slower.

Findings (2026-11-03):
- HACL*'s Vale `sha256_update` was tried in [moq-dev/rind#328](https://github.com/moq-dev/rind/pull/328) and lost: on Arrow Lake, against today's routine on the same machine, HMAC-SHA256 with a reused key was 29% slower at 32 bytes and 40% at 64, SHA-256 15% slower at 64 bytes, HKDF's extract and expand 11%, and both 3-9% at 1200-1350 bytes. 8 KiB and up tied.
- [awslabs/s2n-bignum#450](https://github.com/awslabs/s2n-bignum/pull/450) (draft, 2026-09-08) adds a HOL Light proof, constant time included, of an x86_64 SHA-NI routine, `sha256_compress_hw`, with a FIPS 180-4 spec, `sha256_spec.ml`, and models `sha256rnds2`, `sha256msg1`, `sha256msg2`, and `palignr`.

Route (maintainer, 2026-11-09: ✅ start on #450 at a pinned commit; rejected: keep waiting for it to merge, since it has been an untouched draft since 2026-09-08, and the 2026-11-07 decision that put rind's HOL Light proofs in `proofs/hol-light/` already lets rind build on unmerged upstream by pin). The ✓ notes the pin until upstream merges:
1. Measure its `sha256_compress_hw` against today's routine on the GitHub runners and on Arrow Lake, rows up to 64 bytes and HMAC included. Switch only if it ties at every size.
2. Otherwise, freeze LLVM's output for today's routine as assembly and prove it on #450's spec in HOL Light, adding to s2n-bignum's x86_64 model any instruction that output uses and #450 does not add.

aarch64's routine is proven in [the calibration quest](/quest/m2/verified/sha256-aarch64-hw.md), on the same FIPS 180-4 spec.

Consider vendoring s2n-bignum rather than pinning it (maintainer, 2026-11-09). Today it is a submodule at one upstream commit (`thirdparty/s2n-bignum`, 90 MB checked out). A draft PR's commit can vanish on a force-push, and one submodule commit cannot hold #415, #420, and #450 at once without a fork, which the 2026-11-07 decision rejected. Recommended: keep the submodule for merged upstream, and vendor only the unmerged spec and proof files into `proofs/hol-light/`, each with its source PR and commit recorded; vendor the whole tree only if that cannot build. The calibration quest is the first to build on a pin, so it settles this and this quest follows it.

## Required

- [aarch64 SHA-256 on the SHA-2 instructions is proven](/quest/m2/verified/sha256-aarch64-hw.md) - the calibration: what a hand-written HOL Light proof of unproven assembly costs, and how unmerged upstream comes in
