module
public import Aeneas
public import Rind.Aarch64.Types
@[expose] public section
open Aeneas Aeneas.Std Result
set_option linter.dupNamespace false

/-!
The rind functions the aarch64 translation leaves opaque. No proof assumes anything
about them beyond what `Rind.Aarch64.S2nBignum` and `Rind.Aarch64.AwsLc` state for
s2n-bignum's and aws-lc's routines and what each theorem takes as a hypothesis.
-/

namespace rind.aarch64

/-! s2n-bignum's routines, transliterated to inline assembly. -/

opaque low.aarch64.curve25519_x25519base.curve25519_x25519base
  :
  Array Std.U64 4#usize → Array Std.U64 4#usize → Result (Array Std.U64
    4#usize)

opaque low.aarch64.curve25519_x25519.curve25519_x25519
  :
  Array Std.U64 4#usize → Array Std.U64 4#usize → Array Std.U64 4#usize →
    Result (Array Std.U64 4#usize)

opaque low.aarch64.bignum_eq.bignum_eq
  : Slice Std.U64 → Slice Std.U64 → Result Bool

opaque low.aarch64.bignum_tomont_p256.bignum_tomont_p256
  : Array Std.U64 4#usize → Array Std.U64 4#usize → Result (Array Std.U64 4#usize)

opaque low.aarch64.bignum_demont_p256.bignum_demont_p256
  : Array Std.U64 4#usize → Array Std.U64 4#usize → Result (Array Std.U64 4#usize)

opaque low.aarch64.bignum_add_p256.bignum_add_p256
  :
  Array Std.U64 4#usize → Array Std.U64 4#usize → Array Std.U64 4#usize →
    Result (Array Std.U64 4#usize)

opaque low.aarch64.bignum_montmul_p256.bignum_montmul_p256
  :
  Array Std.U64 4#usize → Array Std.U64 4#usize → Array Std.U64 4#usize →
    Result (Array Std.U64 4#usize)

opaque low.aarch64.bignum_montsqr_p256.bignum_montsqr_p256
  : Array Std.U64 4#usize → Array Std.U64 4#usize → Result (Array Std.U64 4#usize)

opaque low.aarch64.bignum_mod_n256.bignum_mod_n256
  : Array Std.U64 4#usize → Array Std.U64 4#usize → Result (Array Std.U64 4#usize)

opaque low.aarch64.p256_scalarmul.p256_scalarmul
  :
  Array Std.U64 8#usize → Array Std.U64 4#usize → Array Std.U64 8#usize →
    Result (Array Std.U64 8#usize)

opaque low.aarch64.p256_scalarmulbase.p256_scalarmulbase
  :
  Array Std.U64 8#usize → Array Std.U64 4#usize → Array (Array Std.U64
    256#usize) 43#usize → Result (Array Std.U64 8#usize)

opaque low.aarch64.bignum_inv_p256.bignum_inv_p256
  : Array Std.U64 4#usize → Array Std.U64 4#usize → Result (Array Std.U64 4#usize)

opaque low.aarch64.bignum_neg_p256.bignum_neg_p256
  : Array Std.U64 4#usize → Array Std.U64 4#usize → Result (Array Std.U64 4#usize)

opaque low.aarch64.p256_montjadd.p256_montjadd
  :
  Array Std.U64 12#usize → Array Std.U64 12#usize → Array Std.U64 12#usize →
    Result (Array Std.U64 12#usize)

opaque low.aarch64.p256_montjdouble.p256_montjdouble
  : Array Std.U64 12#usize → Array Std.U64 12#usize → Result (Array Std.U64 12#usize)

opaque low.aarch64.p256_montjmixadd.p256_montjmixadd
  :
  Array Std.U64 12#usize → Array Std.U64 12#usize → Array Std.U64 8#usize →
    Result (Array Std.U64 12#usize)

opaque low.aarch64.bignum_modadd.bignum_modadd
  :
  Slice Std.U64 → Slice Std.U64 → Slice Std.U64 → Slice Std.U64 →
    Result (Slice Std.U64)

opaque low.aarch64.bignum_montmul.bignum_montmul
  :
  Slice Std.U64 → Slice Std.U64 → Slice Std.U64 → Slice Std.U64 →
    Result (Slice Std.U64)

opaque low.aarch64.bignum_demont.bignum_demont
  : Slice Std.U64 → Slice Std.U64 → Slice Std.U64 → Result (Slice Std.U64)

opaque low.aarch64.bignum_modinv.bignum_modinv
  :
  Slice Std.U64 → Slice Std.U64 → Slice Std.U64 → Slice Std.U64 →
    Result ((Slice Std.U64) × (Slice Std.U64))

/-! P-256's key generation, which draws through a `dyn RandomSource`:
`Rind.Aarch64.P256Dispatch` models it. -/

opaque mid.p256.PrivateKey.new_random
  : Result (core.result.Result mid.p256.PrivateKey error.Error)

/-! aws-lc's SHA-512 routines, behind their Rust wrappers. -/

opaque low.aarch64.sha512.compress_hw
  :
  low.aarch64.cpu.HaveSha3 → Array Std.U64 8#usize → Slice Std.U8 → Result
    (Array Std.U64 8#usize)

opaque low.aarch64.sha512.compress_nohw
  : Array Std.U64 8#usize → Slice Std.U8 → Result (Array Std.U64 8#usize)

/-! s2n-bignum's Ed25519 routines, transliterated to inline assembly. -/

opaque low.aarch64.edwards25519_decode.edwards25519_decode
  :
  Array Std.U64 8#usize → Array Std.U8 32#usize → Result (Bool × (Array
    Std.U64 8#usize))

opaque low.aarch64.edwards25519_scalarmulbase.edwards25519_scalarmulbase
  :
  Array Std.U64 8#usize → Array Std.U64 4#usize → Result (Array Std.U64
    8#usize)

opaque low.aarch64.edwards25519_scalarmuldouble.edwards25519_scalarmuldouble
  :
  Array Std.U64 8#usize → Array Std.U64 4#usize → Array Std.U64 8#usize →
    Array Std.U64 4#usize → Result (Array Std.U64 8#usize)

opaque low.aarch64.bignum_madd_n25519.bignum_madd_n25519
  :
  Array Std.U64 4#usize → Array Std.U64 4#usize → Array Std.U64 4#usize →
    Array Std.U64 4#usize → Result (Array Std.U64 4#usize)

opaque low.aarch64.bignum_mod_n25519.bignum_mod_n25519
  : Array Std.U64 4#usize → Slice Std.U64 → Result (Array Std.U64 4#usize)

opaque low.aarch64.bignum_neg_p25519.bignum_neg_p25519
  :
  Array Std.U64 4#usize → Array Std.U64 4#usize → Result (Array Std.U64
    4#usize)

opaque low.aarch64.bignum_cmp_lt.bignum_cmp_lt
  : Slice Std.U64 → Slice Std.U64 → Result Std.U64

/-! P-256's ECDSA key generation, which the signing theorems model, and its
PKCS#8 OID, which none states. -/

opaque high.curve.P256.Insts.RindHighCurveCurveStaticPrivateKeyVerifyingKeyScalar.generate_random_key
  {T0 : Type _} (midrngRandomSourceInst : mid.rng.RandomSource T0) :
  T0 → Result ((core.result.Result mid.p256.StaticPrivateKey error.Error) × T0)

opaque high.curve.P256.Insts.RindHighCurveCurveStaticPrivateKeyVerifyingKeyScalar.oid
  : Result high.asn1.ObjectId

/-! The HMAC-DRBG an ECDSA signature draws its nonces from. -/

opaque high.hmac_drbg.HmacDrbg.new
  {H : Type _} {Clause0_Context : Type _} {Clause0_State : Type _}
  (hashHashInst : high.hash.Hash H Clause0_Context Clause0_State) :
  Slice Std.U8 → Slice Std.U8 → Slice Std.U8 →
    Result (high.hmac_drbg.HmacDrbg H Clause0_Context Clause0_State)

opaque high.hmac_drbg.HmacDrbg.Insts.RindMidRngRandomSource.fill
  {H : Type _} {Clause0_Context : Type _} {Clause0_State : Type _}
  (hashHashInst : high.hash.Hash H Clause0_Context Clause0_State) :
  high.hmac_drbg.HmacDrbg H Clause0_Context Clause0_State → Slice Std.U8 →
    Result ((core.result.Result Unit error.Error) × (high.hmac_drbg.HmacDrbg H
    Clause0_Context Clause0_State) × (Slice Std.U8))

/-! The verifying key's cache of 17P, ..., 31P, which ECDSA verification's
theorems take what they need of as a hypothesis. -/

opaque low.generic.reuse_cache.ReuseCache.new
  {T : Type _} (coremarkerCopyInst : core.marker.Copy T)
  (coredefaultDefaultInst : core.default.Default T) :
  Result (low.generic.reuse_cache.ReuseCache T)

opaque low.generic.reuse_cache.ReuseCache.get_or_build
  {T : Type _} {T1 : Type _} (coremarkerCopyInst : core.marker.Copy T)
  (coredefaultDefaultInst : core.default.Default T)
  (coreopsfunctionFnOnceT1TupleTInst : core.ops.function.FnOnce T1 Unit T) :
  low.generic.reuse_cache.ReuseCache T → T1 → Result (Option T)

/-! The wipe a drop runs, which no theorem calls. -/

opaque low.generic.zeroise.zeroise
  {T : Type _} (ZeroableInst : low.generic.zeroise.Zeroable T) :
  Slice T → Result (Slice T)

/-! The entry guard and CPU dispatch, which read no input. -/

opaque low.entry.Entry.new_secret : Result low.entry.Entry

opaque low.entry.Entry.new_public : Result low.entry.Entry

/-- Whether an entry guard is held, which a debug build asserts. -/
opaque low.entry.Entry.assert_held : Result Unit

opaque low.aarch64.cpu.HaveSha3.check : Result (Option low.aarch64.cpu.HaveSha3)

/-! The other curves, which X25519's and P-256's results never depend on. -/

opaque mid.p521.PrivateKey.new_random
  : Result (core.result.Result mid.p521.PrivateKey error.Error)

opaque mid.p384.PrivateKey.new_random
  : Result (core.result.Result mid.p384.PrivateKey error.Error)

opaque mid.p521.PrivateKey.public_key_uncompressed
  : mid.p521.PrivateKey → Result (Array Std.U8 133#usize)

opaque mid.p384.PrivateKey.public_key_uncompressed
  : mid.p384.PrivateKey → Result (Array Std.U8 97#usize)

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

/-! SHA-1 and SHA-256, which no theorem is about. -/

opaque high.hash.LegacySha1.Insts.RindHighHashHashSha1ContextSha1State.ALGORITHM
  : Result high.digest.Algorithm

opaque high.hash.LegacySha1.Insts.RindHighHashHashSha1ContextSha1State.initial
  : Result high.hash.Sha1State

opaque high.hash.LegacySha1.Insts.RindHighHashHashSha1ContextSha1State.new
  : Result high.hash.Sha1Context

opaque high.hash.LegacySha1.Insts.RindHighHashHashSha1ContextSha1State.zeroed_block
  : Result high.hash.HashBlock

opaque high.hash.Sha1Context.Insts.RindHighHashHashContext.update
  : high.hash.Sha1Context → Slice Std.U8 → Result high.hash.Sha1Context

opaque high.hash.Sha1Context.Insts.RindHighHashHashContext.finish
  : high.hash.Sha1Context → Result high.digest.Digest

opaque high.hash.Sha1State.Insts.RindHighHashHashStateSha1Context.update_blocks
  : high.hash.Sha1State → Slice Std.U8 → Result high.hash.Sha1State

opaque high.hash.Sha1State.Insts.RindHighHashHashStateSha1Context.finish_with
  : high.hash.Sha1State → Slice Std.U8 → Result high.digest.Digest

opaque high.hash.Sha1State.Insts.RindHighHashHashStateSha1Context.resume
  : high.hash.Sha1State → Result high.hash.Sha1Context

opaque high.hash.Sha256.Insts.RindHighHashHashSha256ContextSha256State.ALGORITHM
  : Result high.digest.Algorithm

opaque high.hash.Sha256.Insts.RindHighHashHashSha256ContextSha256State.initial
  : Result high.hash.Sha256State

opaque high.hash.Sha256.Insts.RindHighHashHashSha256ContextSha256State.new
  : Result high.hash.Sha256Context

opaque high.hash.Sha256.Insts.RindHighHashHashSha256ContextSha256State.zeroed_block
  : Result high.hash.HashBlock

opaque high.hash.Sha256Context.Insts.RindHighHashHashContext.update
  : high.hash.Sha256Context → Slice Std.U8 → Result high.hash.Sha256Context

opaque high.hash.Sha256Context.Insts.RindHighHashHashContext.finish
  : high.hash.Sha256Context → Result high.digest.Digest

opaque high.hash.Sha256State.Insts.RindHighHashHashStateSha256Context.update_blocks
  : high.hash.Sha256State → Slice Std.U8 → Result high.hash.Sha256State

opaque high.hash.Sha256State.Insts.RindHighHashHashStateSha256Context.finish_with
  : high.hash.Sha256State → Slice Std.U8 → Result high.digest.Digest

opaque high.hash.Sha256State.Insts.RindHighHashHashStateSha256Context.resume
  : high.hash.Sha256State → Result high.hash.Sha256Context

/-! AES, whose header protection no proof covers. -/

opaque mid.aes.Aes.encrypt_block
  : mid.aes.Aes → Array Std.U8 16#usize → Result (Array Std.U8 16#usize)

end rind.aarch64
