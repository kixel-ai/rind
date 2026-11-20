# [L] The portable backend's Poly1305 runs 26-bit limbs on 32-bit targets, if the unproven code is accepted

## Goal

On 32-bit portable targets (ESP32-S3 first, then the Cortex-M, ARMv4T and ARMv5TE, and 32-bit RISC-V cores that reach the portable backend), Poly1305 runs five `u32` limbs in radix 2^26, one 32x32-to-64 multiply per limb product, and where that multiply ends early, is missing, or is a library call, builds each product from four 16-bit halves that cannot end early. ChaCha20-Poly1305 and XChaCha20-Poly1305 on those cores run faster than with HACL*'s Poly1305, and `admin/ct-vartime` fails on a variable-time multiply in `Poly1305::blocks` or `finish`. 64-bit targets and armv7 without NEON keep what they run now. If the maintainer will not accept Poly1305 code that carries no proof, this quest's PR records the measurement in ALGORITHMS.md and deletes the quest.

## Plan

[steelhead99x/rind#191](https://github.com/steelhead99x/rind/pull/191) (`claude/poly1305-32bit-restack`, a fork PR, draft) carries the work. Its base, `claude/xtensa-lint` (fork PR #181, which sends the M-profile targets to the portable backend), is stale and fork-only, so this quest rests on what #191 measures and on the Poly1305 change alone, not on #181.

Today the portable backend's Poly1305 is HACL*'s through `libcrux-poly1305` (`rind/src/low/portable/poly1305.rs`), whose 26-bit limbs live in `u64`s, so a 32-bit compiler emits software 64-bit multiplies and adds. The Cortex-M3's `umull` ends early on small operands, the Cortex-M0, M0+, M1, and M23 have no `umull`, ARMv4T and ARMv5TE end a 32-bit `mul` early on a 16-bit half, and RISC-V without the M extension has no multiply at all.

Measured in #191, on an ESP32-S3 (240 MHz, ESP-IDF v5.5.1, esp rustc 1.97.0.0, 5 rounds with a fresh flash each, CCOUNT, medians, spread under 0.043% across rounds), HACL* against #191's Poly1305, on #87's tree before the restack (the PR's code, not its head):

| row | HACL* cycles | #191 cycles | ratio |
|---|---:|---:|---:|
| Poly1305 64 B | 5,786 | 2,745 | 0.474 |
| Poly1305 1200 B | 73,832 | 41,384 | 0.561 |
| Poly1305 16 KB | 982,929 | 557,411 | 0.567 |
| ChaCha20-Poly1305 seal 32 B | 16,575 | 8,986 | 0.542 |
| ChaCha20-Poly1305 seal 1200 B | 130,082 | 92,368 | 0.710 |
| ChaCha20-Poly1305 seal 16 KB | 1,613,115 | 1,183,661 | 0.734 |

Earlier prebuilt images on a Seeed XIAO ESP32-S3 gave seal 16 KB at 0.735, open 16 KB 0.737, and XChaCha20-Poly1305 32 B 0.490; the same images on an nRF52840 (Cortex-M4F) gave seal 16 KB at 0.698. 330 known-answer checks over 5 boots of each image (RFC 8439, OpenSSL's tags at 0 to 16,384 B, and ring, RustCrypto, and libcrux for every length to 300 B and at 1200, 1350, 8192, and 16,384 B) had 0 failures. No aws-lc-rs or ring timing control ran in those images, and the boards' harness and raw logs are on one machine only. The nRF52840 and early XIAO numbers are of older trees, and nothing was re-measured after the restack.

What makes this a decision, not only a measurement: nothing proves #191's arithmetic. AGENTS.md says to take a verified source (HACL*) only where it measures as fast at every size, and to run the fastest otherwise and plan its proof; HACL* is slower at every size measured here, so this is that case. The argument now is the bounds in `poly1305_32.rs` (limb sums under 2^27 + 2^6, product sums under 2^58, carries under 2^32), RFC 8439 and aws-lc's vectors, every carry out of the final reduction, and agreement with HACL* and the 64-bit implementation over random keys, lengths, and splits.

How this relates to [kixel-ai/rind#794](https://github.com/kixel-ai/rind/pull/794), an open draft that drops libcrux from the `rind` crate and adds a five-limb 26-bit Poly1305 (`generic::poly1305_32`) for 32-bit portable and armv7 without NEON: it describes the same radix, and I have not diffed the two. If it lands first, this quest narrows to what it lacks (the 16-bit-halves layer, `rind_mul16`, the `hide` barrier, the `ct-vartime` rows, the wipe on drop) and becomes a merge of the two; if this lands first, #794 rebases onto it. The same pattern is [the portable SHA-2 quest](/quest/m2/speed/portable-sha2.md), which names #794 too.

Decision rule, measured on a 32-bit board for each target class the code claims, at `main` and at #191 merged with `main`, interleaved, 5 rounds with the clock counted, ChaCha20-Poly1305 at 32 B, 1200 B, and 16 KB:

- Take it for a target class if ChaCha20-Poly1305 seal is at least 5% faster than HACL* at every one of those sizes, the known-answer checks pass, and `admin/ct-vartime` passes its rows for that class. #191's ESP32-S3 ratios are 0.54 to 0.73.
- Do not claim a class nobody timed. #191 measured the ESP32-S3 and the nRF52840 only; Cortex-M0, M3, ARMv4T, ARMv5TE, and RV32I rest on codegen and the `ct-vartime` scans, not on a board, so take their `rind_mul16` paths only when a board is timed, or accept them for constant time alone, which the maintainer decides below.
- Refuse it, delete this quest, and record the numbers in ALGORITHMS.md if the maintainer will not accept unproven Poly1305, or if a class falls under 5%.

If taken, #191's changes land as it carries them:

- `low::generic::poly1305_32` with `rind_limb="32"` so CI tests it on x86_64; `build.rs` sets `rind_mul16` on `thumbv6m`, `thumbv7m`, `thumbv8m.base`, ARMv4T and ARMv5TE (a bit-31 trick, `rind_mul16_top`, since `mul` ends early on a 16-bit half there), and `rind_mul16_soft` on 32-bit RISC-V without M or Zmmul, so no `__mulsi3` call. 32-bit PowerPC and MIPS keep the widening multiply, and `PLATFORMS.md` says why.
- `low::generic::hide` passes the halves and `finish`'s choice of h or h - p through the `rind_reg_asm` barrier (`black_box` elsewhere), so RISC-V, with no conditional move, does not turn the mask select into a branch on h.
- `admin/ct-vartime` scans the three Thumb targets, `armv5te-unknown-linux-gnueabi`, `riscv32i-unknown-none-elf`, `riscv32imac-unknown-none-elf`, and armv7's portable build with `--cfg rind_mul16`, failing on a variable-time multiply or a multiply routine call in `Poly1305::blocks` or `finish`. On ARMv5TE it proves every `mul` and `mla` takes both operands with bit 31 set; on RV32 it rejects a conditional branch on a secret bit, followed through registers and stack slots. A branch planted in `finish` fails the new `+branch` row. ctgrind runs `poly1305_32`'s tests on the widening multiply and does not pass `rind_mul16`, so `ct-vartime` is the scan of that path.
- `Poly1305` wipes its whole value on drop, through `low::zeroise_value`; `poly1305_32::zeroing::zeroes_on_drop` checks every byte after a drop with 0, 5, 16, and 40 buffered bytes and fails with the wipe removed.
- Gates at #191's head `f0dd735a`: `CI_STRICT=1 quest gate sh/dispatch.sh ci` every module passed, `cross` (728 s) and `vartime` (221 s) included; 7 tests in `poly1305_32` and 12 on the portable backend passed; fmt, clippy on the host and `--cfg rind_portable`, `admin/mutants --pins`, `admin/scan-license`, and `quest check` pass.
- Proof, for the ✓ that the portable ChaCha20-Poly1305 loses: a Lean proof of `poly1305_32` against RFC 8439, by Aeneas as [the portable ChaCha20-Poly1305 proof quest](/quest/m5/verified/chacha20-poly1305-portable.md) plans for the other scalar Poly1305, with HACL* the differential reference. That quest names Graviola's 64-bit one; it widens to this when the PR takes this quest.

Not run for #191: the esp toolchain `xtensa-esp32s3-espidf` check at the final head, and any board run after the restack. `libcrux-sha2`'s `expose-hacl` feature still builds `libcrux-hacl-rs` on portable targets, so the libcrux dependency does not leave until #794 or a follow-up gates it.

## Waiting

- Maintainer: whether rind runs Poly1305 on 32-bit portable targets that carries no proof, ahead of HACL*'s proven one, given the ESP32-S3 measurements. Options: (A) accept it, on AGENTS.md's rule to run the fastest source and plan its proof, and add the proof to the portable ChaCha20-Poly1305 quest; (B) keep HACL*'s proven Poly1305 on these cores and delete this quest; (C) accept it for the ESP32-S3 and nRF52840 only, the two boards timed, and keep HACL* on the rest. Recommendation: A, since HACL* is slower at every size and the code is covered by the vectors, the differential tests, and the `ct-vartime` scans, but it is the maintainer's call.
- Maintainer: how to order this with [kixel-ai/rind#794](https://github.com/kixel-ai/rind/pull/794). Options: (A) land #794 first and narrow this quest to the 16-bit-halves layer, the barrier, the scans, and the wipe; (B) land this first and have #794 rebase onto it; (C) fold this into #794. Recommendation: A, because #794 is the larger change and already drops libcrux; this quest then adds only what constant time on early-ending multiplies needs.
- steelhead99x: rerun the ESP32-S3 and nRF52840 rows on the head that lands, since the table above is of the pre-restack tree, and publish the harness and raw logs (the earlier numbers are in [steelhead99x/rind-results](https://github.com/steelhead99x/rind-results) under `results/esp32s3/diag/poly1305-32`). Options: (A) rerun both boards, interleaved with 5 rounds, and post the tables in the quest's PR; (B) give the maintainer SSH access to the boards; (C) take the earlier numbers. Recommendation: A, since the rule needs numbers at the head that lands. Check: the PR body holds the tables.

## Related

- [The portable backend's SHA-256 and SHA-512 run the fastest permissive source](/quest/m2/speed/portable-sha2.md) - the same cores, and #794 touches both
- [ChaCha20-Poly1305 is proven on x86_64 without SSE4.1](/quest/m5/verified/chacha20-poly1305-portable.md) - the proof of the other scalar Poly1305, which this one's proof joins
