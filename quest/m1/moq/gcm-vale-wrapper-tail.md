# [S] Vale's AES-GCM wrapper pads partial blocks in registers

## Goal

The Rust wrapper around Vale's proven AES-GCM kernel builds a partial AAD or message block in registers rather than through `memcpy`, so short opens under a partial AAD, such as QUIC's 13 B header, stop stalling, and the proof still covers the wrapper.

## Plan

Decided with the maintainer on 2026-11-06: plan it in m1. [moq-dev/rind#409](https://github.com/moq-dev/rind/pull/409) found that padding a partial block through a stack copy compiles to a glibc `memcpy` whose narrow stores stall the 16-byte load after it, and fixed it for by-8 and GHASH with overlapping-load helpers that branch only on the public length. Vale's wrapper still pads through `memcpy`, which is why Vale loses short opens on Intel Xeons under a partial AAD. Reuse #409's helpers, extend the wrapper's proof to the new loads (`admin/prove`), run ctgrind on the changed paths, and re-measure the open crossovers on GitHub's VAES runners and `nixos`. For bulk encryption the fastest source wins outright.

## Waiting

- moq-dev/rind: [moq-dev/rind#409](https://github.com/moq-dev/rind/pull/409) merges; check its state.
