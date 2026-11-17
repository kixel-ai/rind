# [S] aarch64's ChaCha20 cipher takes Graviola's faster NEON layout

## Goal

On aarch64, the bare ChaCha20 stream cipher (`mid/chacha20.rs`, which DTLS 1.3 record number protection uses) runs Graviola's `bdad1050` NEON layout (2026-10-23, "Additional speedup for ChaCha20 on some aarch64 implementations") if it measures faster than rind's current routine, which began as Graviola's from cifra, on the aarch64 report hosts; otherwise this quest records the numbers and is deleted.

## Plan

Found by the 2026-11-14 [upstream-updates](/quest/m2/upstream-updates.md) run. Graviola measures about 25% faster on Graviton 2 and 5% on Apple M4. rind's ChaCha20-Poly1305 on aarch64 runs aws-lc's NEON code and is unaffected; only the bare cipher, through `low/aarch64/chacha20.rs`, gains.

- Bench `rind-bench`'s ChaCha20 against aws-lc-rs before and after on each aarch64 host available.
- [ChaCha20-Poly1305 is proven on aarch64](/quest/m4/verified/chacha20-poly1305-aarch64.md) plans to prove this routine; a port changes what it proves.

Groundwork, checked 2026-11-17: No port remains, and `main` against this branch times the same code.

Graviola `bdad1050` (`bdad1050e90bdaa6bb601bfab8ed1638e9fb87ae`, Brian Pane, author date 2026-10-23, committed 2026-10-26) rewrites only `core_x4` in `graviola/src/low/aarch64/chacha20.rs`. Its parent `a060b65b` keeps four blocks side by side, one `uint32x4_t` row per block (`a0`..`d3`), and rotates lanes with `vextq_u32` between the column quarter-rounds and the diagonal ones, then rotates them back. `bdad1050` stripes each of the 16 state words down a column (`vdupq_n_u32` for the constant words, the block counter in the four lanes of `col_d_0`), runs the diagonal round by crossing columns (`col_a_0` with `col_b_1`, `col_c_2`, `col_d_3`, and so on), and transposes the columns back to rows with `vzip1q`/`vzip2q` after the 20 rounds. The scalar one-block `core`, `rotate_left`, and the 256-byte dispatch are unchanged in that commit.

`rind/src/low/aarch64/chacha20.rs` already has that kernel. `core_x4`, `core`, `rotate_left`, `four`, `SIGMA`, and `ChaCha20::{new,cipher}` match `bdad1050` byte for byte, and `core_x4` was already that text in the bootstrap (`3e299b79`, 2026-10-27), the day after the commit landed. The same blob is on `upstream/main`. rind never carried the horizontal `vextq` kernel. The header stays the Graviola one (`Written for Graviola by Joe Birr-Pixton, 2024`, `Apache-2.0 OR ISC OR MIT-0`, `Originally from cifra`); Graviola's own file adds no separate line for the vertical kernel. What rind dropped later is `XChaCha20` and `hchacha` in this file (`#285` runs HChaCha20 in general-purpose registers), not the NEON layout.

`admin/parse-asm` has no ChaCha20 entry. Its drivers transliterate s2n-bignum assembly; this routine is NEON intrinsics. The aarch64 proof quest already names `low/aarch64/chacha20.rs` as the `cipher::ChaCha20` routine it proves with Aeneas over modelled NEON intrinsics, so this quest does not change that target. The kernel it will model is the vertical one: column state and the `vzip` transpose, with no `vextq` between rounds. ChaCha20-Poly1305 on aarch64 stays aws-lc's NEON seal/open and is outside this file.

`aws-lc-rs` 1.19's `cipher` module has no ChaCha20. `rind-bench`'s `chacha20` group times `rind` and `verified-garbage` only (`rind-bench/benches/cipher.rs`). `chacha20poly1305` and `quic-header-protection/chacha20` do time aws-lc-rs, and neither calls this `core_x4`: the AEAD is aws-lc's one-pass NEON, and header protection is HACL*'s one block. A main-versus-branch bench of `^chacha20/` is the comparison that would have shown a port. Graviola's earlier horizontal kernel (`a060b65b`) measures 3-6% slower than rind's on an Apple M1 Pro, so the layout rind runs is the faster one. Beyond that layout, this branch adds `core_x8` (two independent four-block groups) and `core_x9` (a ninth block in general-purpose registers); the commits carry the M1 Pro numbers, and the Neoverse host and aarch64 ctgrind are still to run.

## Related

- [ChaCha20-Poly1305 is proven on aarch64](/quest/m4/verified/chacha20-poly1305-aarch64.md) - proves the routine this replaces
