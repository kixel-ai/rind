# [L] x86_64's by-8 and by-16 AES-GCM intrinsics are proven

## Goal

rind's own AES-GCM kernels on x86_64, the by-8 AES-CTR and GHASH and the AVX-512 by-16, are proven, so AES-GCM earns the ✓ on x86_64 CPUs with AES-NI but without AVX, and every input the Vale tier hands to them is covered: seals under 129 bytes, AES-192, IVs other than 96 bits, and truncated tags.

## Plan

- Runs: `low/x86_64/aes_gcm.rs`, Graviola's stitched by-8 AES-CTR and by-8 GHASH in SSE-encoded intrinsics, its optional AVX-512 by-16 AES-CTR and GHASH, rind's GHASH key powers, counter, partial blocks, J0 for other IV lengths, and the tag check, under the AEAD API's glue that `proofs/` already proves for Vale's tier.
- Already proven: the AES-NI key expansion and block cipher and the PCLMULQDQ GHASH key powers (`Rind/X86_64/AesKey.lean`, `Ghash.lean`, `Gf128.lean`), the partial-block loads and stores (`PartialBlock.lean`), and the AEAD dispatch model, against Vale's AES and GF(2^128) specs.
- Route: Aeneas to Lean, extending `Rind/X86_64/Simd.lean`'s intrinsic models with what the kernels call (`aesenc`, `aesenclast`, `pclmulqdq`, shuffles, and the AVX-512 forms for by-16), against the same `gcm_encrypt_LE` and `gcm_decrypt_LE` specs, adding AES-192 to the AES spec.
- The by-8 path is also what [AES-GCM of 2^32 bytes and more on the Vale tier](/quest/m3/verified/aes-gcm-vale-long.md) falls back to; if that quest keeps the fallback, this proof covers it.
- The VAES tier's short messages run these kernels too; [its quest](/quest/m4/verified/aes-gcm-x86-vaes.md) composes them with BoringSSL's.

## Related

- [AES-GCM of 2^32 bytes and more is proven on the Vale tier](/quest/m3/verified/aes-gcm-vale-long.md) - chunks Vale or proves the same by-8 fallback
