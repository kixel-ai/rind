# [XS] AEAD benches at 128, 256, and 512 B

## Goal

`rind-bench` times AES-GCM and ChaCha20-Poly1305 seal and open at 128 B, 256 B, and 512 B on every nightly row, beside 32 B, 1200 B, 1350 B, and 16 KB.

## Plan

This reopens the size list settled with the maintainer on 2026-11-01 for the m2 speed epic: 32 B, 1200 B, 1350 B, and 16 KB, with a full power-of-two sweep rejected. The maintainer accepted reopening it on 2026-11-09, from the speed audit of that day. It is still no sweep: three sizes, each beside a dispatch threshold.

Why: every length at which rind's AEADs switch kernels lies between the 64 B and 1200 B the benches time (`SIZES`, `rind-bench/benches/criterion/mod.rs:9`, and the QUIC-shaped 32 B and 64 B in `rind-bench/benches/aes_gcm.rs:76`), so no run can show a threshold set wrong for a CPU.

- x86_64 AES-GCM seals from 129 B on Vale's kernel where the CPU has AVX and MOVBE but no VAES (`AVX_VALE_SEAL_FROM`, `rind/src/low/x86_64/aes_gcm.rs:529`), and opens under 256 B on Vale's on VAES CPUs (`VAES_AVX2_VALE_OPEN_BELOW`, `rind/src/low/x86_64/aes_gcm.rs:543`).
- aarch64 AES-GCM runs its one-pass short path up to 15 blocks of AAD and message sealing, and 31 opening (`rind/src/low/aarch64/aes_gcm.rs:126`): 240 B and 496 B, less the AAD's blocks.
- x86_64 ChaCha20 without AVX2 runs HACL*'s rounds up to 128 B and aws-lc's SSSE3 routine above (ALGORITHMS.md, "x86_64 CPUs without AVX2 run ChaCha20 above 128 bytes"), which ChaCha20-Poly1305 reaches without SSE4.1, where it runs in separate passes.

So 128 B is the last size below the seal threshold and on HACL*'s rounds, 256 B the first on the wide open kernel and past aarch64's short seal, and 512 B past aarch64's short open. The audit inferred, and did not measure, that MoQ audio frames and QUIC control packets fall in this range.

Guidance:

- Add the sizes to the AEAD benches only (`aes_gcm.rs`, `chacha20poly1305.rs`, `xchacha20poly1305.rs`), with the 13 B AAD of the QUIC-shaped sizes, not to `SIZES`, which the raw ciphers and hashes share.
- Recommend leaving the report's rows (`OPERATIONS` in `admin/bench-report`) as they are: a gap at a new size surfaces on the nightly's tiers.
- No speed gain is expected from this quest. A gap it shows gets a quest or a reason in `benchmarks/gaps.toml`.
- Update the size list in [the report refresh](/quest/m2/bench/report-refresh.md)'s Plan in the same PR.

## Related

- [AMD CPUs without VAES run their fastest AES-GCM tier](/quest/m3/quic-path.md) - set the x86_64 thresholds from measurements at other sizes
