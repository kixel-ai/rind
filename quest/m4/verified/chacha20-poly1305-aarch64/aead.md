# [XL] aws-lc's ChaCha20-Poly1305 seal and open are proven on aarch64

## Goal

`AwsLc` in `proofs/Rind/Aarch64/ChaCha20Poly1305.lean` is discharged, so ChaCha20-Poly1305 and XChaCha20-Poly1305 earn the ✓ at every length on aarch64 CPUs without SVE2, as they do with it.

## Plan

- Runs: rind's structured copy of aws-lc's NEON `chacha20_poly1305_{seal,open}` (`low/aarch64/chacha20poly1305/`), which interleaves NEON ChaCha20 with scalar Poly1305, on CPUs without SVE2 at the lengths `seal_runs_vg` and `open_runs_vg` leave to it: sealing up to 576 bytes and from 769 to 896, and opening up to 128, from 257 to 448, and from 896 to 960.
- Done in [kixel-ai/rind#1118](https://github.com/kixel-ai/rind/pull/1118), on route (a), which the maintainer chose on [kixel-ai/rind#1077](https://github.com/kixel-ai/rind/pull/1077):
  - The copy keeps aws-lc's instructions, inlines `poly_hash_ad_internal`, drops `extra_in`, and lays each routine out as VG's `Code`. It measured within noise of aws-lc's on an Apple M5 Pro and a Neoverse N2, and ALGORITHMS.md lists it as a deliberate change.
  - `RindIsa` gained the instructions it uses, B.cond, and `ite`/`loop` layout.
  - `RindIsa/AArch64/ChaCha20Poly1305.lean` holds `sealProg` and `openProg`, which `admin/prove lean` checks byte for byte and `admin/prove vg` cosimulates.
  - `Rind/Aarch64/ChaCha20Poly1305Asm.lean` proves both programs constant-time for public `x0`–`x5`, `sp`, and the constants' address, through the kernel-checked taint checker in `Rind/Aarch64/Taint.lean`.
- Left: functional correctness of `sealProg` and `openProg` in the model against `Rind/Spec.lean`'s RFC 8439, as `Rind/Aarch64/Sha256HwAsm.lean` proves SHA-256's routine: from a `Pre` (lengths, a 16-byte-aligned stack with 64 writable bytes below it, readable input, AAD, and constants, writable output and data block, input equal to or disjoint from output), the output holds `chacha20.encrypt key 1 nonce msg` and the data block's first 16 bytes the tag, d8–d15, `sp`, and `x30` are kept, and some state meets `Pre`.
  - The programs are flat instruction lists the generator printed. Factor named blocks first, each proven equal to the flat program by `rfl`:
    - the Poly1305 multiply-and-reduce: 31 identical copies in the AAD and tail loops, and split across the round loops in the main and tail paths;
    - the ChaCha20 double round over one, three, or five blocks;
    - the keystream XOR and stores.
  - Prove the Poly1305 block step at the level of numbers: 3 limbs times a clamped 2-limb `r`, partially reduced mod 2^130 − 5. Put it in a file the [x86_64 child](/quest/m4/verified/chacha20-poly1305-x86/aead.md) can import, since aws-lc's x86_64 routines use the same limb schedule.
  - A throwaway interpreter for `Code` ran both programs in the model against the spec at 22 lengths from 1 to 1000 bytes, every branch path, all matching: the model and the programs agree with RFC 8439 at those lengths.
- Then restate the theorems in `Rind/Aarch64/` as axioms about `seal_aws_lc` and `open_aws_lc` that give `AwsLc`, as `Rind/Aarch64/Sha256Hw.lean` restates SHA-256's, and record them in `Axioms.lean`. Add the `verified.toml` entry for `chacha20poly1305/*` and `xchacha20poly1305/*` on aarch64 without SVE2 (`cpu = ["!sve2"]`), replacing the epic's 1350 B and 16 KB one if it has landed. Until `kixtop` is measured at a revision with [kixel-ai/rind#1023](https://github.com/kixel-ai/rind/pull/1023), which moved those two rows to VG's NEON routine, the entry leaves them out, as the epic's README and `benchmarks/verified.toml` say.
- Seal and open are 1,172 and 1,813 instruction words with the inlined helper and alignment.

## Related

- [aws-lc's ChaCha20-Poly1305 seal and open are proven on x86_64](/quest/m4/verified/chacha20-poly1305-x86/aead.md) - the same routines' x86_64 halves, on the same route; `Rind/Aarch64/Taint.lean`'s checker ports to `RindIsa/X86_64` for its leakage half
