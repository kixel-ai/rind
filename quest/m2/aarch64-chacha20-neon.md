# [S] aarch64's ChaCha20 cipher takes Graviola's open NEON speedups

## Goal

On aarch64, the bare ChaCha20 stream cipher (`mid/chacha20.rs`, which DTLS 1.3 record number protection uses) takes Graviola's two open aarch64 ChaCha20 changes if they measure faster than rind's current routine on the aarch64 report hosts: [ctz/graviola#251](https://github.com/ctz/graviola/pull/251) (head `b3cfec76`), which rotates with `sli` in place of `vshl`/`vshr`/`vorr`, and [ctz/graviola#261](https://github.com/ctz/graviola/pull/261) (head `b9af0d55`), which adds the initial state after the transpose and loads and stores with `vld1q_u32_x4`/`vst1q_u32_x4`. Otherwise this quest records the numbers and is deleted.

## Plan

Found by the 2026-11-14 [upstream-updates](/quest/m2/upstream-updates.md) run, for Graviola's `bdad1050` vertical NEON layout, which the 2026-11-28 run found rind already has: `core_x4` in `low/aarch64/chacha20.rs` is byte for byte Graviola's at `246ae105`, from rind's bootstrap (`3e299b79`). The 2026-11-28 run re-scoped it to #251, which measured 4% faster ChaCha20-Poly1305 at 2 KB on Apple M2, and #261; both were still open upstream. rind's generic rotate is `low/aarch64/chacha20.rs`'s `vorrq_u32(vshlq_n_u32(..), vshrq_n_u32(..))`. rind's ChaCha20-Poly1305 on aarch64 runs aws-lc's and VG's NEON code and is unaffected; only the bare cipher, through `low/aarch64/chacha20.rs`, gains.

- pyca/verified-garbage's routines now run most lengths ([kixel-ai/rind#882](https://github.com/kixel-ai/rind/pull/882)): from 128 bytes with SVE2, and without it from 192 to 256 bytes and from 448. A port gains only below those and from 257 to 447 bytes without SVE2, where VG's NEON routine lost to rind's code, so measure there, and re-time `low/aarch64/chacha20.rs`'s thresholds against the port, since a faster rind loop moves them.
- Bench `rind-bench`'s ChaCha20 against aws-lc-rs before and after on each aarch64 host available.
- [aarch64's NEON ChaCha20 is proven](/quest/m4/verified/chacha20-poly1305-aarch64/cipher.md) waits on this quest to prove whichever routine it leaves.

## Related

- [aarch64's NEON ChaCha20 is proven](/quest/m4/verified/chacha20-poly1305-aarch64/cipher.md) - proves the routine this may replace
