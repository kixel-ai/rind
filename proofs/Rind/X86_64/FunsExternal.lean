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

/-! The other curves, which X25519's results never depend on. -/

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

/-! AES, whose header protection no proof covers. -/

opaque mid.aes.Aes.encrypt_block
  : mid.aes.Aes → Array Std.U8 16#usize → Result (Array Std.U8 16#usize)

end rind.x86_64
