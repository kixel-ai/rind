# [S] aarch64 SHA-256 as fast as the fastest source

## Goal

SHA-256 on aarch64 with the crypto extension matches the fastest source: today 1.26-1.30x from 1200 B, and HMAC-SHA256 1.21-1.30x.

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)); ratios are rind's time over the fastest baseline in nightly run [41378010740](https://github.com/moq-dev/rind/actions/runs/41378010740). Ranked by MoQ impact (armv7 first: it is MoQ's Android target, and ES256 is MoQ's auth). Measure on the GitHub bench runners, not the shared local host.

- Compare the block function with aws-lc's and ring's ARMv8 SHA-256 assembly.
