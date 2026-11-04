module
public import Aeneas
public import Rind.Core
@[expose] public section
open Aeneas Aeneas.Std Result
set_option linter.dupNamespace false

/-! The rind types the aarch64 translation leaves opaque. -/

namespace rind.aarch64

/-- The entry guard every operation holds, which changes no value. -/
opaque low.entry.Entry : Type

/-- A key agreement algorithm, which holds its curve's code as a function pointer. -/
opaque high.agreement.Algorithm : Type

/-- A curve's key agreement functions, as function pointers. -/
opaque high.agreement.Ops (K : Type) : Type

/-- A `&'static T` that a wiped value may hold. -/
opaque low.generic.zeroise.ZeroableRef (T : Type) : Type

end rind.aarch64
