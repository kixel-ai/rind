# [L] FN-DSA

## Goal

rind signs and verifies FN-DSA (FIPS 206, from Falcon) at both parameter sets, on every backend, once NIST publishes the final standard.

## Plan

From [the scope](/quest/m4/pq/README.md), 2026-11-06.

- Candidate: Thomas Pornin's [`fn-dsa`](https://github.com/pornin/rust-fn-dsa) (Rust, Unlicense), which tracks NIST's draft and promises compatibility only from its 1.0. It measured 125 µs to sign and 6.7 µs to verify FN-DSA-512 on desktop (1.3 ms keygen). Its signing uses the hardware `f64` on x86_64 and aarch64, relying on those instructions running in constant time; decide then whether to keep that or its integer emulation, and measure both. No verified implementation exists, and aws-lc-rs has none, so differential tests follow the [epic](/quest/m4/pq/README.md)'s rule.
- Scope it again when the standard lands: the API follows [ML-DSA's](/quest/m4/pq/ml-dsa.md), and tests take ACVP vectors once NIST publishes them.

## Waiting

- NIST: publishes FIPS 206. As of NIST IR 8547 (2026-10-27) it is still being developed and no draft is out. Check [NIST's FIPS list](https://csrc.nist.gov/publications/fips) for FIPS 206 final.
