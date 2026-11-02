# [S] SHA-256 fed 1-byte updates as fast as the fastest source

## Goal

SHA-256 fed one byte per update matches the fastest source: today 1.20x on x86_64, 1.34x without AVX2, 1.03-1.07x without AVX, 1.23x on aarch64, and 1.15x without crypto; armv7 is ahead.

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)); ratios are rind's time over the fastest baseline in nightly run [41378010740](https://github.com/moq-dev/rind/actions/runs/41378010740). Ranked by MoQ impact (armv7 first: it is MoQ's Android target, and ES256 is MoQ's auth). Measure on the GitHub bench runners, not the shared local host.

- The cost is the update path's buffering, not the block function.
