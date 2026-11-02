# [M] x86_64 AES-GCM with VAES as fast as the fastest source

## Goal

AES-GCM on x86_64 with VAES matches the fastest source at every size: today 1.29-1.35x at 32 B and 1.08-1.19x at 1200-1350 B; rustls bulk transfer is within 1.02x.

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)); ratios are rind's time over the fastest baseline in nightly run [41378010740](https://github.com/moq-dev/rind/actions/runs/41378010740). Ranked by MoQ impact (armv7 first: it is MoQ's Android target, and ES256 is MoQ's auth). Measure on the GitHub bench runners, not the shared local host.

- Small inputs dominate QUIC: the per-call overhead and the tail path matter more than the bulk loop.
- The no-VAES Intel numbers (1.25-1.53x) come only from the shared i7-8700 and are not part of this quest; the Zen 4 runner showed 0.81-1.05x.
