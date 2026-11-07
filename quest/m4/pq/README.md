# rind covers the standardized post-quantum algorithms

## Goal

rind offers every NIST post-quantum standard and the hybrids that TLS, HPKE, and MLS deploy, without waiting for a consumer: ML-KEM-512 and ML-KEM-1024 beside today's ML-KEM-768, ML-DSA-44/65/87, SLH-DSA, the hybrid KEMs (X-Wing, and P-256 and P-384 with ML-KEM), and FN-DSA and HQC once NIST finalizes them.

## Plan

Decided with the maintainer on 2026-11-07, planning m4's long-term work with no token budget. These leave [aws-lc-rs extras on demand](/quest/m3/parity/aws-lc-extras.md) and are built here. [rustls provider parity](/quest/m3/parity/rustls.md) takes ML-KEM-1024 and ML-DSA from this epic.

- Start with the scope below, which recommends one leaf quest per algorithm from what it finds, as the verified epic's audit did.
- Each algorithm follows `AGENTS.md`: a verified source where one exists (mlkem-native, mldsa-native, s2n-bignum, libcrux's hax-verified ML-KEM and ML-DSA), Wycheproof and NIST vectors, differential tests against aws-lc-rs, ctgrind, and a benchmark on every backend.

## Required

- [Scope the post-quantum algorithms](/quest/m4/pq/scope.md) - sources, speed, proofs, API, and an order to build them in
