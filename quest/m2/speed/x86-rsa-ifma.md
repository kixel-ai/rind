# [L] x86_64 RSA with AVX-512 IFMA

## Goal

On x86_64 CPUs with AVX-512 IFMA, RSA runs as fast as aws-lc's AVX-512 RSA, which beats rind's Haswell path 1.85x, 3.09x, and 3.56x at 2048, 3072, and 4096 bits.

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)); ratios are rind's time over the fastest baseline in nightly run [41378010740](https://github.com/moq-dev/rind/actions/runs/41378010740). Ranked by MoQ impact (armv7 first: it is MoQ's Android target, and ES256 is MoQ's auth). Measure on the GitHub bench runners, not the shared local host.

- Decided 2026-11-02: keep, ranked last; MoQ relays rarely sign RSA.
- A new dispatch tier chosen once per process from CPUID, as the others are. Verify under SDE and on an IFMA runner, with ctgrind.
