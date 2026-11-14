import Rind.Armv7.Funs
open Aeneas Aeneas.Std Result

/-! What armv7's theorems assume of the CPU, in place of the `Runs` that
`Rind.X86_64.S2nBignum` states with the x86_64 dispatch it also reads. -/

namespace rind.armv7

/-- rind runs on this CPU: its entry guard's CPU-feature check passes. It reads
no input. -/
def Runs : Prop :=
  ∃ e, low.entry.Entry.new_secret = ok e

@[step]
theorem new_secret_spec (h : Runs) : low.entry.Entry.new_secret ⦃ _ => True ⦄ := by
  obtain ⟨e, he⟩ := h
  simp [he]

end rind.armv7
