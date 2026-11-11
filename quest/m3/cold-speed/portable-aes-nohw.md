# [M] Portable AES bitslices several blocks at once

## Goal

AES on the portable backend, and on armv7 without the crypto extension, encrypts several counter blocks per bitsliced pass, so AES-GCM, AES-CTR, and CBC decryption close most of their gap to aws-lc's C on the nightly's portable row, and `benchmarks/gaps.toml` records what remains.

## Plan

rind's copy of libcrux-aes's block cipher (`rind/src/low/portable/aes.rs`) bitslices one block into eight `u16`s per pass. aws-lc's `aes_nohw.c` bitslices 4 blocks in `uint64_t` on 64-bit targets and 2 on 32-bit ones (8 in `__m128i` with SSE2, as the x86_64 portable row builds it), and rind already ports it for x86_64 without SSSE3 (`rind/src/low/x86_64/aes_nohw.rs`).

Measured on a shared, noisy x86_64 host under `--cfg rind_portable` after [moq-dev/rind#613](https://github.com/moq-dev/rind/pull/613) made AES-GCM keep its key and seal in place: AES-128-GCM at about 0.95 µs for 32 B and 23 µs for 1200 B against aws-lc-rs's 52 ns and 107 ns; raw AES-CTR trailed by 7.5 to 8.9× on the nightly row before it. The block cipher's throughput is now the whole gap from 1200 B up.

- Recommend generalizing `aes_nohw.rs`'s port to a `u64` word (4 blocks) and `u32` (2 blocks) in `low/generic`, and running it for AES-CTR, AES-GCM's counter mode, and CBC decryption on the portable and armv7 backends, measured first against the current block cipher at 32 B, 1200 B, and 16 KB. Keep the single-block cipher where a mode is serial (CBC encryption, the tag's mask) only if it measures faster there.
- A secret path changes: ctgrind on the portable build, and on armv7 with the crypto extension denied.
- Source and proof: aws-lc's `aes_nohw.c` (ISC), unproven; [x86_64 without AES-NI](/quest/m5/verified/x86-no-aesni.md) already plans to prove the port, and [armv7 runs the Rust proofs](/quest/m5/verified-armv7/prove.md) would prove this instead of the libcrux copy.

## Related

- [armv7 raw ciphers from libcrux](/quest/m3/libcrux-ciphers.md) - would replace the block cipher copy with libcrux's export; this replaces it with a faster source
