# [S] Scope the post-quantum algorithms

## Goal

A report gives the maintainer, for each post-quantum algorithm in the [epic](/quest/m4/pq/README.md), the candidate sources per backend, with their licenses, proofs, and measured speed against aws-lc-rs. It also proposes rind's API for it and an order to build in, and plans a leaf quest for each.

## Plan

- Sources to weigh: pq-code-package's mlkem-native and mldsa-native (HOL Light and CBMC proofs), s2n-bignum's ML-KEM and Keccak, libcrux's ML-KEM and ML-DSA (hax and F*), and SLH-DSA implementations such as the reference's and aws-lc's.
- Hybrids: X-Wing (draft-connolly-cfrg-xwing-kem), and TLS's `X25519MLKEM768`, `SecP256r1MLKEM768`, and `SecP384r1MLKEM1024`. Check which rind-rustls already offers.
- FN-DSA (FIPS 206) and HQC: record their standards' status, and plan each as waiting on its final standard.
- API: one type per parameter set, so a wrong pairing fails to compile, consistent with today's ML-KEM-768 API.
