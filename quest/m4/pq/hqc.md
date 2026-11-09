# [L] HQC

## Goal

rind offers HQC, NIST's second KEM, at its three parameter sets, on every backend, once NIST publishes its final FIPS.

## Plan

From [the scope](/quest/m4/pq/README.md), 2026-11-06.

- Candidate: the [HQC team's implementation](https://gitlab.com/pqc-hqc/hqc) (public domain), with a reference and an x86_64 AVX2 path and nothing for aarch64. v5.1.0 (2026-10-26) changed parameters, sampling, and the key format, so PQClean's 2023 code, which measured 0.8, 1.6, and 2.7 ms for HQC-128 key generation, encapsulation, and decapsulation on desktop, is obsolete. No verified or Rust implementation exists, and aws-lc-rs has none, so differential tests follow the [epic](/quest/m4/pq/README.md)'s rule.
- Its "constant-time" code had new timing leaks published in late 2025 (ePrint 2025/2162); audit whatever source is chosen with ctgrind before trusting it.
- Scope it again when the standard lands: the API joins [ML-KEM's](/quest/m4/pq/ml-kem.md).

## Waiting

- NIST: publishes the HQC FIPS (expected as FIPS 207). As of NIST IR 8547 (2026-10-27) it is under development and no draft is out. Check [NIST's FIPS list](https://csrc.nist.gov/publications/fips).
