# [L] cipher::ChaCha20 is proven on x86_64

## Goal

`cipher::ChaCha20` earns the ✓ on x86_64 CPUs with SSE4.1.

## Plan

- Prove rind's AVX2 kernels with Aeneas over modelled intrinsics, and aws-lc's `ChaCha20_ctr32_ssse3_4x` (486 instructions, all decoded under rind's model additions) in HOL Light against `thirdparty/s2n-bignum/common/chacha20poly1305.ml`'s `chacha20_encrypt`, and compose them with the HACL* rounds' proof.
- pyca/verified-garbage (VG)'s bare ChaCha20 looked faster than rind's AVX2 kernels on `desktop` (0.52 to 0.93 under load) and slower than the SSSE3 routine (1.08 to 1.37 from 1200 B up); [its switch quest](/quest/m2/verified-garbage/chacha20.md) settles it on the tiers.

## Required

- [cipher::ChaCha20 runs pyca/verified-garbage's code where it is faster](/quest/m2/verified-garbage/chacha20.md) - if it switches with AVX2, this quest shrinks to the SSSE3 routine; delete it if it switches every tier, and drop this link if it switches none
