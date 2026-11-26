# [M] ML-KEM's compressors are byte-checked against mlkem-native's proofs

## Goal

`admin/prove bytes` checks that rind's release build of each ML-KEM ciphertext compressor (4, 5, 10, and 11 bits), mlkem-native's AVX2 assembly on x86_64 and its NEON assembly on aarch64, assembles to the instructions its HOL Light proof checked, and that each constant table it reads (every AVX2 compressor's, and the NEON 5-bit one's) holds the proof's bytes, so the ✓ on ML-KEM's compression covers the bytes rind runs.

## Plan

Found by CodeRabbit's review of [kixel-ai/rind#1036](https://github.com/kixel-ai/rind/pull/1036), which imports the NEON compressors at mlkem-native `58721ebd`: `admin/prove-bytes list` registers s2n-bignum's routines, Vale's, and aws-lc-verification's SHA-512, and none of mlkem-native's, the AVX2 compressors (`low/x86_64/mlkem_compress.rs`) included.

- mlkem-native's proofs assert each routine's bytes in its `proofs/hol_light/x86_64/proofs/mlkem_poly_compress_<d>_avx2_asm.ml` and `proofs/hol_light/aarch64/proofs/mlkem_poly_compress_<d>_aarch64_asm.ml`, as s2n-bignum's do; read them from the pinned commit as `check` reads s2n-bignum's, and compare against `<name>.bin` as the other rows are.
- The upstream objects are proved, so `ALGORITHMS.md`'s ✓ stands (it marks code its source verifies); this closes the gap between that and rind's build.
- Rind's naked AVX2 routines end with `vzeroupper; ret` where the pinned proofs end with `ret`, so the x86_64 rows allow that one epilogue and reject any other difference, rather than reusing the naked rows' rule that forbids `vzeroupper`.
- The AVX2 wrappers take their constant tables by pointer, so the relocations inside a compressor say nothing about them: the check reads each table's bytes from the build, all four AVX2 tables (32 bytes each, d11's 64) and the NEON d5 table, against the proof's constants.
