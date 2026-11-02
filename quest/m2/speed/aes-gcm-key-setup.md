# [S] AES-GCM key setup as fast as the fastest source

## Goal

Creating an AES-GCM key (as rustls does after HKDF) runs at least as fast as the fastest source: today 1.30x on x86_64, 1.48x on aarch64, and 1.33x on armv7.

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)); ratios are rind's time over the fastest baseline in nightly run [41378010740](https://github.com/moq-dev/rind/actions/runs/41378010740). Ranked by MoQ impact (armv7 first: it is MoQ's Android target, and ES256 is MoQ's auth). Measure on the GitHub bench runners, not the shared local host.

- Check the AES key expansion and the GHASH table precomputation separately on each backend.
