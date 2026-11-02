# [M] x86_64 AES-GCM without VAES as fast as ring

## Goal

AES-GCM on x86_64 CPUs with AES-NI and PCLMULQDQ but no VAES matches ring at QUIC sizes: today rind is 1.22-1.31x behind at 1200-1350 B on the i7-8700.

## Plan

Planned with the maintainer on 2026-11-02 from [moq-dev/rind#229](https://github.com/moq-dev/rind/pull/229), which fixed the per-call overhead; this replaces the audit's unconfirmed no-VAES gap.

- The remaining cost is the 8-block bulk loop, where AES and GHASH are not interleaved as in aws-lc's and ring's `aesni_gcm` routine; import that routine or interleave the loop.
- No GitHub runner lacks VAES, so measure on the local i7-8700 (one interleaved pass, not reruns) and confirm no regression on the runners' VAES and forced no-AVX2 tiers.
