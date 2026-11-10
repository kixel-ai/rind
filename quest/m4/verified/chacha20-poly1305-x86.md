# [XL] ChaCha20-Poly1305 is proven on x86_64

## Goal

ChaCha20-Poly1305 and XChaCha20-Poly1305, TLS's and QUIC's other AEAD, and `cipher::ChaCha20` earn the ✓ on x86_64 CPUs with SSE4.1, every tier from Westmere up.

## Plan

- Runs: aws-lc's stitched `chacha20_poly1305_{seal,open}` and `poly_hash_ad_internal` (`low/x86_64/aws_lc/`), its AVX2 half where the CPU has AVX2 and BMI2 and its SSE4.1 half otherwise, with rind's one change (the AVX2 choice read from the block rind passes); rind's AEAD glue (`mid/chacha20poly1305.rs`, `xchacha20poly1305.rs`) and HChaCha20 over HACL*'s rounds; and for `cipher::ChaCha20`, rind's AVX2 kernels from two blocks, aws-lc's SSSE3 `ChaCha20_ctr32_ssse3_4x` above 128 bytes without AVX2, and HACL*'s rounds below.
- Already proven: HACL*'s rounds, inside the header-protection proof. Nothing of aws-lc's stitched routine. Other proven x86_64 code exists: Vale's scalar Poly1305 assembly, inside HACL\*'s EverCrypt; libjade's AVX2 ChaCha20 and Poly1305 in Jasmin, proven in EasyCrypt ([The Last Mile](https://arxiv.org/abs/1904.04606)), in separate passes; and HACL\*'s vectorized ChaCha20-Poly1305, which ships only as C.
- First measure libjade's AVX2 ChaCha20 and Poly1305, and Vale's Poly1305, against aws-lc's stitched routine at 32 B, 1350 B, and 16 KB; take a proven one only where it is as fast at every size, which a separate-pass design is unlikely to be.
- Route otherwise: write ChaCha20 and Poly1305 specs in HOL Light against RFC 8439, and prove aws-lc's routines in s2n-bignum's x86_64 model, whose AVX2 decoding is broad; prove the AEAD glue and HChaCha20 with Aeneas, and rind's AVX2 ChaCha20 kernels (`low/x86_64/chacha20.rs`) with Aeneas over modelled intrinsics.
- The specs are [aarch64's quest](/quest/m4/verified/chacha20-poly1305-aarch64.md)'s too.
- Upstream: offering this work to awslabs/s2n-bignum is optional, and there is no standing approval: stop and ask the maintainer before posting there or anywhere outside the moq-dev and kixelated orgs (decided with the maintainer on 2026-11-07 on [moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448)).

## Required

- [rind's own HOL Light proofs live in proofs/hol-light](/quest/m3/verified/hol-light.md) - where the HOL Light proofs live and CI checks them
- [aarch64 SHA-256 on the SHA-2 instructions is proven](/quest/m2/verified/sha256-aarch64-hw.md) - the calibration: what a hand-written HOL Light proof of unproven assembly costs
