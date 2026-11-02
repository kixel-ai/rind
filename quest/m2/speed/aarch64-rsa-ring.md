# [M] aarch64 RSA as fast as ring

## Goal

RSA on aarch64 matches ring, the fastest source there: today signing is 1.56x at 2048 bits and 1.55x at 4096, verification 1.27x at 2048 and 1.35x at 1024, and RSA handshakes 1.41-1.49x. rind is already faster at 3072 bits and level with aws-lc-rs everywhere.

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)); ratios are rind's time over the fastest baseline in nightly run [41378010740](https://github.com/moq-dev/rind/actions/runs/41378010740). Ranked by MoQ impact (armv7 first: it is MoQ's Android target, and ES256 is MoQ's auth). Measure on the GitHub bench runners, not the shared local host.

- #206 put aws-lc's `bn_mul_mont` at every width but the Karatsuba 16 and 32 words; compare those two widths and the exponentiation with ring's.
- Constant time with ctgrind coverage.
