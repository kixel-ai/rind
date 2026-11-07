# [L] aarch64 without the crypto extension is proven

## Goal

Every operation earns the ✓ on aarch64 cores without the crypto extension (the Raspberry Pi 4's Cortex-A72 among them): AES-GCM and the AES modes over vpaes and NEON GHASH, and SHA-256 and SHA-1 over aws-lc's scalar routines.

## Plan

- Runs: aws-lc's `vpaes-armv8` (key schedule, encrypt, decrypt, CTR, CBC; NEON `tbl` lookups, no secret-indexed memory) and `ghash-neon-armv8` (`gcm_init_neon`, `gcm_ghash_neon`), composed into AES-GCM over each eight blocks by rind's Rust as aws-lc composes them; aws-lc's `sha256_block_data_order_nohw` and `sha1_block_data_order_nohw`. SHA-512's `nohw` is already proven.
- Route: HOL Light proofs in s2n-bignum's aarch64 model, which models NEON's `tbl` and 8-bit `pmull`, against `common/fips197.ml`, `common/gcm.ml`, and [awslabs/s2n-bignum#415](https://github.com/awslabs/s2n-bignum/pull/415)'s SHA-256 spec; Aeneas for rind's composition.
- Spec pin: build on [awslabs/s2n-bignum#415](https://github.com/awslabs/s2n-bignum/pull/415)'s spec at a pinned commit while it is unmerged, and move to the merged version when it lands; `benchmarks/verified.toml`'s ✓ notes the pin (decided with the maintainer on 2026-11-07 on [moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448)).
- Upstream: offering this work to awslabs/s2n-bignum is optional, and there is no standing approval: stop and ask the maintainer before posting there or anywhere outside the moq-dev and kixelated orgs (decided with the maintainer on 2026-11-07 on [moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448)).

## Required

- [rind's own HOL Light proofs live in proofs/hol-light](/quest/m4/verified/hol-light.md) - where the HOL Light proofs live and CI checks them
- [AES-GCM on aarch64 is proven](/quest/m4/verified/aes-gcm-aarch64.md) - the AEAD glue this tier shares
