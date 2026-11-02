# [M] ML-KEM-768 encapsulation as fast as the fastest source

## Goal

ML-KEM-768 encapsulation and key generation match the fastest source on armv7, where libcrux-ml-kem trails aws-lc-rs by 1.05x and 1.04x, and on any x86_64 or aarch64 path still behind after [moq-dev/rind#233](https://github.com/moq-dev/rind/pull/233).

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)); ratios are rind's time over the fastest baseline in nightly run [41378010740](https://github.com/moq-dev/rind/actions/runs/41378010740). Ranked by MoQ impact (armv7 first: it is MoQ's Android target, and ES256 is MoQ's auth). Measure on the GitHub bench runners, not the shared local host.

- #233 cut rind's own construction (x86_64 and aarch64) to aws-lc's Keccak-f count and gave x86_64 mlkem-native's AVX2 compression; its bench run on the PR says what x86_64 and aarch64 still trail.
- armv7 runs libcrux's portable ML-KEM whole, so none of that reaches it. aws-lc runs mlkem-native's portable C there, which rind already ports for x86_64 without AVX2, where it measured 1.3x faster than libcrux. Running rind's construction on armv7 needs a portable Keccak-f and that port built for 32-bit ARM; measure it against libcrux on the armv7 runner, keeping libcrux if it is within about 2%.
