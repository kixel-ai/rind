# [M] AES-GCM on aarch64 cores with SHA3 is proven

## Goal

AES-128-GCM and AES-256-GCM earn the ✓ on aarch64 cores with the crypto extension and the SHA3 instructions (Apple, Graviton 3 and later, Neoverse N2 and V), where `stitched` runs s2n-bignum's `_alt` kernels: rind's AES-GCM proofs from the AEAD API down no longer take `KernelBuffersLow` as a hypothesis there.

## Plan

- Already proven: AES-GCM on aarch64 with the crypto extension from the AEAD API down, at every length, with every key size on cores without SHA3 and with AES-128 and AES-256 on cores with it: `AesGcm::new`, `encrypt`, `decrypt`, and the AEAD API in `Rind/Aarch64/AesGcmAead.lean`, `encrypt_any` and `decrypt_any` in `Rind/Aarch64/AesGcmAny.lean`, `gcm::Key` in the copy of `Rind/X86_64/GcmKey.lean` that `admin/prove` makes, and AES-192 past the short path, `composed`, in `Rind/Aarch64/AesGcmComposed.lean`, over `Rind/Aarch64/AesGcmLong.lean` and s2n-bignum's kernels' theorems restated in `Rind/Aarch64/S2nBignum.lean`. `benchmarks/verified.toml` gives the ✓ on cores without SHA3.
- Left: on cores with SHA3, where the PMULL table has `eight_way`, `RunsAesGcm alg` (`Rind/Aarch64/AesGcmAead.lean`) assumes `KernelBuffersLow`: the `_alt` kernels' requirement that the blocks' address plus their length is below 2^63, which a pointer tag that sets bit 63 breaks, and which nothing discharges. Android's Bionic heap tags (`0xB4` in the top byte) already put aarch64 Android's buffers outside the bound; an MTE tag, in bits 59 to 56, does not by itself.
- A guard would compare the end of `inout` with 2^63 in `stitched` (`rind/src/low/aarch64/aes_gcm.rs`) before the `_alt` call and otherwise run a proven path, such as the kernels without `_alt` or `composed`, whichever measures faster; its proof replaces `KernelBuffersLow` with the compare's result.
- Then drop `KernelBuffersLow` from `RunsAesGcm`, `GcmReady`, and the theorems in `Rind/Aarch64/AesGcmLong.lean`, and add the ✓ for cores with SHA3 to `benchmarks/verified.toml`, AES-128 and AES-256 alone: AES-192 there runs aws-lc's eight-way kernels, which [their own quest](/quest/m4/verified/aes-gcm-aarch64-192.md) proves.

## Waiting

- Maintainer: How should rind's aarch64 AES-GCM proofs meet s2n-bignum's `_alt` kernels' requirement that the buffer's address plus its length is below 2^63, which they now take as the unproven hypothesis `KernelBuffersLow` on cores with SHA3 (Apple, Graviton 3 and later)?
  - Guard the `_alt` call and prove the guard (Recommended) - one compare per call in `stitched`, falling back to a proven path when the bound fails, so the ✓ covers every target, Android's tagged heap included, which then runs the slower path
  - State the bound per supported target - no code change, but the ✓ excludes aarch64 Android, whose heap pointers set bit 63, and rests on each OS's address layout

## Related

- [aarch64's eight-way AES-192-GCM kernels are proven](/quest/m4/verified/aes-gcm-aarch64-192.md) - AES-192 on the same cores
