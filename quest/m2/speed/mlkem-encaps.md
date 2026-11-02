# [M] ML-KEM-768 encapsulation as fast as the fastest source

## Goal

ML-KEM-768 encapsulation matches the fastest source: today 1.22x on x86_64, 1.12x on aarch64, and 1.05x on armv7; key generation is 1.04-1.06x.

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)); ratios are rind's time over the fastest baseline in nightly run [41378010740](https://github.com/moq-dev/rind/actions/runs/41378010740). Ranked by MoQ impact (armv7 first: it is MoQ's Android target, and ES256 is MoQ's auth). Measure on the GitHub bench runners, not the shared local host.

- Compare libcrux's current release and aws-lc's ML-KEM per step (matrix expansion, NTT, sampling).
