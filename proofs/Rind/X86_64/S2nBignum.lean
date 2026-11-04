import Rind.X86_64.Funs
import Rind.Spec
open Aeneas Aeneas.Std Result rind.spec

/-!
# s2n-bignum's contracts on x86_64

Each axiom restates one of s2n-bignum's HOL Light theorems, at the revision
rind transliterates (9f2cd960), about the opaque Rust wrapper
`admin/parse-asm` generates around that routine. The theorem's preconditions
hold for every call from safe Rust: the `&mut` result cannot overlap an input
or the routine's code, and the routine's stack lies below the caller's
frame. Its total correctness (`ensures`) gives the `ok`.

The restatement, and that rind's inline assembly is s2n-bignum's object code
with the wrapper passing the arguments the theorem names, are trusted.
-/

namespace rind.x86_64

/-- `CURVE25519_X25519_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/x86/proofs/curve25519_x25519.ml#L8305 -/
@[step]
axiom curve25519_x25519_spec (res scalar point : Std.Array U64 4#usize) :
    low.x86_64.curve25519_x25519.curve25519_x25519 res scalar point ⦃ r =>
      wordsNat r.val = rfcx25519 (wordsNat scalar.val) (wordsNat point.val) ⦄

/-- `CURVE25519_X25519_ALT_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/x86/proofs/curve25519_x25519_alt.ml#L8524 -/
@[step]
axiom curve25519_x25519_alt_spec (res scalar point : Std.Array U64 4#usize) :
    low.x86_64.curve25519_x25519_alt.curve25519_x25519_alt res scalar point ⦃ r =>
      wordsNat r.val = rfcx25519 (wordsNat scalar.val) (wordsNat point.val) ⦄

/-- `CURVE25519_X25519BASE_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/x86/proofs/curve25519_x25519base.ml#L5099 -/
@[step]
axiom curve25519_x25519base_spec (res scalar : Std.Array U64 4#usize) :
    low.x86_64.curve25519_x25519base.curve25519_x25519base res scalar ⦃ r =>
      wordsNat r.val = rfcx25519 (wordsNat scalar.val) 9 ⦄

/-- `CURVE25519_X25519BASE_ALT_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/x86/proofs/curve25519_x25519base_alt.ml#L5197 -/
@[step]
axiom curve25519_x25519base_alt_spec (res scalar : Std.Array U64 4#usize) :
    low.x86_64.curve25519_x25519base_alt.curve25519_x25519base_alt res scalar ⦃ r =>
      wordsNat r.val = rfcx25519 (wordsNat scalar.val) 9 ⦄

/-- `BIGNUM_EQ_SUBROUTINE_CORRECT`, whose 1 or 0 the wrapper returns as
`true` or `false`,
https://github.com/awslabs/s2n-bignum/blob/9f2cd960e11892a582e7facb0c191b4a2959ea91/x86/proofs/bignum_eq.ml#L294 -/
@[step]
axiom bignum_eq_spec (x y : Slice U64) :
    low.x86_64.bignum_eq.bignum_eq x y ⦃ b => b = decide (wordsNat x.val = wordsNat y.val) ⦄

/-- rind runs on this CPU: its entry guards' CPU-feature checks pass, and its
BMI2/ADX dispatch reads the CPU. None reads an input. -/
def Runs : Prop :=
  (∃ e, low.entry.Entry.new_secret = ok e) ∧ (∃ e, low.entry.Entry.new_public = ok e) ∧
    ∃ t, low.x86_64.cpu.HaveBmi2Adx.check = ok t

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

end rind.x86_64
