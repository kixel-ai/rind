# [M] rind passes NIST's ACVP vectors

## Goal

A test harness runs NIST's ACVP vector sets (from usnistgov/ACVP-Server's JSON) against every algorithm rind offers that ACVP covers, on every backend, in a slow CI workflow.

## Plan

- Take the sample vector sets for AES modes, SHA-1, SHA-2, SHA-3, HMAC, the KDFs, ECDSA, EdDSA, RSA, ML-KEM, ML-DSA, and the rest, as aws-lc's ACVP tooling does.
- Record which ACVP algorithms rind lacks, and what [the FIPS scope](/quest/m4/fips-scope.md) would need beyond passing vectors.
