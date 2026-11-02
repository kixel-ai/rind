# [M] armv7 P-256 as fast as the fastest source

## Goal

ECDSA and ECDH on P-256 on armv7 run at least as fast as the fastest permissively licensed source: today signing is 2.63x, key generation 1.43x, verification 1.31x, ECDH 1.23x, JWT ES256 2.04x to sign and 1.29x to verify, and the secp256r1 handshake 1.28x. P-384 (1.09x) and P-521 (1.05x) verification are folded in.

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)); ratios are rind's time over the fastest baseline in nightly run [41378010740](https://github.com/moq-dev/rind/actions/runs/41378010740). Ranked by MoQ impact (armv7 first: it is MoQ's Android target, and ES256 is MoQ's auth). Measure on the GitHub bench runners, not the shared local host.

- Find which layer loses first: field arithmetic (fiat-crypto), scalar multiplication (window, precomputed table), or inversion; compare with aws-lc's and ring's armv7 P-256.
- Keep it constant time with ctgrind coverage, and prefer a verified source unless another is more than about 10% faster, per `AGENTS.md`.
