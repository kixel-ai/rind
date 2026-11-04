module
public import Aeneas
public import Rind.Core
@[expose] public section
open Aeneas Aeneas.Std Result
set_option linter.dupNamespace false

/-! The rind types the aarch64 translation leaves opaque. `Rind.Aarch64.Dispatch` models the last two. -/

namespace rind.aarch64

/-- The entry guard every operation holds, which changes no value. -/
opaque low.entry.Entry : Type

/-- A `&'static T` that a wiped value may hold, as `Rind.Aarch64.Dispatch` models it:
the `T`, since only the drop that wipes it leaves it `None`. -/
@[reducible] def low.generic.zeroise.ZeroableRef (T : Type) : Type := T

/-- A curve's key agreement functions, as `Rind.Aarch64.Dispatch` models them:
nothing, since `Keyed::generate` builds the only one, of `K`'s own `Agree`
functions, which the model calls directly. -/
@[reducible] def high.agreement.Ops (_K : Type) : Type := Unit

end rind.aarch64
