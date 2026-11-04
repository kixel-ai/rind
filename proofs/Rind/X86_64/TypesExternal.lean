module
public import Aeneas
public import Rind.Core
public import Rind.X86_64.Digest
@[expose] public section
open Aeneas Aeneas.Std Result
set_option linter.dupNamespace false

/-! The rind types the x86_64 translation leaves opaque, beside `Rind.X86_64.Digest`'s. `Rind.X86_64.Dispatch` models the last two. -/

namespace rind.x86_64

/-- The entry guard every operation holds, which changes no value. -/
opaque low.entry.Entry : Type

/-- The token proving the CPU has BMI2 and ADX. -/
opaque low.x86_64.cpu.HaveBmi2Adx : Type

/-- The tokens proving the CPU has what each SHA-256 routine needs. -/
opaque low.x86_64.cpu.HaveSha256 : Type
opaque low.x86_64.cpu.HaveAvx : Type
opaque low.x86_64.cpu.HaveAvx2 : Type
opaque low.x86_64.cpu.HaveSsse3 : Type

/-- A `&'static T` that a wiped value may hold, as `Rind.X86_64.Dispatch` models it:
the `T`, since only the drop that wipes it leaves it `None`. -/
@[reducible] def low.generic.zeroise.ZeroableRef (T : Type) : Type := T

/-- A curve's key agreement functions, as `Rind.X86_64.Dispatch` models them:
nothing, since `Keyed::generate` builds the only one, of `K`'s own `Agree`
functions, which the model calls directly. -/
@[reducible] def high.agreement.Ops (_K : Type) : Type := Unit

end rind.x86_64
