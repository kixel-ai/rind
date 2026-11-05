import Rind.Aarch64.Funs
import Rind.Spec
import Rind.Ed25519
open Aeneas Aeneas.Std Result rind.spec

/-!
# s2n-bignum's contracts on aarch64

Each axiom restates one of s2n-bignum's HOL Light theorems, at the revision
rind transliterates (9f2cd960), about the opaque Rust wrapper
`admin/parse-asm` generates around that routine. rind's aarch64 X25519 runs
the `_alt` sources under the plain names, and so does its Ed25519 for the
scalar multiplications, decoding, and `bignum_madd_n25519`. The theorem's preconditions hold
for every call from safe Rust: the `&mut` result cannot overlap an input or
the routine's code or table, the routine's stack lies below the caller's
frame, and the ABI keeps the stack pointer 16-byte aligned. Its total correctness
(`ensures`) gives the `ok`.

The restatement, and that rind's inline assembly is s2n-bignum's object code
and constant table with the wrapper passing the arguments the theorem names,
are trusted.
-/

namespace rind.aarch64

/-- `CURVE25519_X25519_ALT_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/curve25519_x25519_alt.ml#L5349 -/
@[step]
axiom curve25519_x25519_spec (res scalar point : Std.Array U64 4#usize) :
    low.aarch64.curve25519_x25519.curve25519_x25519 res scalar point ⦃ r =>
      wordsNat r.val = rfcx25519 (wordsNat scalar.val) (wordsNat point.val) ⦄

/-- `CURVE25519_X25519BASE_ALT_SUBROUTINE_CORRECT`, whose `tables`
precondition holds because rind's copy of the constant table is s2n-bignum's,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/curve25519_x25519base_alt.ml#L3700 -/
@[step]
axiom curve25519_x25519base_spec (res scalar : Std.Array U64 4#usize) :
    low.aarch64.curve25519_x25519base.curve25519_x25519base res scalar ⦃ r =>
      wordsNat r.val = rfcx25519 (wordsNat scalar.val) 9 ⦄

/-- `BIGNUM_EQ_SUBROUTINE_CORRECT`, whose 1 or 0 the wrapper returns as
`true` or `false`,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/bignum_eq.ml#L269 -/
@[step]
axiom bignum_eq_spec (x y : Slice U64) :
    low.aarch64.bignum_eq.bignum_eq x y ⦃ b => b = decide (wordsNat x.val = wordsNat y.val) ⦄

/-! ### Ed25519 -/

/-- `EDWARDS25519_DECODE_ALT_SUBROUTINE_CORRECT`, whose 0 for a valid
encoding the wrapper returns as `true`,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/edwards25519_decode_alt.ml#L1703 -/
@[step]
axiom edwards25519_decode_spec (z : Std.Array U64 8#usize) (c : Std.Array U8 32#usize) :
    low.aarch64.edwards25519_decode.edwards25519_decode z c ⦃ r =>
      (r.1 = true ↔ edValidEncode (leNat c.val)) ∧
        (edValidEncode (leNat c.val) → pairNat r.2.val = edModEncodePair (edDecode (leNat c.val))) ⦄

/-- `EDWARDS25519_SCALARMULBASE_ALT_SUBROUTINE_CORRECT`, whose `tables`
preconditions hold because rind links s2n-bignum's constant table, which the
routine addresses PC-relative,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/edwards25519_scalarmulbase_alt.ml#L3870 -/
@[step]
axiom edwards25519_scalarmulbase_spec (res : Std.Array U64 8#usize)
    (scalar : Std.Array U64 4#usize) :
    low.aarch64.edwards25519_scalarmulbase.edwards25519_scalarmulbase res scalar ⦃ r =>
      pairNat r.val = edModEncodePair (edPow edB (wordsNat scalar.val)) ⦄

/-- `EDWARDS25519_SCALARMULDOUBLE_ALT_SUBROUTINE_CORRECT`, whose `tables`
preconditions hold because rind links s2n-bignum's constant table, which the
routine addresses PC-relative,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/edwards25519_scalarmuldouble_alt.ml#L8432 -/
@[step]
axiom edwards25519_scalarmuldouble_spec (res : Std.Array U64 8#usize)
    (scalar : Std.Array U64 4#usize) (point : Std.Array U64 8#usize)
    (bscalar : Std.Array U64 4#usize) :
    low.aarch64.edwards25519_scalarmuldouble.edwards25519_scalarmuldouble res scalar point
      bscalar ⦃ r =>
      ∀ P, edOnCurve P → edModDecodePair (pairNat point.val) = P →
        pairNat r.val =
          edModEncodePair (edMul (edPow P (wordsNat scalar.val)) (edPow edB (wordsNat bscalar.val))) ⦄

/-- `BIGNUM_MADD_N25519_ALT_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/bignum_madd_n25519_alt.ml#L829 -/
@[step]
axiom bignum_madd_n25519_spec (z x y c : Std.Array U64 4#usize) :
    low.aarch64.bignum_madd_n25519.bignum_madd_n25519 z x y c ⦃ r =>
      wordsNat r.val = (wordsNat x.val * wordsNat y.val + wordsNat c.val) % n25519 ⦄

/-- `BIGNUM_MOD_N25519_SUBROUTINE_CORRECT`, for the slice's length as `k`,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/bignum_mod_n25519.ml#L434 -/
@[step]
axiom bignum_mod_n25519_spec (z : Std.Array U64 4#usize) (x : Slice U64) :
    low.aarch64.bignum_mod_n25519.bignum_mod_n25519 z x ⦃ r =>
      wordsNat r.val = wordsNat x.val % n25519 ⦄

/-- `BIGNUM_NEG_P25519_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/bignum_neg_p25519.ml#L90 -/
@[step]
axiom bignum_neg_p25519_spec (z x : Std.Array U64 4#usize) :
    low.aarch64.bignum_neg_p25519.bignum_neg_p25519 z x ⦃ r =>
      wordsNat x.val ≤ p25519 → wordsNat r.val = (p25519 - wordsNat x.val) % p25519 ⦄

/-- `BIGNUM_LT_SUBROUTINE_CORRECT`, for the slices' lengths as `m` and `n`,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/bignum_lt.ml#L346 -/
@[step]
axiom bignum_cmp_lt_spec (x y : Slice U64) :
    low.aarch64.bignum_cmp_lt.bignum_cmp_lt x y ⦃ r =>
      r.val = if wordsNat x.val < wordsNat y.val then 1 else 0 ⦄

/-! ### P-256

rind's aarch64 P-256 runs the `_alt` scalar multiplications under the plain
names, and the other routines' plain sources. -/

/-- HOL Light's `inverse_mod p_256 (2 EXP 256)`: the number below `p256`
that 2²⁵⁶ times is 1 mod `p256`, which `p256RInv_spec` checks, and which is
unique since `p256` is odd. -/
def p256RInv : Nat :=
  115792089183396302114378112356516095823261736990586219612555396166510339686400

theorem p256RInv_spec : p256RInv < p256 ∧ 2 ^ 256 * p256RInv % p256 = 1 := by
  simp only [p256RInv, p256]; decide

/-- `affinepoint_p256 xy P`: `P` is the point whose coordinates are `xy`'s,
reduced mod `p256` (`modular_decode`),
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/p256_scalarmul_alt.ml#L6433 -/
def p256Affine (xy : Nat × Nat) (P : P256Point) : Prop :=
  P = some (xy.1 % p256, xy.2 % p256)

/-- `affinepointz_p256 xy P`: as `p256Affine`, except that (0, 0) is the point
at infinity,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/p256_scalarmul_alt.ml#L6437 -/
def p256AffineZ (xy : Nat × Nat) (P : P256Point) : Prop :=
  if xy.1 = 0 ∧ xy.2 = 0 then P = none else P = some (xy.1 % p256, xy.2 % p256)

/-- `represents2_p256 P xy`: `xy` are `P`'s coordinates in Montgomery form
(`montgomery_decode`), each below `p256`,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/p256_montjmixadd_alt.ml#L1951 -/
def p256Represents2 (P : P256Point) (xy : Nat × Nat) : Prop :=
  xy.1 < p256 ∧ xy.2 < p256 ∧ some (p256RInv * xy.1 % p256, p256RInv * xy.2 % p256) = P

/-- `p256_tabulates P 6 tab len tabulation`, for the table rind passes: entry
`j` of row `i`, counting entries from 1, represents `P` times 2⁶ⁱ·j. Its length
condition, (256 / 6 + 1) · 2⁵ · 64 ≤ len, is the type's 43 rows of 256 words,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/p256_scalarmulbase_alt.ml#L3063 -/
def p256Tabulates (P : P256Point) (table : Std.Array (Std.Array U64 256#usize) 43#usize) : Prop :=
  ∀ i < 43, ∀ j, 1 ≤ j → j ≤ 32 →
    p256Represents2 (p256Pow P (2 ^ (6 * i) * j)) (pairNat ((table.val[i]!).val.drop (8 * (j - 1))))

/-- `BIGNUM_TOMONT_P256_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/bignum_tomont_p256.ml#L415 -/
@[step]
axiom bignum_tomont_p256_spec (z x : Std.Array U64 4#usize) :
    low.aarch64.bignum_tomont_p256.bignum_tomont_p256 z x ⦃ r =>
      wordsNat r.val = 2 ^ 256 * wordsNat x.val % p256 ⦄

/-- `BIGNUM_DEMONT_P256_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/bignum_demont_p256.ml#L117 -/
@[step]
axiom bignum_demont_p256_spec (z x : Std.Array U64 4#usize) :
    low.aarch64.bignum_demont_p256.bignum_demont_p256 z x ⦃ r =>
      wordsNat x.val < p256 → wordsNat r.val = p256RInv * wordsNat x.val % p256 ⦄

/-- `BIGNUM_ADD_P256_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/bignum_add_p256.ml#L107 -/
@[step]
axiom bignum_add_p256_spec (z x y : Std.Array U64 4#usize) :
    low.aarch64.bignum_add_p256.bignum_add_p256 z x y ⦃ r =>
      wordsNat x.val < p256 → wordsNat y.val < p256 →
        wordsNat r.val = (wordsNat x.val + wordsNat y.val) % p256 ⦄

/-- `BIGNUM_MONTMUL_P256_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/bignum_montmul_p256.ml#L1753 -/
@[step]
axiom bignum_montmul_p256_spec (z x y : Std.Array U64 4#usize) :
    low.aarch64.bignum_montmul_p256.bignum_montmul_p256 z x y ⦃ r =>
      wordsNat x.val * wordsNat y.val ≤ 2 ^ 256 * p256 →
        wordsNat r.val = p256RInv * wordsNat x.val * wordsNat y.val % p256 ⦄

/-- `BIGNUM_MONTSQR_P256_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/bignum_montsqr_p256.ml#L1231 -/
@[step]
axiom bignum_montsqr_p256_spec (z x : Std.Array U64 4#usize) :
    low.aarch64.bignum_montsqr_p256.bignum_montsqr_p256 z x ⦃ r =>
      wordsNat x.val ^ 2 ≤ 2 ^ 256 * p256 →
        wordsNat r.val = p256RInv * wordsNat x.val ^ 2 % p256 ⦄

/-- `BIGNUM_MOD_N256_4_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/bignum_mod_n256_4.ml#L110 -/
@[step]
axiom bignum_mod_n256_spec (z x : Std.Array U64 4#usize) :
    low.aarch64.bignum_mod_n256.bignum_mod_n256 z x ⦃ r =>
      wordsNat r.val = wordsNat x.val % n256 ⦄

/-- `P256_SCALARMUL_ALT_SUBROUTINE_CORRECT`, whose stack frame is 1248 bytes,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/p256_scalarmul_alt.ml#L7459 -/
@[step]
axiom p256_scalarmul_spec (res : Std.Array U64 8#usize) (scalar : Std.Array U64 4#usize)
    (point : Std.Array U64 8#usize) :
    low.aarch64.p256_scalarmul.p256_scalarmul res scalar point ⦃ r =>
      ∀ P, p256OnCurve P → p256Affine (pairNat point.val) P →
        p256AffineZ (pairNat r.val) (p256Pow P (wordsNat scalar.val)) ⦄

/-- `P256_SCALARMULBASE_ALT_SUBROUTINE_CORRECT`, with the block size 6 the
wrapper passes and a table it reads but cannot overlap,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/arm/proofs/p256_scalarmulbase_alt.ml#L4059 -/
@[step]
axiom p256_scalarmulbase_spec (res : Std.Array U64 8#usize) (scalar : Std.Array U64 4#usize)
    (table : Std.Array (Std.Array U64 256#usize) 43#usize) :
    low.aarch64.p256_scalarmulbase.p256_scalarmulbase res scalar table ⦃ r =>
      ∀ P, p256OnCurve P → p256Tabulates P table →
        p256AffineZ (pairNat r.val) (p256Pow P (wordsNat scalar.val)) ⦄

/-- rind runs on this CPU: its entry guards' CPU-feature checks pass. Neither
reads an input. -/
def Runs : Prop :=
  (∃ e, low.entry.Entry.new_secret = ok e) ∧ (∃ e, low.entry.Entry.new_public = ok e)

@[step]
theorem new_secret_spec (h : Runs) : low.entry.Entry.new_secret ⦃ _ => True ⦄ := by
  obtain ⟨⟨e, he⟩, -⟩ := h
  simp [he]

@[step]
theorem new_public_spec (h : Runs) : low.entry.Entry.new_public ⦃ _ => True ⦄ := by
  obtain ⟨-, ⟨e, he⟩⟩ := h
  simp [he]

end rind.aarch64
