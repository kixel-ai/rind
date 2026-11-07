# rind covers the standardized post-quantum algorithms

## Goal

rind offers every NIST post-quantum standard and the hybrids that TLS, HPKE, and MLS deploy, without waiting for a consumer: ML-KEM-512 and ML-KEM-1024 beside today's ML-KEM-768, ML-DSA-44/65/87, SLH-DSA, the hybrid KEMs (X-Wing, and P-256 and P-384 with ML-KEM), and FN-DSA and HQC once NIST finalizes them.

## Plan

Decided with the maintainer on 2026-11-07, planning m4's long-term work with no token budget. These leave [aws-lc-rs extras on demand](/quest/m3/parity/aws-lc-extras.md) and are built here. [rustls provider parity](/quest/m3/parity/rustls.md) takes ML-KEM-1024 and ML-DSA from this epic.

- Each algorithm follows `AGENTS.md`: a verified source where one exists (mlkem-native, mldsa-native, s2n-bignum, libcrux's hax-verified ML-KEM and ML-DSA), Wycheproof and NIST vectors, differential tests against aws-lc-rs, ctgrind, and a benchmark on every backend.
- The scope ([moq-dev/rind#450](https://github.com/moq-dev/rind/pull/450), 2026-11-06) planned one leaf per algorithm below, in build order. Its measurements: mldsa-native's and mlkem-native's proven kernels, through s2n-bignum, are the fastest sources for ML-KEM and ML-DSA (libcrux trails aws-lc-rs, which runs them); the SPHINCS+ team's SIMD code is the fastest SLH-DSA, and none is verified; FN-DSA and HQC have no draft FIPS yet.
- API, across the epic: one sealed marker type per parameter set parameterizes the key, ciphertext, and signature types, so a wrong pairing fails to compile and each type is its set's exact size. Verification keeps the `&'static` algorithm constants of `signature::verify`, since a certificate names its algorithm at run time.
- Where aws-lc-rs lacks an algorithm (SLH-DSA, X-Wing, the CFRG hybrids, FN-DSA, HQC), differential tests run against the best Rust implementations instead, and behavior follows the standard and its LAMPS or IETF profile.

## Required

- [ML-KEM-512 and ML-KEM-1024](/quest/m4/pq/ml-kem.md) - the typed KEM API, and ML-KEM-1024 for rustls parity
- [ML-DSA-44, ML-DSA-65, and ML-DSA-87](/quest/m4/pq/ml-dsa.md) - mldsa-native's proven kernels, for rustls parity and certificates
- [X-Wing](/quest/m4/pq/x-wing.md) - the hybrid HPKE and MLS use, composed from rind's parts
- [rind-rustls offers SecP384r1MLKEM1024](/quest/m4/pq/rustls-p384-mlkem1024.md) - RFC 10024's third hybrid group
- [SLH-DSA](/quest/m4/pq/slh-dsa.md) - every FIPS 205 parameter set, from the SPHINCS+ team's SIMD code
- [MLKEM768-P256 and MLKEM1024-P384 hybrid KEMs](/quest/m4/pq/cfrg-hybrids.md) - HPKE's and MLS's other hybrids, once the CFRG draft settles
- [FN-DSA](/quest/m4/pq/fn-dsa.md) - once NIST publishes FIPS 206
- [HQC](/quest/m4/pq/hqc.md) - once NIST publishes its FIPS
