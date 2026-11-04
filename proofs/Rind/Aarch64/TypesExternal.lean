module
public import Aeneas
public import Rind.Core
@[expose] public section
open Aeneas Aeneas.Std Result
set_option linter.dupNamespace false

/-! The rind types the aarch64 translation leaves opaque. -/

namespace rind.aarch64

/-- The entry guard every operation holds, which changes no value. -/
axiom low.entry.Entry : Type

end rind.aarch64
