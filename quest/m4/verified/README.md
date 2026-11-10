# Every rind path is proven, with the smallest trust base

## Goal

Every operation rind exports earns `benchmarks/verified.toml`'s strict ✓ on every hot tier of x86_64 and aarch64 (the cold tiers are [m5's](/quest/m5/verified/README.md)), including what the [m3 verified epic](/quest/m3/verified/README.md) accepted as a gap, and every algorithm m4 adds. What those proofs trust shrinks to the published theorems, Lean, and Aeneas.

## Plan

Decided with the maintainer on 2026-11-07, planning m4's long-term work with no token budget. This reopens the m3 audit's "accepted unless a route changes it" list: VAES AES-GCM, SIMD ChaCha20-Poly1305, SHA-256 and SHA-1 on every tier, RSA end to end, ML-KEM's construction, P-384 and P-521 glue, x86_64 P-256, armv7's curves, the AES and GHASH fallbacks, and the rest.

- Prove the fast code rind runs; never swap in slower verified code to earn a ✓. Where no proof of a routine exists, write one in HOL Light, in [`proofs/hol-light/`](/quest/m3/verified/hol-light.md), or in Lean. Offering it upstream is optional, with no standing approval: each quest stops and asks the maintainer before posting to awslabs/s2n-bignum or anywhere outside the moq-dev and kixelated orgs (decided with the maintainer on 2026-11-07 on [moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448)).
- The m3 epic's settled choices hold: Aeneas to Lean for rind's Rust, and its composition rule.
- Staging (maintainer, 2026-11-09, after an audit found most children are person-months of HOL Light with no measured cost and nothing ordering them): ✅ calibrate first, and move the cold tiers to m5 (rejected: calibrate only, leave this plan as written). [The aarch64 SHA-256 proof](/quest/m2/verified/sha256-aarch64-hw.md) moved to m2 as the calibration, and every child here that writes new HOL Light requires it. armv7, MD5, SHA-1, and the tiers without AES or SHA hardware moved to [m5](/quest/m5/verified/README.md).
- Audit ([moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448), 2026-11-06), counting [the m3 epic](/quest/m3/verified/README.md)'s open quests as done: the ✓ then holds for X25519 and ChaCha20 header protection on x86_64 and aarch64, P-256 on aarch64, AES-GCM on x86_64's Vale tier, SHA-256 and its MACs and KDFs on x86_64 with SHA-NI, and SHA-384/512 and Ed25519 on Intel x86_64 with AVX but not AVX2 and on aarch64 without the SHA-512 instructions. Every other cell is a child below, ranked by how often the operation and tier run.
  - Upstream since m3: s2n-bignum proves aarch64 AES-GCM against SP 800-38D, out of place only, and models the aarch64 SHA-512 instructions; its FIPS 180-4 specs and x86_64 SHA-NI proof ([awslabs/s2n-bignum#415](https://github.com/awslabs/s2n-bignum/pull/415), [#420](https://github.com/awslabs/s2n-bignum/pull/420), [#450](https://github.com/awslabs/s2n-bignum/pull/450)) are still open. No proof covers the ChaCha20-Poly1305 or VAES AES-GCM assembly rind runs, or any aarch64 ChaCha20 or Poly1305; aws-lc-verification and HACL\* have added nothing rind runs.
  - Most children write HOL Light for assembly no one has proven. Decided with the maintainer on 2026-11-07 on [moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448): those proofs live in [`proofs/hol-light/`](/quest/m3/verified/hol-light.md), run by `admin/prove` beside the Lean proofs over a pinned or vendored s2n-bignum, not in a fork. The SHA-2 children may pin [awslabs/s2n-bignum#415](https://github.com/awslabs/s2n-bignum/pull/415)'s and [#420](https://github.com/awslabs/s2n-bignum/pull/420)'s unmerged specs by commit, moving to the merged versions when they land, with the ✓ noting the pin.
  - Parsing and randomness stay outside the ✓, as `benchmarks/verified.toml` defines it.
  - No algorithm from [post-quantum](/quest/m4/pq/README.md) or [protocols](/quest/m4/protocols/README.md) has landed. Decided with the maintainer on 2026-11-07 on [moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448): [a recurring re-audit](/quest/m4/verified/re-audit.md) at the end of each milestone covers them as they land, rather than each algorithm's quest stating its own route.

## Required

- [Every hand model of untranslated Rust is retired](/quest/m4/verified/aeneas-fn-pointers.md) - the dispatch, HKDF, AES-NI, and key-generation models and the hypotheses standing in for opaque Rust, as Aeneas lifts each limitation
- [Re-audit what's left to prove, end of m3](/quest/m4/verified/re-audit.md) - recurring: what still lacks a ✓, new algorithms included, planned as children
- [AES and QUIC AES header protection are proven with AES hardware](/quest/m4/verified/aes-header-protection.md) - every QUIC packet's mask on x86_64 and aarch64
- [x86_64's by-8 and by-16 AES-GCM intrinsics are proven](/quest/m4/verified/aes-gcm-x86-intrinsics.md) - AES-GCM without AVX, and the Vale tier's short seals, AES-192, odd IVs, and truncated tags
- [AES-GCM on x86_64 with VAES is proven](/quest/m4/verified/aes-gcm-x86-vaes.md) - BoringSSL's VAES kernels, the common x86_64 tier
- [aarch64's AES-GCM kernels are proven in place](/quest/m4/verified/aes-gcm-aarch64-in-place.md) - s2n-bignum's theorems generalized to the aliasing rind uses
- [AES-GCM on aarch64 is proven](/quest/m4/verified/aes-gcm-aarch64.md) - rind's key setup, short-message pass, and glue around the kernels
- [aarch64's eight-way AES-192-GCM kernels are proven](/quest/m4/verified/aes-gcm-aarch64-192.md) - aws-lc's `aesv8_gcm_8x` kernels, AES-192-GCM on cores with SHA3
- [aarch64 SHA-512 on the SHA-512 instructions is proven](/quest/m4/verified/sha512-aarch64-hw.md) - SHA-384, SHA-512, and Ed25519 on Graviton 3, Apple, and Neoverse N2 and V
- [x86_64 SHA-512 on AVX2 is proven](/quest/m4/verified/sha512-x86-avx2.md) - SHA-384, SHA-512, and Ed25519 on every AVX2 core
- [x86_64 SHA-256 on AVX2 without SHA-NI is proven](/quest/m4/verified/sha256-x86-avx2.md) - Intel's cores from Haswell through Cascade Lake
- [The SHA-3 sponge is proven](/quest/m4/verified/sha3-sponge.md) - SHA3 digests, and the hash and XOF calls under ML-KEM
- [ML-KEM-768's construction is proven](/quest/m4/verified/mlkem-construction.md) - rind-rustls's default key exchange on aarch64 and x86_64 with AVX2
- [ML-KEM's AVX-512 sampler is proven](/quest/m4/verified/mlkem-avx512-sampler.md) - the 8-way Keccak and rejection sampling on AVX-512 cores
- [P-256 ECDH and ECDSA are proven on x86_64](/quest/m4/verified/p256-x86.md) - aws-lc's k·G routines and the conversion to affine
- [RSA verification is proven](/quest/m4/verified/rsa-verify.md) - certificate chains' RSA signatures, first on x86_64 with ADX
- [aarch64's RSA Montgomery products are proven](/quest/m4/verified/rsa-aarch64-mont.md) - aws-lc's `bn_mul_mont` in HOL Light
- [ChaCha20-Poly1305 is proven on x86_64](/quest/m4/verified/chacha20-poly1305-x86.md) - aws-lc's stitched assembly, new HOL Light ChaCha20 and Poly1305 specs
- [ChaCha20-Poly1305 is proven on aarch64](/quest/m4/verified/chacha20-poly1305-aarch64.md) - aws-lc's NEON assembly on the same specs
- [The curve proofs' group assumptions are proven](/quest/m4/verified/curve-groups.md) - `P256Order` and Ed25519's group membership leave the trust base
- [RSA signing, decryption, and key generation are proven](/quest/m4/verified/rsa-sign.md) - the CRT private operation, OAEP, and key generation's output
- [x86_64's dual RSAZ IFMA exponentiation is proven](/quest/m4/verified/rsa-x86-ifma.md) - RSA signing on AVX-512 IFMA servers
- [x86_64 SHA-512 on the SHA512 instructions is proven](/quest/m4/verified/sha512-x86-ext.md) - Arrow Lake, Lunar Lake, and later Intel cores
- [P-384 ECDH and ECDSA are proven on x86_64 and aarch64](/quest/m4/verified/p384.md) - rind's comb and double multiplication over s2n-bignum's routines
- [x86_64's other RSA Montgomery products are proven](/quest/m4/verified/rsa-x86-mont.md) - RSA-3072, RSA-4096, and every size without ADX
- [Ed25519 verification on AVX2 without ADX is proven](/quest/m4/verified/ed25519-avx2-verify.md) - rind's port of curve25519-dalek's AVX2 backend
- [AES-CTR, AES-CBC, and AES key wrap are proven with AES hardware](/quest/m4/verified/aes-modes.md) - the raw cipher and key-wrap APIs
- [P-521 ECDH and ECDSA are proven on x86_64 and aarch64](/quest/m4/verified/p521.md) - the same, over P-521's direct field
- [ML-KEM's portable arithmetic is proven](/quest/m4/verified/mlkem-portable.md) - x86_64 without AVX2
- [The portable backend's HACL* paths are proven](/quest/m4/verified/portable.md) - `admin/prove` translates the backend; SHA-2, its MACs and KDFs, and ChaCha20 header protection earn the ✓
- [The portable backend's Keccak-f is proven or replaced](/quest/m4/verified/keccak-portable.md) - SHA-3 and ML-KEM on every architecture without rind assembly
