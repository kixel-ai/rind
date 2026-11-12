# What rind carries for s2n-bignum

rind's HOL Light proofs build on
[s2n-bignum](https://github.com/awslabs/s2n-bignum) at the commit of rind's
`thirdparty/s2n-bignum` submodule. This directory holds everything rind adds
to it, each listed below so it can be offered upstream. HOL Light loads it
ahead of the submodule.

## Specs from unmerged pull requests

Each is the pull request's file unchanged, at its path in s2n-bignum, so a
submodule bump past its merge deletes it.

- `x86/proofs/utils/sha256_spec.ml`: SHA-256's FIPS 180-4 spec, from
  [awslabs/s2n-bignum#415](https://github.com/awslabs/s2n-bignum/pull/415) at
  `79120e64ed55e37c9652565ff272b7ef17f76738`.

## rind's additions to the x86 model

`x86.patch` adds what aws-lc's x86_64 ChaCha20-Poly1305 and ChaCha20 routines
need, `chacha20_poly1305_{seal,open}`, `poly_hash_ad_internal`, and
`ChaCha20_ctr32_ssse3_4x`, to `x86/proofs/instruction.ml`, `decode.ml`, and
`x86.ml` (maintainer, 2026-11-11, on
[moq-dev/rind#627](https://github.com/moq-dev/rind/pull/627)). Under it every
instruction of those routines, as rind's release build emits them, decodes.
`admin/prove` applies it to the files it changes, where this directory
vendors one, or else to the submodule's, and fails unless every hunk applies
exactly, so a submodule bump that touches them means redoing it.

| Instruction | Encoding | Note |
| --- | --- | --- |
| `PALIGNR xmm, xmm/m128, imm8` | 66 0F 3A 0F /r ib | semantics as in [awslabs/s2n-bignum#450](https://github.com/awslabs/s2n-bignum/pull/450) |
| `VPALIGNR xmm/ymm, xmm/ymm, xmm/ymm/m, imm8` | VEX.128/256.66.0F3A.WIG 0F /r ib | `PALIGNR` in each 128-bit lane |
| `PSLLD xmm, imm8` | 66 0F 72 /6 ib | |
| `PSRLD xmm, imm8` | 66 0F 72 /2 ib | |
| `PSLLDQ xmm, imm8` | 66 0F 73 /7 ib | semantics as in [awslabs/s2n-bignum#439](https://github.com/awslabs/s2n-bignum/pull/439) |
| `PSRLDQ xmm, imm8` | 66 0F 73 /3 ib | semantics as in #439 |
| `PINSRB xmm, r32/m8, imm8` | 66 0F 3A 20 /r ib | REX.W refused |
| `PEXTRB r32/m8, xmm, imm8` | 66 0F 3A 14 /r ib | REX.W refused |
| `PEXTRQ r/m64, xmm, imm8` | 66 REX.W 0F 3A 16 /r ib | |
| `POR xmm, xmm/m128` | 66 0F EB /r | |
| `PUNPCKLDQ xmm, xmm/m128` | 66 0F 62 /r | |
| `PUNPCKHDQ xmm, xmm/m128` | 66 0F 6A /r | |
| `PUNPCKLQDQ xmm, xmm/m128` | 66 0F 6C /r | semantics as in #450 |
| `PUNPCKHQDQ xmm, xmm/m128` | 66 0F 6D /r | semantics as in #450 |
| `VBROADCASTI128 ymm, m128` | VEX.256.66.0F38.W0 5A /r | |
| `RET` with the F3 prefix | F3 C3 | aws-lc's `rep ret`, which every CPU runs as `RET` |

The legacy SSE forms write only the low 128 bits of their register, as the
model's other legacy SSE instructions do, and decode only with the 66 prefix
and no other, where #439 and #450 also take the MMX form without it.
`OPERAND_SIZE_CASES` gains the 32-or-8-bit operand case `PINSRB` and
`PEXTRB` dispatch on.

`x86-cosim.ml` checks every row but the last against the CPU, as s2n-bignum
checks its own instructions: `nix develop .#hol-light --command admin/prove
cosim`, which the `prove` workflow runs. Offering the patch upstream would
also add its encodings to s2n-bignum's `x86/proofs/simulator.ml`, as
s2n-bignum's own additions do. Posting to awslabs/s2n-bignum needs the
maintainer's approval
([moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448)).

## rind's AArch32 model

`aarch32/proofs/` models the A32 instructions armv7's proofs need, after
s2n-bignum's RV32IM model in `riscv/proofs/` and on the 32-bit infrastructure
[awslabs/s2n-bignum#452](https://github.com/awslabs/s2n-bignum/pull/452)
added: `instruction.ml` their semantics, from the Arm Architecture Reference
Manual's AArch32 pseudocode (DDI 0487, part F), `decode.ml` their A32
encodings, `aarch32.ml` the step relation, symbolic-execution tactics, and
AAPCS argument and clobber lists, `consttime.ml` s2n-bignum's safety tactics
specialized to it, and `base.ml` what a proof loads. The state is R0-R12, SP,
LR, PC, the N, Z, C, and V flags, memory, and the event trace s2n-bignum's
safety proofs read.

| Instructions | Forms |
| --- | --- |
| `AND`, `EOR`, `SUB`, `RSB`, `ADD`, `ADC`, `SBC`, `RSC`, `ORR`, `BIC`, and their `S` forms | register with an immediate shift, or a modified immediate |
| `TST`, `TEQ`, `CMP`, `CMN` | the same operands |
| `MOV`, `MVN`, and their `S` forms | the same operands |
| `MOVW`, `MOVT` | 16-bit immediate |
| `LDR`, `LDRB`, `STR`, `STRB` | 12-bit immediate offset, pre-indexed, or post-indexed |
| `B` | 24-bit offset |

Each takes any condition but the unconditional space. The decoder refuses
everything else: Thumb, register-shifted registers, PC as an operand or
destination, `LDRT` and the other unprivileged forms, write-back to the
transferred register, and every other encoding. Loads and stores may be
unaligned, as Linux and Android leave them.

`aarch32/proofs/simulator.ml` cosimulates the model as s2n-bignum's
`riscv/proofs/simulator.ml` does its own: directed cases at the shifts' and
carries' edges, then random instructions from every row above, each with a
random condition and state, which `cosim_runner.c` and `cosim_start.S`, a
static armv7 program, run under qemu-arm, and the model must prove reach the
same state. `admin/prove cosim` runs 1000 random cases, printing the seed,
which `S2N_BIGNUM_SEMATEST_SEED` repeats.

Offering the model upstream is also a post to awslabs/s2n-bignum, which needs
the maintainer's approval.
