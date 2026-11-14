# [L] cipher::ChaCha20 is proven on x86_64

## Goal

`cipher::ChaCha20` earns the ✓ on x86_64 CPUs with SSE4.1.

## Plan

- Prove rind's AVX2 kernels with Aeneas over modelled intrinsics, and aws-lc's `ChaCha20_ctr32_ssse3_4x` (486 instructions, all decoded under rind's model additions) in HOL Light against `thirdparty/s2n-bignum/common/chacha20poly1305.ml`'s `chacha20_encrypt`, and compose them with the HACL* rounds' proof.
- pyca/verified-garbage (VG) measured slower on 2026-11-13 (ChaCha20 header protection 1.21 to 1.37x rind's time), so rind keeps this code ([the m2 VG epic](/quest/m2/verified-garbage/README.md)).
