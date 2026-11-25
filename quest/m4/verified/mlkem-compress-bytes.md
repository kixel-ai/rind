# [M] ML-KEM's compressors are byte-checked against mlkem-native's proofs

## Goal

`admin/prove bytes` checks that rind's release build of each ML-KEM ciphertext compressor (4, 5, 10, and 11 bits), mlkem-native's AVX2 assembly on x86_64 and its NEON assembly on aarch64, assembles to the instructions its HOL Light proof checked, and for the 5-bit one that its constant table is the proof's 32 bytes, so the ✓ on ML-KEM's compression covers the bytes rind runs.

## Plan

Found by CodeRabbit's review of [kixel-ai/rind#1036](https://github.com/kixel-ai/rind/pull/1036), which imports the NEON compressors at mlkem-native `58721ebd`: `admin/prove-bytes list` registers s2n-bignum's routines, Vale's, and aws-lc-verification's SHA-512, and none of mlkem-native's, the AVX2 compressors (`low/x86_64/mlkem_compress.rs`) included.

- mlkem-native's proofs assert each routine's bytes in its `proofs/hol_light/<arch>/proofs/mlkem_poly_compress_<d>_<arch>_asm.ml`, as s2n-bignum's do; read them from the pinned commit as `check` reads s2n-bignum's, and compare against `<name>.bin` as the other rows are.
- The upstream objects are proved, so `ALGORITHMS.md`'s ✓ stands (it marks code its source verifies); this closes the gap between that and rind's build.
