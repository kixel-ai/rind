import Rind.Aarch64.Funs
import Rind.Spec
open Aeneas Aeneas.Std Result rind.spec

/-!
# s2n-bignum's contracts on aarch64

Each axiom restates one of s2n-bignum's HOL Light theorems, at the revision
rind transliterates (9f2cd960), about the opaque Rust wrapper
`admin/parse-asm` generates around that routine. rind's aarch64 X25519 runs
the `_alt` sources under the plain names. The theorem's preconditions hold
for every call from safe Rust: the `&mut` result cannot overlap an input or
the routine's code, the routine's stack lies below the caller's frame, and
the ABI keeps the stack pointer 16-byte aligned. Its total correctness
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
