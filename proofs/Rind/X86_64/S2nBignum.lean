import Rind.X86_64.Funs
import Rind.Spec
import Rind.Ed25519
import Rind.Keccak
open Aeneas Aeneas.Std Result rind.spec

/-!
# s2n-bignum's contracts on x86_64

Each axiom restates one of s2n-bignum's HOL Light theorems, at the revision
rind transliterates (b4f17ee7), about the opaque Rust wrapper
`admin/parse-asm` generates around that routine. The theorem's preconditions
hold for every call from safe Rust: the `&mut` result cannot overlap an input
or the routine's code, and the routine's stack lies below the caller's
frame. Its total correctness (`ensures`) gives the `ok`.

The restatement, and that rind's inline assembly is s2n-bignum's object code
with the wrapper passing the arguments the theorem names, are trusted.
-/

namespace rind.x86_64

/-- `CURVE25519_X25519_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/x86/proofs/curve25519_x25519.ml#L8305 -/
@[step]
axiom curve25519_x25519_spec (res scalar point : Std.Array U64 4#usize) :
    low.x86_64.curve25519_x25519.curve25519_x25519 res scalar point ⦃ r =>
      wordsNat r.val = rfcx25519 (wordsNat scalar.val) (wordsNat point.val) ⦄

/-- `CURVE25519_X25519_ALT_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/x86/proofs/curve25519_x25519_alt.ml#L8524 -/
@[step]
axiom curve25519_x25519_alt_spec (res scalar point : Std.Array U64 4#usize) :
    low.x86_64.curve25519_x25519_alt.curve25519_x25519_alt res scalar point ⦃ r =>
      wordsNat r.val = rfcx25519 (wordsNat scalar.val) (wordsNat point.val) ⦄

/-- `CURVE25519_X25519BASE_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/x86/proofs/curve25519_x25519base.ml#L5099 -/
@[step]
axiom curve25519_x25519base_spec (res scalar : Std.Array U64 4#usize) :
    low.x86_64.curve25519_x25519base.curve25519_x25519base res scalar ⦃ r =>
      wordsNat r.val = rfcx25519 (wordsNat scalar.val) 9 ⦄

/-- `CURVE25519_X25519BASE_ALT_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/x86/proofs/curve25519_x25519base_alt.ml#L5197 -/
@[step]
axiom curve25519_x25519base_alt_spec (res scalar : Std.Array U64 4#usize) :
    low.x86_64.curve25519_x25519base_alt.curve25519_x25519base_alt res scalar ⦃ r =>
      wordsNat r.val = rfcx25519 (wordsNat scalar.val) 9 ⦄

/-- `BIGNUM_EQ_SUBROUTINE_CORRECT`, whose 1 or 0 the wrapper returns as
`true` or `false`,
https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/x86/proofs/bignum_eq.ml#L294 -/
@[step]
axiom bignum_eq_spec (x y : Slice U64) :
    low.x86_64.bignum_eq.bignum_eq x y ⦃ b => b = decide (wordsNat x.val = wordsNat y.val) ⦄

/-! ### Ed25519 -/

/-- `EDWARDS25519_DECODE_SUBROUTINE_CORRECT`, whose 0 for a valid
encoding the wrapper returns as `true`,
https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/x86/proofs/edwards25519_decode.ml#L2128 -/
@[step]
axiom edwards25519_decode_spec (z : Std.Array U64 8#usize) (c : Std.Array U8 32#usize) :
    low.x86_64.edwards25519_decode.edwards25519_decode z c ⦃ r =>
      (r.1 = true ↔ edValidEncode (leNat c.val)) ∧
        (edValidEncode (leNat c.val) → pairNat r.2.val = edModEncodePair (edDecode (leNat c.val))) ⦄

/-- `EDWARDS25519_SCALARMULBASE_SUBROUTINE_CORRECT`, whose `tables`
preconditions hold because rind links s2n-bignum's constant table, which the
routine addresses PC-relative,
https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/x86/proofs/edwards25519_scalarmulbase.ml#L5312 -/
@[step]
axiom edwards25519_scalarmulbase_spec (res : Std.Array U64 8#usize)
    (scalar : Std.Array U64 4#usize) :
    low.x86_64.edwards25519_scalarmulbase.edwards25519_scalarmulbase res scalar ⦃ r =>
      pairNat r.val = edModEncodePair (edPow edB (wordsNat scalar.val)) ⦄

/-- `EDWARDS25519_SCALARMULDOUBLE_SUBROUTINE_CORRECT`, whose `tables`
preconditions hold because rind links s2n-bignum's constant table, which the
routine addresses PC-relative,
https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/x86/proofs/edwards25519_scalarmuldouble.ml#L11800 -/
@[step]
axiom edwards25519_scalarmuldouble_spec (res : Std.Array U64 8#usize)
    (scalar : Std.Array U64 4#usize) (point : Std.Array U64 8#usize)
    (bscalar : Std.Array U64 4#usize) :
    low.x86_64.edwards25519_scalarmuldouble.edwards25519_scalarmuldouble res scalar point
      bscalar ⦃ r =>
      ∀ P, edOnCurve P → edModDecodePair (pairNat point.val) = P →
        pairNat r.val =
          edModEncodePair (edMul (edPow P (wordsNat scalar.val)) (edPow edB (wordsNat bscalar.val))) ⦄

/-- `BIGNUM_MADD_N25519_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/x86/proofs/bignum_madd_n25519.ml#L964 -/
@[step]
axiom bignum_madd_n25519_spec (z x y c : Std.Array U64 4#usize) :
    low.x86_64.bignum_madd_n25519.bignum_madd_n25519 z x y c ⦃ r =>
      wordsNat r.val = (wordsNat x.val * wordsNat y.val + wordsNat c.val) % n25519 ⦄

/-- `EDWARDS25519_DECODE_ALT_SUBROUTINE_CORRECT`, whose 0 for a valid
encoding the wrapper returns as `true`,
https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/x86/proofs/edwards25519_decode_alt.ml#L2071 -/
@[step]
axiom edwards25519_decode_alt_spec (z : Std.Array U64 8#usize) (c : Std.Array U8 32#usize) :
    low.x86_64.edwards25519_decode_alt.edwards25519_decode_alt z c ⦃ r =>
      (r.1 = true ↔ edValidEncode (leNat c.val)) ∧
        (edValidEncode (leNat c.val) → pairNat r.2.val = edModEncodePair (edDecode (leNat c.val))) ⦄

/-- `EDWARDS25519_SCALARMULBASE_ALT_SUBROUTINE_CORRECT`, whose `tables`
preconditions hold because rind links s2n-bignum's constant table, which the
routine addresses PC-relative,
https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/x86/proofs/edwards25519_scalarmulbase_alt.ml#L5418 -/
@[step]
axiom edwards25519_scalarmulbase_alt_spec (res : Std.Array U64 8#usize)
    (scalar : Std.Array U64 4#usize) :
    low.x86_64.edwards25519_scalarmulbase_alt.edwards25519_scalarmulbase_alt res scalar ⦃ r =>
      pairNat r.val = edModEncodePair (edPow edB (wordsNat scalar.val)) ⦄

/-- `EDWARDS25519_SCALARMULDOUBLE_ALT_SUBROUTINE_CORRECT`, whose `tables`
preconditions hold because rind links s2n-bignum's constant table, which the
routine addresses PC-relative,
https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/x86/proofs/edwards25519_scalarmuldouble_alt.ml#L11872 -/
@[step]
axiom edwards25519_scalarmuldouble_alt_spec (res : Std.Array U64 8#usize)
    (scalar : Std.Array U64 4#usize) (point : Std.Array U64 8#usize)
    (bscalar : Std.Array U64 4#usize) :
    low.x86_64.edwards25519_scalarmuldouble_alt.edwards25519_scalarmuldouble_alt res scalar point
      bscalar ⦃ r =>
      ∀ P, edOnCurve P → edModDecodePair (pairNat point.val) = P →
        pairNat r.val =
          edModEncodePair (edMul (edPow P (wordsNat scalar.val)) (edPow edB (wordsNat bscalar.val))) ⦄

/-- `BIGNUM_MADD_N25519_ALT_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/x86/proofs/bignum_madd_n25519_alt.ml#L939 -/
@[step]
axiom bignum_madd_n25519_alt_spec (z x y c : Std.Array U64 4#usize) :
    low.x86_64.bignum_madd_n25519_alt.bignum_madd_n25519_alt z x y c ⦃ r =>
      wordsNat r.val = (wordsNat x.val * wordsNat y.val + wordsNat c.val) % n25519 ⦄

/-- `BIGNUM_MOD_N25519_SUBROUTINE_CORRECT`, for the slice's length as `k`,
https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/x86/proofs/bignum_mod_n25519.ml#L498 -/
@[step]
axiom bignum_mod_n25519_spec (z : Std.Array U64 4#usize) (x : Slice U64) :
    low.x86_64.bignum_mod_n25519.bignum_mod_n25519 z x ⦃ r =>
      wordsNat r.val = wordsNat x.val % n25519 ⦄

/-- `BIGNUM_NEG_P25519_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/x86/proofs/bignum_neg_p25519.ml#L120 -/
@[step]
axiom bignum_neg_p25519_spec (z x : Std.Array U64 4#usize) :
    low.x86_64.bignum_neg_p25519.bignum_neg_p25519 z x ⦃ r =>
      wordsNat x.val ≤ p25519 → wordsNat r.val = (p25519 - wordsNat x.val) % p25519 ⦄

/-- `BIGNUM_LT_SUBROUTINE_CORRECT`, for the slices' lengths as `m` and `n`,
https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/x86/proofs/bignum_lt.ml#L412 -/
@[step]
axiom bignum_cmp_lt_spec (x y : Slice U64) :
    low.x86_64.bignum_cmp_lt.bignum_cmp_lt x y ⦃ r =>
      r.val = if wordsNat x.val < wordsNat y.val then 1 else 0 ⦄

/-! ### Keccak-f[1600]

Each routine permutes the 25-lane states it is given in place, for the round
constants, and the four-way one's byte-shuffle constants, that rind passes. -/

/-- `SHA3_KECCAK_F1600_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/x86/proofs/sha3_keccak_f1600.ml#L736 -/
axiom sha3_keccak_f1600_spec (a : Std.Array U64 25#usize) (rc : Std.Array U64 24#usize)
    (hrc : rc.val.map (·.bv) = keccakRoundConstants) :
    low.x86_64.sha3_keccak_f1600.sha3_keccak_f1600 a rc ⦃ r =>
      r.val.map (·.bv) = keccak 24 (a.val.map (·.bv)) ⦄

/-- `SHA3_KECCAK4_F1600_ALT_SUBROUTINE_CORRECT`, whose four states are
consecutive, as an array of them is,
https://github.com/awslabs/s2n-bignum/blob/b4f17ee743ebc9b53a26c3cd1908f50f0658314f/x86/proofs/sha3_keccak4_f1600_alt.ml#L1081 -/
axiom sha3_keccak4_f1600_alt_spec (a : Std.Array (Std.Array U64 25#usize) 4#usize)
    (rc : Std.Array U64 24#usize) (rho8 rho56 : Std.Array U64 4#usize)
    (hrc : rc.val.map (·.bv) = keccakRoundConstants) (h8 : rho8.val.map (·.bv) = keccakRho8)
    (h56 : rho56.val.map (·.bv) = keccakRho56) :
    low.x86_64.sha3_keccak4_f1600_alt.sha3_keccak4_f1600 a rc rho8 rho56 ⦃ r =>
      r.val.map (·.val.map (·.bv)) = (a.val.map (·.val.map (·.bv))).map (keccak 24) ⦄

/-- rind runs on this CPU: its entry guards' CPU-feature checks pass, and its
BMI2/ADX dispatch reads the CPU. None reads an input. -/
def Runs : Prop :=
  (∃ e, low.entry.Entry.new_secret = ok e) ∧ (∃ e, low.entry.Entry.new_public = ok e) ∧
    ∃ t, low.x86_64.cpu.HaveBmi2Adx.check = ok t

/-- Ed25519 verification's double scalar multiplication runs one of
s2n-bignum's routines: a CPU without ADX lacks AVX2 too, since with it rind
runs a port of curve25519-dalek's AVX2 backend, which nothing proves. -/
def RunsDouble : Prop :=
  low.x86_64.cpu.HaveBmi2Adx.check = ok none → low.x86_64.cpu.HaveAvx2.check = ok none

@[step]
theorem new_secret_spec (h : Runs) : low.entry.Entry.new_secret ⦃ _ => True ⦄ := by
  obtain ⟨⟨e, he⟩, -⟩ := h
  simp [he]

@[step]
theorem new_public_spec (h : Runs) : low.entry.Entry.new_public ⦃ _ => True ⦄ := by
  obtain ⟨-, ⟨e, he⟩, -⟩ := h
  simp [he]

/-- The dispatch runs one of the twins, whose contracts agree. -/
@[step]
theorem curve25519_x25519_mux_spec (h : Runs) (res scalar point : Std.Array U64 4#usize) :
    low.x86_64.adx_mux.curve25519_x25519 res scalar point ⦃ r =>
      wordsNat r.val = rfcx25519 (wordsNat scalar.val) (wordsNat point.val) ⦄ := by
  obtain ⟨-, -, t, ht⟩ := h
  unfold low.x86_64.adx_mux.curve25519_x25519
  rw [ht]
  cases t <;> step*

@[step]
theorem curve25519_x25519base_mux_spec (h : Runs) (res scalar : Std.Array U64 4#usize) :
    low.x86_64.adx_mux.curve25519_x25519base res scalar ⦃ r =>
      wordsNat r.val = rfcx25519 (wordsNat scalar.val) 9 ⦄ := by
  obtain ⟨-, -, t, ht⟩ := h
  unfold low.x86_64.adx_mux.curve25519_x25519base
  rw [ht]
  cases t <;> step*

@[step]
theorem edwards25519_decode_mux_spec (h : Runs) (z : Std.Array U64 8#usize)
    (c : Std.Array U8 32#usize) :
    low.x86_64.adx_mux.edwards25519_decode z c ⦃ r =>
      (r.1 = true ↔ edValidEncode (leNat c.val)) ∧
        (edValidEncode (leNat c.val) → pairNat r.2.val = edModEncodePair (edDecode (leNat c.val))) ⦄ := by
  obtain ⟨-, -, t, ht⟩ := h
  unfold low.x86_64.adx_mux.edwards25519_decode
  rw [ht]
  cases t <;> step*

@[step]
theorem edwards25519_scalarmulbase_mux_spec (h : Runs) (res : Std.Array U64 8#usize)
    (scalar : Std.Array U64 4#usize) :
    low.x86_64.adx_mux.edwards25519_scalarmulbase res scalar ⦃ r =>
      pairNat r.val = edModEncodePair (edPow edB (wordsNat scalar.val)) ⦄ := by
  obtain ⟨-, -, t, ht⟩ := h
  unfold low.x86_64.adx_mux.edwards25519_scalarmulbase
  rw [ht]
  cases t <;> step*

@[step]
theorem edwards25519_scalarmuldouble_mux_spec (h : Runs) (hd : RunsDouble)
    (res : Std.Array U64 8#usize) (scalar : Std.Array U64 4#usize)
    (point : Std.Array U64 8#usize) (bscalar : Std.Array U64 4#usize) :
    low.x86_64.adx_mux.edwards25519_scalarmuldouble res scalar point bscalar ⦃ r =>
      ∀ P, edOnCurve P → edModDecodePair (pairNat point.val) = P →
        pairNat r.val =
          edModEncodePair (edMul (edPow P (wordsNat scalar.val)) (edPow edB (wordsNat bscalar.val))) ⦄ := by
  obtain ⟨-, -, t, ht⟩ := h
  unfold low.x86_64.adx_mux.edwards25519_scalarmuldouble
  rw [ht]
  cases t
  · rw [hd ht]
    step*
  · step*

@[step]
theorem bignum_madd_n25519_mux_spec (h : Runs) (z x y c : Std.Array U64 4#usize) :
    low.x86_64.adx_mux.bignum_madd_n25519 z x y c ⦃ r =>
      wordsNat r.val = (wordsNat x.val * wordsNat y.val + wordsNat c.val) % n25519 ⦄ := by
  obtain ⟨-, -, t, ht⟩ := h
  unfold low.x86_64.adx_mux.bignum_madd_n25519
  rw [ht]
  cases t <;> step*

end rind.x86_64
