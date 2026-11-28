module
public import Rind.X86_64.Funs
public import Rind.X86_64.MlKem.Types
@[expose] public section
open Aeneas Aeneas.Std Result
set_option linter.dupNamespace false

/-! The functions the x86_64 ML-KEM translation leaves opaque, which it
reaches as the target's translation and `Rind.X86_64.FunsExternal` define them,
in the namespace above its own: SHA-3, the constant-time markers, compare, and
wipes, the polynomial routines, and pyca/verified-garbage's ML-KEM-768. Here is
only the SHAKE padding byte, a constant the target reads as a value and this
translation, which leaves it opaque, as a computation. -/

namespace rind.x86_64.mlkem

/-- `sha3::SHAKE_PAD_BYTE`, the target's. -/
@[global_simps] def mid.sha3.SHAKE_PAD_BYTE : Result Std.U8 :=
  ok rind.x86_64.mid.sha3.SHAKE_PAD_BYTE

/-- Reading it gives the target's byte. -/
@[step] theorem mid.sha3.SHAKE_PAD_BYTE.spec :
    mid.sha3.SHAKE_PAD_BYTE ⦃ b => b = rind.x86_64.mid.sha3.SHAKE_PAD_BYTE ⦄ := by
  unfold mid.sha3.SHAKE_PAD_BYTE
  exact (WP.spec_ok _).2 rfl

end rind.x86_64.mlkem
