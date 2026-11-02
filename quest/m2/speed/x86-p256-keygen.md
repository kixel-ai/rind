# [S] x86_64 P-256 key generation as fast as the fastest source

## Goal

P-256 on x86_64 matches the fastest source: today key generation is 1.11x, 1.17x without ADX, and 1.12x without AVX2; without AVX2, verification is 1.08x and JWT ES256 signing 1.14x.

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)); ratios are rind's time over the fastest baseline in nightly run [41378010740](https://github.com/moq-dev/rind/actions/runs/41378010740). Ranked by MoQ impact (armv7 first: it is MoQ's Android target, and ES256 is MoQ's auth). Measure on the GitHub bench runners, not the shared local host.

- Upstream graviola 0.4.2 did ECDH 1.16x faster than rind in the audit's scratch harness (same license); check what changed there first.
