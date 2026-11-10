# Every cold tier is proven

## Goal

Every operation rind exports earns `benchmarks/verified.toml`'s strict ✓ on the tiers few machines run: armv7, the legacy hashes, and x86_64 and aarch64 without AES or SHA hardware.

## Plan

Moved from [the m4 verified epic](/quest/m4/verified/README.md) with the maintainer on 2026-11-09, so the hot tiers' proofs rank ahead of these. That epic's rules hold here: prove the code rind runs, in HOL Light or Lean, under the m3 epic's composition rule.

Under `AGENTS.md`'s speed rule (maintainer, 2026-11-09: ✅ the fastest source, then its proof; rejected: verified code within about 10% on cold tiers, or everywhere), these tiers run their fastest source unproven until a quest here proves it. A verified source replaces one only where it measures as fast at every size.

## Required

- [armv7 is proven](/quest/m5/verified-armv7/README.md) - an AArch32 model, then armv7's assembly, curves, and Rust
- [x86_64 SHA-2 without AVX2 is proven](/quest/m5/verified/sha2-x86-no-avx2.md) - aws-lc's AVX, SSSE3, and scalar routines
- [aarch64 without the crypto extension is proven](/quest/m5/verified/aarch64-no-crypto.md) - vpaes, NEON GHASH, and scalar SHA-256 and SHA-1
- [x86_64 AES without AES-NI is proven](/quest/m5/verified/x86-no-aesni.md) - vpaes and SSSE3 GHASH, and the bitsliced Rust ports
- [ChaCha20-Poly1305 is proven on x86_64 without SSE4.1](/quest/m5/verified/chacha20-poly1305-portable.md) - Graviola's Poly1305 and the separate-pass glue
- [SHA-1 is proven on every x86_64 and aarch64 tier](/quest/m5/verified/sha1.md) - the legacy hash, for RSA, OAEP, and HMAC
- [MD5 is proven](/quest/m5/verified/md5.md) - the legacy digest's portable Rust
