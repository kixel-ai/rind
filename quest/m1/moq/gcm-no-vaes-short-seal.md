# [XS] x86_64 CPUs without VAES seal short AES-GCM messages on their fastest path

## Goal

On x86_64 CPUs with AES-NI and AVX2 but no VAES, short AES-GCM seals and opens run whichever of by-8 and Vale's kernel is faster at each length.

## Plan

Decided with the maintainer on 2026-11-06: plan it in m1 as its own quest, not folded into [quic-path](/quest/m1/moq/quic-path.md), so it doesn't wait on the Zen 2 rerun. After [moq-dev/rind#409](https://github.com/moq-dev/rind/pull/409), by-8 seals 1.11-1.32x faster than Vale below 128 B on Coffee Lake, yet that tier always runs Vale. Measure seals and opens at QUIC sizes under a 13 B AAD on `nixos2` (i7-8700) and `nixos` (Zen 3), under `quest gate --host`, and on GitHub runners, then add crossovers to that tier if by-8 wins. For bulk encryption the fastest source wins outright.

## Waiting

- moq-dev/rind: [moq-dev/rind#409](https://github.com/moq-dev/rind/pull/409) merges; check its state.
