module
public import Aeneas
@[expose] public section
set_option linter.style.nameCheck false
open Aeneas Aeneas.Std Result

/-!
# x86_64's 256-bit vectors and the AVX2 intrinsics rind's Ed25519 double multiplication calls

As `Rind.X86_64.Simd` models the 128-bit ones: `core::arch` implements each
intrinsic with an LLVM builtin, which Aeneas cannot translate, so these model
them by hand, each as Intel's Software Developer's Manual defines its
instruction, and as `core::arch` passes its immediate. `__m256i` is its 256
bits, lane 0 lowest. That these models are what the CPU computes is trusted,
as an instruction model is for s2n-bignum's and Vale's own proofs;
`admin/simd-vectors.rs` tests each against the instruction.
-/

/-- `__m256i`: 256 bits, lane 0 lowest. -/
@[reducible] def core.core_arch.x86.__m256i : Type := BitVec 256

namespace rind.avx2

/-- 32-bit lane `i`. -/
def lane32 (x : BitVec 256) (i : Nat) : BitVec 32 := x.extractLsb' (32 * i) 32

/-- 64-bit lane `i`. -/
def lane64 (x : BitVec 256) (i : Nat) : BitVec 64 := x.extractLsb' (64 * i) 64

/-- The vector of eight 32-bit lanes, lane 0 lowest. -/
def ofLanes32 (f : Nat → BitVec 32) : BitVec 256 :=
  f 7 ++ f 6 ++ f 5 ++ f 4 ++ f 3 ++ f 2 ++ f 1 ++ f 0

/-- The vector of four 64-bit lanes, lane 0 lowest. -/
def ofLanes64 (f : Nat → BitVec 64) : BitVec 256 := f 3 ++ f 2 ++ f 1 ++ f 0

/-- An immediate as the instruction reads it: its low 8 bits. -/
def imm8 (x : Std.I32) : Nat := x.bv.toNat % 256

end rind.avx2

open rind.avx2

/-- `__m256i`'s `Clone`. -/
def core.core_arch.x86.__m256i.Insts.CoreCloneClone.clone (x : core.core_arch.x86.__m256i) :
    Result core.core_arch.x86.__m256i :=
  ok x

/-- `_mm256_setzero_si256`. -/
def core.core_arch.x86.avx._mm256_setzero_si256 : Result core.core_arch.x86.__m256i :=
  ok 0

/-- `_mm256_setr_epi32`: the 32-bit lanes in order, the first lowest. -/
def core.core_arch.x86.avx._mm256_setr_epi32 (e0 e1 e2 e3 e4 e5 e6 e7 : Std.I32) :
    Result core.core_arch.x86.__m256i :=
  ok (ofLanes32 fun i => [e0.bv, e1.bv, e2.bv, e3.bv, e4.bv, e5.bv, e6.bv, e7.bv][i]!)

/-- `_mm256_set1_epi64x`: each 64-bit lane `a`. -/
def core.core_arch.x86.avx._mm256_set1_epi64x (a : Std.I64) : Result core.core_arch.x86.__m256i :=
  ok (ofLanes64 fun _ => a.bv)

/-- `_mm256_and_si256`, `VPAND`. -/
def core.core_arch.x86.avx2._mm256_and_si256 (a b : core.core_arch.x86.__m256i) :
    Result core.core_arch.x86.__m256i :=
  ok (a &&& b)

/-- `_mm256_add_epi32`, `VPADDD`: each 32-bit lane's sum, wrapping. -/
def core.core_arch.x86.avx2._mm256_add_epi32 (a b : core.core_arch.x86.__m256i) :
    Result core.core_arch.x86.__m256i :=
  ok (ofLanes32 fun i => lane32 a i + lane32 b i)

/-- `_mm256_sub_epi32`, `VPSUBD`: each 32-bit lane's difference, wrapping. -/
def core.core_arch.x86.avx2._mm256_sub_epi32 (a b : core.core_arch.x86.__m256i) :
    Result core.core_arch.x86.__m256i :=
  ok (ofLanes32 fun i => lane32 a i - lane32 b i)

/-- `_mm256_add_epi64`, `VPADDQ`: each 64-bit lane's sum, wrapping. -/
def core.core_arch.x86.avx2._mm256_add_epi64 (a b : core.core_arch.x86.__m256i) :
    Result core.core_arch.x86.__m256i :=
  ok (ofLanes64 fun i => lane64 a i + lane64 b i)

/-- `_mm256_sub_epi64`, `VPSUBQ`: each 64-bit lane's difference, wrapping. -/
def core.core_arch.x86.avx2._mm256_sub_epi64 (a b : core.core_arch.x86.__m256i) :
    Result core.core_arch.x86.__m256i :=
  ok (ofLanes64 fun i => lane64 a i - lane64 b i)

