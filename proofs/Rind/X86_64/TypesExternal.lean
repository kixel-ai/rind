module
public import Aeneas
public import Rind.Core
public import Rind.X86_64.DigestAlgorithm
public import Rind.X86_64.Simd
@[expose] public section
open Aeneas Aeneas.Std Result
set_option linter.dupNamespace false

/-! The rind types the x86_64 translation leaves opaque. `Rind.X86_64.Dispatch`,
`Rind.X86_64.DigestDispatch`, and `Rind.X86_64.AeadDispatch` model the last five,
`Rind.X86_64.DigestAlgorithm` `Algorithm` and `Digest`, and `Rind.X86_64.Simd`
`__m128i`. -/

namespace rind.x86_64

/-- The entry guard every operation holds, which changes no value. -/
opaque low.entry.Entry : Type

/-- The token proving the CPU has BMI2 and ADX. -/
opaque low.x86_64.cpu.HaveBmi2Adx : Type

/-- The tokens proving the CPU has what each SHA-256 routine needs: the SHA
extensions, AVX and SSSE3, AVX2, and SSSE3. -/
opaque low.x86_64.cpu.HaveSha256 : Type
opaque low.x86_64.cpu.HaveAvx : Type
opaque low.x86_64.cpu.HaveAvx2 : Type
opaque low.x86_64.cpu.HaveSsse3 : Type

/-- An AES key, whose header protection no proof covers. -/
opaque mid.aes.Aes : Type

/-- A SHA-3 context, whose sponge no proof covers. -/
opaque mid.sha3.Sha3Context (R : Std.Usize) (OUT : Std.Usize) : Type

/-- The token proving the CPU has AES-NI, PCLMULQDQ, SSSE3, and SSE4.1. -/
opaque low.x86_64.cpu.HaveAesHardware : Type

/-- The token proving the CPU has AVX and MOVBE besides `HaveAesHardware`'s,
which Vale's AES-GCM needs. -/
opaque low.x86_64.cpu.HaveAvxMovbeForAesGcm : Type

/-- The token proving the CPU has VAES and VPCLMULQDQ for AES-GCM. -/
opaque low.x86_64.cpu.HaveVaesAvx2ForAesGcm : Type

/-- The token proving the CPU has AVX-512 for AES-GCM. -/
opaque low.x86_64.cpu.HaveAvx512ForAesGcm : Type

/-- The AES keys and GHASH tables of the tiers no proof covers. -/
opaque low.x86_64.vpaes_x86_64.VpaesKey : Type
opaque low.x86_64.aes_nohw.NohwKey : Type
opaque low.x86_64.ghash_ssse3_x86_64.Ssse3Table : Type
opaque low.x86_64.ghash_nohw.NohwTable : Type
opaque low.x86_64.aes_gcm_vaes.VaesKernel : Type

/-- A `&'static T` that a wiped value may hold, as `Rind.X86_64.Dispatch` models it:
the `T`, since only the drop that wipes it leaves it `None`. -/
@[reducible] def low.generic.zeroise.ZeroableRef (T : Type) : Type := T

/-- A curve's key agreement functions, as `Rind.X86_64.Dispatch` models them:
nothing, since `Keyed::generate` builds the only one, of `K`'s own `Agree`
functions, which the model calls directly. -/
@[reducible] def high.agreement.Ops (_K : Type) : Type := Unit

/-- A header-protection key with its cipher's mask, as `Rind.X86_64.Dispatch` models it:
the key, since `Masker::new` builds every one with `C`'s own `mask`, which the
model calls directly. -/
@[reducible] def aead.quic.Masker (C : Type) : Type := C

/-- A hash's context functions, as `Rind.X86_64.DigestDispatch` models them:
nothing, since `Hashing::start` builds the only one, of `C`'s own
`HashContext` functions, which the model calls directly. -/
@[reducible] def high.digest.Ops (_C : Type) : Type := Unit

/-- An expanded AEAD key with its cipher's functions, as `Rind.X86_64.AeadDispatch`
models it: the key, since `Sealer::expand` builds every one with `C`'s own
`seal` and `open`, which the model calls directly. -/
@[reducible] def aead.Sealer (C : Type) : Type := C

end rind.x86_64
