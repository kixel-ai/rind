module
public import Aeneas
public import Rind.X86_64.Types
@[expose] public section
open Aeneas Aeneas.Std Result
set_option linter.dupNamespace false

/-!
The rind functions the x86_64 translation leaves opaque. No proof assumes anything
about them beyond what `Rind.X86_64.S2nBignum` states for s2n-bignum's routines
and what each theorem takes as a hypothesis.
-/

namespace rind.x86_64

/-! s2n-bignum's routines, transliterated to inline assembly. -/

opaque low.x86_64.curve25519_x25519base_alt.curve25519_x25519base_alt
  :
  Array Std.U64 4#usize → Array Std.U64 4#usize → Result (Array Std.U64
    4#usize)

opaque low.x86_64.curve25519_x25519base.curve25519_x25519base
  :
  Array Std.U64 4#usize → Array Std.U64 4#usize → Result (Array Std.U64
    4#usize)

opaque low.x86_64.bignum_eq.bignum_eq
  : Slice Std.U64 → Slice Std.U64 → Result Bool

opaque low.x86_64.curve25519_x25519_alt.curve25519_x25519_alt
  :
  Array Std.U64 4#usize → Array Std.U64 4#usize → Array Std.U64 4#usize →
    Result (Array Std.U64 4#usize)

opaque low.x86_64.curve25519_x25519.curve25519_x25519
  :
  Array Std.U64 4#usize → Array Std.U64 4#usize → Array Std.U64 4#usize →
    Result (Array Std.U64 4#usize)

/-! The entry guard and CPU dispatch, which read no input. -/

opaque low.entry.Entry.new_secret : Result low.entry.Entry

opaque low.entry.Entry.new_public : Result low.entry.Entry

opaque low.x86_64.cpu.HaveBmi2Adx.check
  : Result (Option low.x86_64.cpu.HaveBmi2Adx)

/-!
The agreement API's dispatch to each curve's `Agree` impl, through function
pointers, which Aeneas cannot translate. No theorem covers it.
-/

opaque high.agreement.X25519 : Result high.agreement.Algorithm

opaque high.agreement.ECDH_P256 : Result high.agreement.Algorithm

opaque high.agreement.ECDH_P384 : Result high.agreement.Algorithm

opaque high.agreement.ECDH_P521 : Result high.agreement.Algorithm

opaque high.agreement.PrivateKey.generate
  :
  high.agreement.Algorithm → Result (core.result.Result
    high.agreement.PrivateKey error.Error)

opaque high.agreement.PrivateKey.public_key
  : high.agreement.PrivateKey → Result high.agreement.PublicKey

opaque high.agreement.PrivateKey.agree
  :
  high.agreement.PrivateKey → Slice Std.U8 → Result (core.result.Result
    high.agreement.SharedSecret error.Error)

opaque high.agreement.Keyed.generate
  {K : Type} (AgreeInst : high.agreement.Agree K) :
  Result (core.result.Result high.agreement.Private error.Error)

opaque high.agreement.Keyed.public_key
  {K : Type} (AgreeInst : high.agreement.Agree K) :
  high.agreement.Keyed K → Result high.agreement.PublicKey

opaque high.agreement.Keyed.agree
  {K : Type} (AgreeInst : high.agreement.Agree K) :
  high.agreement.Keyed K → Slice Std.U8 → Result (core.result.Result
    high.agreement.Secret error.Error)

/-! The other curves, the wipe on drop, cloning, and formatting, which X25519's results never depend on. -/

opaque high.agreement.PrivateKey.Insts.CoreOpsDropDrop.drop
  : high.agreement.PrivateKey → Result high.agreement.PrivateKey

opaque high.agreement.SharedSecret.Insts.CoreOpsDropDrop.drop
  : high.agreement.SharedSecret → Result high.agreement.SharedSecret

opaque high.agreement.AlgorithmId.Insts.CoreCloneClone.clone
  : high.agreement.AlgorithmId → Result high.agreement.AlgorithmId

opaque high.agreement.AlgorithmId.Insts.CoreCmpPartialEqAlgorithmId.eq
  : high.agreement.AlgorithmId → high.agreement.AlgorithmId → Result Bool

opaque high.agreement.PublicKey.Insts.CoreCloneClone.clone
  : high.agreement.PublicKey → Result high.agreement.PublicKey

opaque mid.p521.PrivateKey.new_random
  : Result (core.result.Result mid.p521.PrivateKey error.Error)

opaque mid.p384.PrivateKey.new_random
  : Result (core.result.Result mid.p384.PrivateKey error.Error)

opaque mid.p256.PrivateKey.new_random
  : Result (core.result.Result mid.p256.PrivateKey error.Error)

opaque mid.p521.PrivateKey.public_key_uncompressed
  : mid.p521.PrivateKey → Result (Array Std.U8 133#usize)

opaque mid.p384.PrivateKey.public_key_uncompressed
  : mid.p384.PrivateKey → Result (Array Std.U8 97#usize)

opaque mid.p256.PrivateKey.public_key_uncompressed
  : mid.p256.PrivateKey → Result (Array Std.U8 65#usize)

opaque mid.p521.PrivateKey.diffie_hellman
  :
  mid.p521.PrivateKey → mid.p521.PublicKey → Result (core.result.Result
    mid.p521.SharedSecret error.Error)

opaque mid.p521.PublicKey.from_x962_uncompressed
  : Slice Std.U8 → Result (core.result.Result mid.p521.PublicKey error.Error)

opaque mid.p384.PrivateKey.diffie_hellman
  :
  mid.p384.PrivateKey → mid.p384.PublicKey → Result (core.result.Result
    mid.p384.SharedSecret error.Error)

opaque mid.p384.PublicKey.from_x962_uncompressed
  : Slice Std.U8 → Result (core.result.Result mid.p384.PublicKey error.Error)

opaque mid.p256.PrivateKey.diffie_hellman
  :
  mid.p256.PrivateKey → mid.p256.PublicKey → Result (core.result.Result
    mid.p256.SharedSecret error.Error)

opaque mid.p256.PublicKey.from_x962_uncompressed
  : Slice Std.U8 → Result (core.result.Result mid.p256.PublicKey error.Error)

opaque high.agreement.AlgorithmId.Insts.CoreFmtDebug.fmt
  :
  high.agreement.AlgorithmId → core.fmt.Formatter → Result
    ((core.result.Result Unit core.fmt.Error) × core.fmt.Formatter)

opaque high.agreement.Algorithm.Insts.CoreFmtDebug.fmt
  :
  high.agreement.Algorithm → core.fmt.Formatter → Result
    ((core.result.Result Unit core.fmt.Error) × core.fmt.Formatter)

opaque high.agreement.PrivateKey.Insts.CoreFmtDebug.fmt
  :
  high.agreement.PrivateKey → core.fmt.Formatter → Result
    ((core.result.Result Unit core.fmt.Error) × core.fmt.Formatter)

opaque high.agreement.PublicKey.Insts.CoreFmtDebug.fmt
  :
  high.agreement.PublicKey → core.fmt.Formatter → Result
    ((core.result.Result Unit core.fmt.Error) × core.fmt.Formatter)

opaque high.agreement.SharedSecret.Insts.CoreFmtDebug.fmt
  :
  high.agreement.SharedSecret → core.fmt.Formatter → Result
    ((core.result.Result Unit core.fmt.Error) × core.fmt.Formatter)

end rind.x86_64
