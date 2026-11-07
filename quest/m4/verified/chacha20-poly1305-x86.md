# [XL] ChaCha20-Poly1305 is proven on x86_64

## Goal

ChaCha20-Poly1305 and XChaCha20-Poly1305, TLS's and QUIC's other AEAD, and `cipher::ChaCha20` earn the ✓ on x86_64 CPUs with SSE4.1, every tier from Westmere up.

## Plan

- Runs: aws-lc's stitched `chacha20_poly1305_{seal,open}` and `poly_hash_ad_internal` (`low/x86_64/aws_lc/`), its AVX2 half where the CPU has AVX2 and BMI2 and its SSE4.1 half otherwise, with rind's one change (the AVX2 choice read from the block rind passes); rind's AEAD glue (`mid/chacha20poly1305.rs`, `xchacha20poly1305.rs`) and HChaCha20 over HACL*'s rounds; and for `cipher::ChaCha20`, rind's AVX2 kernels from two blocks, aws-lc's SSSE3 `ChaCha20_ctr32_ssse3_4x` above 128 bytes without AVX2, and HACL*'s rounds below.
- Already proven: HACL*'s rounds, inside the header-protection proof. No published proof of any ChaCha20 or Poly1305 assembly exists, in s2n-bignum, aws-lc-verification, or elsewhere. HACL*'s vectorized ChaCha20-Poly1305 is proven but ships only as C and is slower.
- Route: write ChaCha20 and Poly1305 specs in HOL Light against RFC 8439, and prove aws-lc's routines in s2n-bignum's x86_64 model, whose AVX2 decoding is broad; prove the AEAD glue and HChaCha20 with Aeneas, and rind's AVX2 ChaCha20 kernels (`low/x86_64/chacha20.rs`) with Aeneas over modelled intrinsics. Offer the HOL Light work upstream; ask the maintainer before posting outside the moq-dev and kixelated orgs.
- The specs are [aarch64's quest](/quest/m4/verified/chacha20-poly1305-aarch64.md)'s too.

## Required

- [rind's own HOL Light proofs have a home that CI checks](/quest/m4/verified/hol-light.md) - where the specs and routine proofs live
