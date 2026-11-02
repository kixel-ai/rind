# [S] armv7 RSA as fast as the fastest source

## Goal

RSA on armv7 runs at least as fast as the fastest permissively licensed source in every benchmark. Bench run [41401089431](https://github.com/moq-dev/rind/actions/runs/41401089431), on [moq-dev/rind#227](https://github.com/moq-dev/rind/pull/227), leaves two gaps: key loading at 1.30x (2048 bits) and 1.34x (8192 bits), and RSA-2056 at 1.07x for signing and 1.08x for verification. Every other armv7 RSA, JWT RS256, and RSA handshake row is at or under 1.01.

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)). Ranked by MoQ impact (armv7 first: it is MoQ's Android target). Measure on the GitHub bench runners, not the shared local host.

aarch64 runs the same RSA code at 0.78x and 0.88x for key loading and 0.97-0.98x at 2056 bits, so both gaps sit in what armv7 alone runs: `low::generic::bignum`'s portable Rust, and aws-lc's `bn_mul_mont_nohw` at widths `bn_mul8x_mont_neon` doesn't take.

- Key loading: its bit-serial `reduce_even` runs two `bignum_modadd`s per bit over 64-bit words, and `bignum_montifier` squares with the portable `mont_mul`. Candidates are a 32-bit `bignum_modadd` and `reduce_even`'s TODO `bignum_moddouble`, and squaring on `bn_mul_mont`. Profile first.
- RSA-2056: its 65-word modulus takes `bn_mul_mont_nohw` in both rind and aws-lc, so the gap is around the multiplication. Profile before choosing a fix.
