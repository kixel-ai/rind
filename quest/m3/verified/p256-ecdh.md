# [S] aarch64 P-256 ECDH is proven end to end

## Goal

P-256 ECDH on aarch64 earns the report's ✓: rind's Rust around s2n-bignum's proven `p256_scalarmulbase_alt` and `p256_scalarmul_alt` (byte conversion, the X9.62 point decoding and curve check, the Montgomery conversions, and the result's fault check) is proven with Aeneas → Lean in `proofs/`, as X25519 is, under [the epic's composition rule](/quest/m3/verified/README.md).

## Plan

Planned with the maintainer on 2026-11-03 from [moq-dev/rind#319](https://github.com/moq-dev/rind/pull/319). [moq-dev/rind#321](https://github.com/moq-dev/rind/pull/321) moved agreement onto `p256_scalarmul_alt`, whose proof covers affine input to affine output, inversion included, with no slowdown on the arm64 runner. The strict ✓ rule ([moq-dev/rind#325](https://github.com/moq-dev/rind/pull/325)) also counts that glue, so the `benchmarks/verified.toml` entry waits on its proof. The entry cites the routines' pinned proofs and the glue's.
