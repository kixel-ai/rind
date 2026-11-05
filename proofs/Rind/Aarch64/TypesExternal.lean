module
public import Aeneas
public import Rind.Core
public import Rind.Aarch64.DigestAlgorithm
@[expose] public section
open Aeneas Aeneas.Std Result
set_option linter.dupNamespace false

/-! The rind types the aarch64 translation leaves opaque. `Rind.Aarch64.Dispatch` and
`Rind.Aarch64.DigestDispatch` model the last four, and `Rind.Aarch64.DigestAlgorithm`
`Algorithm` and `Digest`. -/

namespace rind.aarch64

/-- The entry guard every operation holds, which changes no value. -/
opaque low.entry.Entry : Type

/-- The token proving the CPU has the SHA-512 instructions. -/
opaque low.aarch64.cpu.HaveSha3 : Type

/-- An AES key, whose header protection no proof covers. -/
opaque mid.aes.Aes : Type

/-- A SHA-3 context, whose sponge no proof covers. -/
opaque mid.sha3.Sha3Context (R : Std.Usize) (OUT : Std.Usize) : Type

/-- A `&'static T` that a wiped value may hold, as `Rind.Aarch64.Dispatch` models it:
the `T`, since only the drop that wipes it leaves it `None`. -/
@[reducible] def low.generic.zeroise.ZeroableRef (T : Type) : Type := T

/-- A curve's key agreement functions, as `Rind.Aarch64.Dispatch` models them:
nothing, since `Keyed::generate` builds the only one, of `K`'s own `Agree`
functions, which the model calls directly. -/
@[reducible] def high.agreement.Ops (_K : Type) : Type := Unit

/-- A header-protection key with its cipher's mask, as `Rind.Aarch64.Dispatch` models it:
the key, since `Masker::new` builds every one with `C`'s own `mask`, which the
model calls directly. -/
@[reducible] def aead.quic.Masker (C : Type) : Type := C

/-- A hash's context functions, as `Rind.Aarch64.DigestDispatch` models them:
nothing, since `Hashing::start` builds the only one, of `C`'s own
`HashContext` functions, which the model calls directly. -/
@[reducible] def high.digest.Ops (_C : Type) : Type := Unit

end rind.aarch64
