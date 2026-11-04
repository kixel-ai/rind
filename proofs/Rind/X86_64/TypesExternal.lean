module
public import Aeneas
public import Rind.Core
@[expose] public section
open Aeneas Aeneas.Std Result
set_option linter.dupNamespace false

/-! The rind types the x86_64 translation leaves opaque. -/

namespace rind.x86_64

/-- The entry guard every operation holds, which changes no value. -/
opaque low.entry.Entry : Type

/-- The token proving the CPU has BMI2 and ADX. -/
opaque low.x86_64.cpu.HaveBmi2Adx : Type

end rind.x86_64