/-- `_mm256_mul_epu32`, `VPMULUDQ`: each 64-bit lane the product of the
operands' low 32 bits there, unsigned. -/
def core.core_arch.x86.avx2._mm256_mul_epu32 (a b : core.core_arch.x86.__m256i) :
    Result core.core_arch.x86.__m256i :=
  ok (ofLanes64 fun i => (lane32 a (2 * i)).setWidth 64 * (lane32 b (2 * i)).setWidth 64)

/-- `_mm256_blend_epi32::<IMM8>`, `VPBLENDD`: lane `i` is `b`'s if bit `i` of
`IMM8` is set, and otherwise `a`'s. -/
def core.core_arch.x86.avx2._mm256_blend_epi32 (IMM8 : Std.I32) (a b : core.core_arch.x86.__m256i) :
    Result core.core_arch.x86.__m256i :=
  ok (ofLanes32 fun i => if (imm8 IMM8).testBit i then lane32 b i else lane32 a i)

/-- `_mm256_permutevar8x32_epi32`, `VPERMD`: lane `i` is `a`'s lane that the low
three bits of `b`'s lane `i` select. -/
def core.core_arch.x86.avx2._mm256_permutevar8x32_epi32 (a b : core.core_arch.x86.__m256i) :
    Result core.core_arch.x86.__m256i :=
  ok (ofLanes32 fun i => lane32 a ((lane32 b i).toNat % 8))

/-- `_mm256_shuffle_epi32::<IMM8>`, `VPSHUFD`: in each 128-bit half, lane `i` is
the half's lane that bits `2i` and `2i + 1` of `IMM8` select. -/
def core.core_arch.x86.avx2._mm256_shuffle_epi32 (IMM8 : Std.I32) (a : core.core_arch.x86.__m256i) :
    Result core.core_arch.x86.__m256i :=
  ok (ofLanes32 fun i => lane32 a (i / 4 * 4 + imm8 IMM8 / 4 ^ (i % 4) % 4))

/-- `_mm256_unpacklo_epi32`, `VPUNPCKLDQ`: in each 128-bit half, its low two
lanes of `a` and `b`, interleaved, `a`'s first. -/
def core.core_arch.x86.avx2._mm256_unpacklo_epi32 (a b : core.core_arch.x86.__m256i) :
    Result core.core_arch.x86.__m256i :=
  ok (ofLanes32 fun i => lane32 (if i % 2 = 0 then a else b) (i / 4 * 4 + i % 4 / 2))

/-- `_mm256_unpackhi_epi32`, `VPUNPCKHDQ`: in each 128-bit half, its high two
lanes of `a` and `b`, interleaved, `a`'s first. -/
def core.core_arch.x86.avx2._mm256_unpackhi_epi32 (a b : core.core_arch.x86.__m256i) :
    Result core.core_arch.x86.__m256i :=
  ok (ofLanes32 fun i => lane32 (if i % 2 = 0 then a else b) (i / 4 * 4 + 2 + i % 4 / 2))

/-- `_mm256_slli_epi32::<IMM8>`, `VPSLLD`: each 32-bit lane shifted left, or
zero for a shift past 31. -/
def core.core_arch.x86.avx2._mm256_slli_epi32 (IMM8 : Std.I32) (a : core.core_arch.x86.__m256i) :
    Result core.core_arch.x86.__m256i :=
  ok (ofLanes32 fun i => if imm8 IMM8 > 31 then 0 else lane32 a i <<< imm8 IMM8)

/-- `_mm256_slli_epi64::<IMM8>`, `VPSLLQ`: each 64-bit lane shifted left, or
zero for a shift past 63. -/
def core.core_arch.x86.avx2._mm256_slli_epi64 (IMM8 : Std.I32) (a : core.core_arch.x86.__m256i) :
    Result core.core_arch.x86.__m256i :=
  ok (ofLanes64 fun i => if imm8 IMM8 > 63 then 0 else lane64 a i <<< imm8 IMM8)

/-- `_mm256_srli_epi64::<IMM8>`, `VPSRLQ`: each 64-bit lane shifted right
logically, or zero for a shift past 63. -/
def core.core_arch.x86.avx2._mm256_srli_epi64 (IMM8 : Std.I32) (a : core.core_arch.x86.__m256i) :
    Result core.core_arch.x86.__m256i :=
  ok (ofLanes64 fun i => if imm8 IMM8 > 63 then 0 else lane64 a i >>> imm8 IMM8)

/-- `_mm256_srlv_epi32`, `VPSRLVD`: each 32-bit lane of `a` shifted right
logically by `b`'s, or zero for a shift past 31. -/
def core.core_arch.x86.avx2._mm256_srlv_epi32 (a b : core.core_arch.x86.__m256i) :
    Result core.core_arch.x86.__m256i :=
  ok (ofLanes32 fun i => if (lane32 b i).toNat > 31 then 0 else lane32 a i >>> (lane32 b i).toNat)
