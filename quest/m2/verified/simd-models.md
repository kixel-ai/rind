# [S] The Lean models of CPU intrinsics are tested against the instructions

## Goal

Every hand-written Lean model of a CPU intrinsic in `proofs/` is differential-tested against the real instruction: `admin/prove` fails when a model in `proofs/Rind/X86_64/Simd.lean` disagrees with the CPU on any test input, or when an intrinsic model has no test. The models the later quests add (NEON, AVX2, AVX-512, and the SHA instructions) enter through the same check.

## Plan

Found by the 2026-11-09 audit. `proofs/README.md:366` trusts that `Simd.lean`'s intrinsics "compute what Intel's manual defines their instructions to, as an instruction model is trusted for s2n-bignum's". s2n-bignum does not only trust its models: it cosimulates them against an independent executor in CI (`thirdparty/s2n-bignum/SOUNDNESS.md`, risk B1). `Simd.lean` has no test at all, and about ten later quests extend it.

- Today's models: the 16 intrinsics in `proofs/Rind/X86_64/Simd.lean:56-141`, from `_mm_xor_si128` to `_mm_aesenclast_si128`, each a `BitVec` function, so Lean can evaluate it.
- Harness: a Rust program runs each real intrinsic on a set of inputs and writes inputs and outputs as vectors; Lean evaluates the model on the same inputs and `admin/prove` fails on any mismatch. Generate the vectors on the machine that checks them, so the instruction ran on a real CPU, rather than committing them.
- Inputs: random ones from a fixed seed, plus the edges each model has to get right: every immediate the model masks (`_mm_shuffle_epi32`'s and `_mm_clmulepi64_si128`'s selectors, `_mm_slli_si128` at 16 and above, `_mm_srai_epi32` at 32 and above), `_mm_shuffle_epi8` with the high bit of an index set, and all-zero and all-ones lanes.
- Completeness: the check lists the intrinsic models from the Lean source (the `core.core_arch.` definitions) and fails on one with no vectors, so a later quest cannot add an untested model.
- The AES models are the open point: `_mm_aesenc_si128` and `_mm_aesenclast_si128` call `Rind.Vale`'s `sbox` and `mixColumns`, both `opaque` (`proofs/Rind/Vale.lean:89`, `:93`), which Lean cannot evaluate. Give the test FIPS 197's definitions of the two if that leaves every proof intact, and otherwise record them in `proofs/README.md` as the models still untested, with the reason.
- A CPU feature the checking machine lacks: the `prove` workflow runs on one x86_64 runner (`.github/workflows/prove.yml:29`), which has no NEON and may have no AVX-512. Run those intrinsics under the emulators rind's constant-time checks already use (`admin/ct-sde`, `admin/ct-qemu`), and say in `proofs/README.md` which models were tested on hardware and which under an emulator, itself a model. s2n-bignum is moving its own x86 cosimulation to Intel SDE for AVX-512 ([awslabs/s2n-bignum#474](https://github.com/awslabs/s2n-bignum/pull/474), open).
- Out of scope: `proofs/Rind/X86_64/AesNi.lean`'s models of rind's own Rust (raw-pointer loads, `transmute`), which `admin/prove`'s quote check covers, and the dispatch models.
- Reword `proofs/README.md`'s trust-base line: the models are tested against the CPU on these inputs, and trusted beyond them. A test is not a proof, so the line stays.

## Related

- [AES and QUIC AES header protection are proven with AES hardware](/quest/m4/verified/aes-header-protection.md) - the first quest to add NEON models, which this harness then tests
- [x86_64's by-8 and by-16 AES-GCM intrinsics are proven](/quest/m4/verified/aes-gcm-x86-intrinsics.md) - the largest extension of `Simd.lean`, AVX-512 included
