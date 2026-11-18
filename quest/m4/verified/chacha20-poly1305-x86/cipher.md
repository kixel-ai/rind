# [L] cipher::ChaCha20 is proven on x86_64

## Goal

`cipher::ChaCha20` earns the ✓ on x86_64 CPUs with SSE4.1.

## Plan

- Runs ([kixel-ai/rind#811](https://github.com/kixel-ai/rind/pull/811)): with AVX2, pyca/verified-garbage (VG)'s AVX2 or AVX-512 VL routine from 256 bytes, which [its proof quest](/quest/m2/verified-garbage/chacha20-proof.md) imports, and rind's two-block AVX2 kernel (`core_2x`, from Graviola) from two blocks below 256 bytes and for a tail of two to four blocks after VG's eight-block loop; without AVX2, aws-lc's `ChaCha20_ctr32_ssse3_4x` above 128 bytes; and HACL*'s rounds below those. #811 deleted the eight-block kernel, which no length ran any more.
- Done in [kixel-ai/rind#869](https://github.com/kixel-ai/rind/pull/869): `proofs/Rind/X86_64/ChaCha20Avx2.lean` proves the kernel against RFC 8439 with Aeneas over `Rind/X86_64/Simd.lean`'s models of its AVX2 intrinsics, discharging `Kernel`, and `proofs/Rind/X86_64/ChaCha20Cipher.lean` proves rind's loop around HACL*'s rounds and `cipher` at every length. `chacha20_apply_keystream` (AVX2 CPUs) rests only on VG's axioms; `chacha20_apply_keystream_ssse3` (any CPU) also takes aws-lc's SSSE3 routine's contract as the hypothesis `Ssse3`. The kernel now stores its keystream and XORs it a byte at a time, which Aeneas translates; `cipher` took 0.74-0.89 of main's time from 65 to 255 bytes on a Lion Cove P-core of an Intel Core Ultra 7 270K Plus, and the same time as main from 420 bytes.
- Remaining: prove aws-lc's `ChaCha20_ctr32_ssse3_4x` (486 instructions, all decoded under rind's model additions) in HOL Light against `thirdparty/s2n-bignum/common/chacha20poly1305.ml`'s `chacha20_encrypt`, restate the theorem as an axiom about `cipher_ssse3_4x` as `Rind/X86_64/AwsLc.lean` does for aws-lc's other routines, and discharge `Ssse3` with it, so `chacha20_apply_keystream_ssse3` loses the hypothesis. Its 32-bit counter wraps unspecified past 2^32 blocks, which `Ssse3`'s precondition rules out as `check_counter` does.
- VG lost to the SSSE3 routine (1.15 to 1.28 from 1200 B in [run 43881997679](https://github.com/kixel-ai/rind/actions/runs/43881997679)), so it stays.
