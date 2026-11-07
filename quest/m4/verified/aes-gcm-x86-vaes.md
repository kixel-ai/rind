# [XL] AES-GCM on x86_64 with VAES is proven

## Goal

AES-GCM earns the ✓ on x86_64 CPUs with VAES and VPCLMULQDQ (Ice Lake and later, Zen 3 and later), the common tier on today's x86_64 servers and desktops: BoringSSL's VAES kernels, and rind's choice among them, Vale's, and its own, are proven.

## Plan

- Runs (`low/x86_64/aes_gcm_vaes.rs`): BoringSSL's `aes_gcm_{enc,dec}_update_vaes_avx2` from 256 bytes, and `aes_gcm_{enc,dec}_update_vaes_avx512` from 2 KB where the CPU has AVX-512, with their key-power setup `gcm_init_vpclmulqdq_avx2` and `_avx512` in BoringSSL's table layout; below those lengths, the [by-8 and by-16 intrinsics](/quest/m4/verified/aes-gcm-x86-intrinsics.md), and Vale's proven routines for opens under 256 bytes on cores without AVX-512.
- Already proven: Vale's routines, the AEAD API's glue on Vale's tier, and nothing of BoringSSL's. No published proof of a VAES or AVX-512 AES-GCM routine exists, and Vale has none.
- Route: HOL Light proofs of BoringSSL's four kernels and two key setups in s2n-bignum's x86_64 model, against s2n-bignum's SP 800-38D GCM spec (`common/gcm.ml`, which its aarch64 AES-GCM proofs use). The model decodes VPCLMULQDQ at VEX.256 and broad AVX2, but not VAES or EVEX: add VEX.256 `vaesenc` and `vaesenclast` for the AVX2 kernel, and AVX-512 for the other, building on [awslabs/s2n-bignum#462](https://github.com/awslabs/s2n-bignum/pull/462)'s EVEX decoding if it lands. Offer the model and proofs upstream; ask the maintainer before posting outside the moq-dev and kixelated orgs.
- Then Aeneas to Lean for rind's glue around the kernels and the length-based choice, as `Rind/X86_64/AesGcm.lean` does for Vale's tier, with the composition rule's axioms bridging s2n-bignum's GCM spec and Vale's.
- Do the AVX2 kernel first: it is the whole path on Zen 3 and on cores without AVX-512.

## Required

- [rind's own HOL Light proofs have a home that CI checks](/quest/m4/verified/hol-light.md) - where the HOL Light proofs live and are checked until upstream takes them
- [x86_64's by-8 and by-16 AES-GCM intrinsics are proven](/quest/m4/verified/aes-gcm-x86-intrinsics.md) - the short messages this tier hands to them
