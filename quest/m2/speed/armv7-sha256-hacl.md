# [XS] armv7 without the crypto extension runs the fastest SHA-256

## Goal

On armv7 without the ARMv8 crypto extension, rind's SHA-256 runs whichever of Graviola's routine and HACL*'s is fastest, by the verified-source rule: HACL*'s unless Graviola's is more than about 10% faster. `ALGORITHMS.md` and the bench rows show the pick.

## Plan

Planned with the maintainer on 2026-11-07, a follow-up of [moq-dev/rind#458](https://github.com/moq-dev/rind/pull/458): the portable backend took HACL*'s SHA-256 in place of Graviola's, but armv7 without the crypto extension kept Graviola's unmeasured.

- Time both on armv7 in 32-bit mode on the arm64 runner (as the speed epic's hardware rule says), at 64 B and 1350 B.
