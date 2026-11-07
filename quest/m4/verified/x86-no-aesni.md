# [XL] x86_64 AES without AES-NI is proven

## Goal

AES-GCM, AES header protection, and the AES modes earn the ✓ on x86_64 CPUs without AES-NI and PCLMULQDQ (Core 2, Nehalem, and SSE2-only virtual CPUs).

## Plan

- Runs: with SSSE3, aws-lc's `vpaes-x86_64` and `ghash-ssse3-x86_64` (`gcm_ghash_ssse3`) assembly, with rind's Rust port of the C that sets up its GHASH table, composed into AES-GCM as aws-lc composes them, taking turns over 3 KB; without SSSE3, rind's Rust ports of aws-lc's `aes_nohw.c` (`low/x86_64/aes_nohw.rs`, a bitsliced AES with the S-box as a circuit, about 950 lines) and `gcm_nohw.c` (`low/generic/ghash_nohw.rs`).
- Already proven: nothing. libcrux's portable AES-GCM measured 3-7x slower.
- Route: HOL Light proofs of the vpaes and SSSE3 GHASH routines in s2n-bignum's x86_64 model against `common/fips197.ml` and `common/gcm.ml`, offered upstream (ask the maintainer before posting outside the moq-dev and kixelated orgs); Aeneas to Lean for the two Rust ports, whose S-box circuit and masked-multiply GHASH reduce to finite checks over every input byte and limb pattern.

## Required

- [rind's own HOL Light proofs have a home that CI checks](/quest/m4/verified/hol-light.md) - where the vpaes and GHASH proofs live
- [x86_64's by-8 and by-16 AES-GCM intrinsics are proven](/quest/m4/verified/aes-gcm-x86-intrinsics.md) - the AES-GCM glue and specs this tier reuses
