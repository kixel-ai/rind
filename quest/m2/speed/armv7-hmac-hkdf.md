# [S] One-block hashes, HMAC, and HKDF as fast as the fastest source

## Goal

Hashing, HMAC, and HKDF on one-block inputs match the fastest source: today 1.12-1.59x on armv7, 1.07-1.17x on aarch64, and 1.02-1.08x on x86_64.

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)); ratios are rind's time over the fastest baseline in nightly run [41378010740](https://github.com/moq-dev/rind/actions/runs/41378010740). Ranked by MoQ impact (armv7 first: it is MoQ's Android target, and ES256 is MoQ's auth). Measure on the GitHub bench runners, not the shared local host.

- The cost is per-call setup (key schedule, padding, context copies), not the compression function; profile one call on each path.
