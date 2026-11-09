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

/-- A value its owner builds once and keeps, whose atomics Aeneas cannot
translate. -/
opaque low.generic.reuse_cache.ReuseCache (T : Type) : Type

/-- The HMAC-DRBG an ECDSA signature draws its nonces from, whose output the
functional spec leaves out. -/
opaque high.hmac_drbg.HmacDrbg (H : Type _) (Clause0_Context : Type _) (Clause0_State : Type _) : Type

/-- An AES key, whose header protection no proof covers. -/
opaque mid.aes.Aes : Type

/-- MD5's chaining state, which no proof covers. -/
opaque mid.md5.Md5State : Type

/-- An MD5 context, which no proof covers. -/
opaque mid.md5.Md5Context : Type

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
