# [L] armv7 RSA as fast as the fastest source

## Goal

RSA on armv7 runs at least as fast as the fastest permissively licensed source: today signing is 2.28-2.62x, verification 2.84x, key loading 6.42x, JWT RS256 2.72x to sign and 2.91x to verify, and RSA handshakes 2.21-2.50x.

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)); ratios are rind's time over the fastest baseline in nightly run [41378010740](https://github.com/moq-dev/rind/actions/runs/41378010740). Ranked by MoQ impact (armv7 first: it is MoQ's Android target, and ES256 is MoQ's auth). Measure on the GitHub bench runners, not the shared local host.

- Key loading's 6.42x likely comes from precomputation at load (Montgomery constants, CRT values); check it first.
- Then the Montgomery multiplication: aws-lc's and ring's armv7 `bn_mul_mont` (NEON) against libcrux's portable bignum.
- Constant time with ctgrind coverage.
