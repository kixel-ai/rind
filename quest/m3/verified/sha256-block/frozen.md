# [M] x86_64 SHA-NI SHA-256 runs frozen assembly at today's speed

## Goal

x86_64 with SHA-NI runs SHA-256's block function and finish as frozen `asm!` blocks rather than intrinsics, with the finish's padding in plain Rust that Aeneas translates, and ties today's routine at every size: SHA-256, HMAC-SHA256 with and without a reused key, and HKDF-SHA256, from 32 bytes to 16 KiB.

## Plan

The shape is in [the epic](/quest/m3/verified/sha256-block/README.md):
- `sha256_compress_blocks_shaext`'s loop and the finish's rounds and digest are LLVM's output of today's intrinsics in `rind/src/low/x86_64/sha256.rs`, frozen into `asm!` blocks with fixed registers, as `low::x86_64::cpu::ct_compare_16` is, so `admin/prove` can extract each block's bytes for the HOL Light proof. Restructure the finish so its rounds appear once where that costs nothing measurable, since each copy is proven separately.
- The finish's padding is a plain Rust function returning the last block's eight 64-bit words, inlined so they reach the block in registers; a stack buffer between them measured 1-4% slower.
- Keep the block's instruction set to what s2n-bignum's x86 model and #450's additions hold (`sha256rnds2`, `sha256msg1`, `sha256msg2`, `palignr`, `punpcklqdq`, `punpckhqdq`, `pshufb`, `pshufd`, `pblendw`, `paddd`, `movdqu`, `movdqa`, `movq`); list in the PR any other the block needs, for the proof to add.
- Measure as #611 did, interleaving both builds on one host, then on the GitHub runners and on Arrow Lake. Keep `paths_match_generic` and `finish_matches_generic`, and run the ctgrind checks under SDE (`admin/ct-sde`).
- SHA-1's finish shares `sha_tail::padded_tail`; leave SHA-1 on it, since SHA-1 stays unproven by the epic's audit.
