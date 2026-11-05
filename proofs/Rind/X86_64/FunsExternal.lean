module
public import Aeneas
public import Rind.X86_64.Types
public import Rind.X86_64.AesNi
@[expose] public section
open Aeneas Aeneas.Std Result
set_option linter.dupNamespace false

/-!
The rind functions the x86_64 translation leaves opaque, beside those
`Rind.X86_64.AesNi` models. No proof assumes anything about them beyond what
`Rind.X86_64.S2nBignum`, `Rind.X86_64.AwsLc`, and `Rind.X86_64.ValeAesGcm`
state for s2n-bignum's, aws-lc's, and Vale's routines and what each theorem
takes as a hypothesis.
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

/-! aws-lc's SHA-512 routines, behind their Rust wrappers. -/

opaque low.x86_64.sha512.compress_avx
  :
  low.x86_64.cpu.HaveAvx → Array Std.U64 8#usize → Slice Std.U8 → Result
    (Array Std.U64 8#usize)

opaque low.x86_64.sha512.compress_nohw
  : Array Std.U64 8#usize → Slice Std.U8 → Result (Array Std.U64 8#usize)

/-! Vale's AES-GCM routines, behind their Rust wrappers. -/

opaque low.x86_64.aes_gcm_avx.counter_block
  :
  Std.Array Std.U8 12#usize → Std.Array Std.U8 16#usize →
    Std.Array core.core_arch.x86.__m128i 8#usize → low.x86_64.cpu.HaveAvxMovbeForAesGcm →
    Result (Std.Array Std.U8 16#usize)

opaque low.x86_64.aes_gcm_avx.aead
  (ENC : Bool) :
  low.x86_64.aes.HwKey → Std.Array core.core_arch.x86.__m128i 8#usize →
    low.x86_64.aes_gcm_avx.Buffers → low.x86_64.cpu.HaveAvxMovbeForAesGcm →
    Result (Std.U64 × low.x86_64.aes_gcm_avx.Buffers)

/-! AES-GCM's other tiers, which the theorems' CPU never runs. -/

opaque low.x86_64.aes_gcm.tagged
  (ENC : Bool) :
  low.x86_64.aes.AesKey → low.x86_64.ghash.GhashTable → Std.Array Std.U8 12#usize →
    Slice Std.U8 → Slice Std.U8 → Result ((Std.Array Std.U8 16#usize) × (Slice Std.U8))

opaque low.generic.ct_equal.ct_equal : Slice Std.U8 → Slice Std.U8 → Result Bool

opaque low.x86_64.vpaes_x86_64.VpaesKey.new
  : Slice Std.U8 → low.x86_64.cpu.HaveSsse3 → Result low.x86_64.vpaes_x86_64.VpaesKey

opaque low.x86_64.vpaes_x86_64.VpaesKey.encrypt_block
  : low.x86_64.vpaes_x86_64.VpaesKey → Std.Array Std.U8 16#usize → Result (Std.Array Std.U8 16#usize)

opaque low.x86_64.aes_nohw.NohwKey.new : Slice Std.U8 → Result low.x86_64.aes_nohw.NohwKey

opaque low.x86_64.aes_nohw.NohwKey.encrypt_block
  : low.x86_64.aes_nohw.NohwKey → Std.Array Std.U8 16#usize → Result (Std.Array Std.U8 16#usize)

opaque low.x86_64.ghash_ssse3_x86_64.Ssse3Table.new
  : Std.Array Std.U8 16#usize → low.x86_64.cpu.HaveSsse3 → Result low.x86_64.ghash_ssse3_x86_64.Ssse3Table

opaque low.x86_64.ghash_nohw.NohwTable.new
  : Std.Array Std.U8 16#usize → Result low.x86_64.ghash_nohw.NohwTable

opaque low.x86_64.ghash.ClmulTable.from_powers
  : Slice core.core_arch.x86.__m128i → low.x86_64.cpu.HaveAesHardware → Result low.x86_64.ghash.ClmulTable

opaque low.x86_64.aes_gcm_vaes.VaesKernel.powers
  : low.x86_64.aes_gcm_vaes.VaesKernel → Result (Slice core.core_arch.x86.__m128i)

opaque low.x86_64.aes_gcm_vaes.VaesKernel.avx512
  : Std.U128 → low.x86_64.cpu.HaveAvx512ForAesGcm → Result low.x86_64.aes_gcm_vaes.VaesKernel

opaque low.x86_64.aes_gcm_vaes.VaesKernel.avx2
  : Std.U128 → low.x86_64.cpu.HaveVaesAvx2ForAesGcm → Result low.x86_64.aes_gcm_vaes.VaesKernel

/-- Wiping a value, which no proof observes: the translation ignores drops. -/
opaque low.generic.zeroise.zeroise_value {T : Type} (ZeroableInst : low.generic.zeroise.Zeroable T) :
  T → Result T

/-! ChaCha20-Poly1305's AEAD, which no theorem here is about. -/

opaque mid.chacha20poly1305.ChaCha20Poly1305.Insts.RindAeadCipher.new
  : Slice Std.U8 → Result mid.chacha20poly1305.ChaCha20Poly1305

opaque mid.chacha20poly1305.ChaCha20Poly1305.Insts.RindAeadCipher.inner
  : aead.Sealer mid.chacha20poly1305.ChaCha20Poly1305 → Result aead.Inner

opaque mid.chacha20poly1305.ChaCha20Poly1305.Insts.RindAeadCipher.seal
  : mid.chacha20poly1305.ChaCha20Poly1305 → Std.Array Std.U8 12#usize → Slice Std.U8 → Slice Std.U8 →
    Std.Array Std.U8 16#usize →
    Result ((core.result.Result Unit error.Error) × (Slice Std.U8) × (Std.Array Std.U8 16#usize))

opaque mid.chacha20poly1305.ChaCha20Poly1305.Insts.RindAeadCipher.open
  : mid.chacha20poly1305.ChaCha20Poly1305 → Std.Array Std.U8 12#usize → Slice Std.U8 → Slice Std.U8 →
    Std.Array Std.U8 16#usize → Result ((core.result.Result Unit error.Error) × (Slice Std.U8))

/-! s2n-bignum's Ed25519 routines, transliterated to inline assembly. -/

opaque low.x86_64.edwards25519_decode.edwards25519_decode
  :
  Array Std.U64 8#usize → Array Std.U8 32#usize → Result (Bool × (Array
    Std.U64 8#usize))

opaque low.x86_64.edwards25519_scalarmulbase.edwards25519_scalarmulbase
  :
  Array Std.U64 8#usize → Array Std.U64 4#usize → Result (Array Std.U64
    8#usize)

opaque low.x86_64.edwards25519_scalarmuldouble.edwards25519_scalarmuldouble
  :
  Array Std.U64 8#usize → Array Std.U64 4#usize → Array Std.U64 8#usize →
    Array Std.U64 4#usize → Result (Array Std.U64 8#usize)

opaque low.x86_64.bignum_madd_n25519.bignum_madd_n25519
  :
  Array Std.U64 4#usize → Array Std.U64 4#usize → Array Std.U64 4#usize →
    Array Std.U64 4#usize → Result (Array Std.U64 4#usize)

opaque low.x86_64.edwards25519_decode_alt.edwards25519_decode_alt
  :
  Array Std.U64 8#usize → Array Std.U8 32#usize → Result (Bool × (Array
    Std.U64 8#usize))

opaque low.x86_64.edwards25519_scalarmulbase_alt.edwards25519_scalarmulbase_alt
  :
  Array Std.U64 8#usize → Array Std.U64 4#usize → Result (Array Std.U64
    8#usize)

opaque low.x86_64.edwards25519_scalarmuldouble_alt.edwards25519_scalarmuldouble_alt
  :
  Array Std.U64 8#usize → Array Std.U64 4#usize → Array Std.U64 8#usize →
    Array Std.U64 4#usize → Result (Array Std.U64 8#usize)

opaque low.x86_64.bignum_madd_n25519_alt.bignum_madd_n25519_alt
  :
  Array Std.U64 4#usize → Array Std.U64 4#usize → Array Std.U64 4#usize →
    Array Std.U64 4#usize → Result (Array Std.U64 4#usize)

opaque low.x86_64.bignum_mod_n25519.bignum_mod_n25519
  : Array Std.U64 4#usize → Slice Std.U64 → Result (Array Std.U64 4#usize)

opaque low.x86_64.bignum_neg_p25519.bignum_neg_p25519
  :
  Array Std.U64 4#usize → Array Std.U64 4#usize → Result (Array Std.U64
    4#usize)

opaque low.x86_64.bignum_cmp_lt.bignum_cmp_lt
  : Slice Std.U64 → Slice Std.U64 → Result Std.U64

/-! The wipe a drop runs, which no theorem calls. -/

opaque low.generic.zeroise.zeroise
  {T : Type _} (ZeroableInst : low.generic.zeroise.Zeroable T) :
  Slice T → Result (Slice T)

/-! The entry guard and CPU dispatch, which read no input. -/

opaque low.entry.Entry.new_secret : Result low.entry.Entry

opaque low.entry.Entry.new_public : Result low.entry.Entry

/-- Whether an entry guard is held, which a debug build asserts. -/
opaque low.entry.Entry.assert_held : Result Unit

opaque low.x86_64.sha512.avx : Result (Option low.x86_64.cpu.HaveAvx)

opaque low.x86_64.cpu.HaveBmi2Adx.check
  : Result (Option low.x86_64.cpu.HaveBmi2Adx)

opaque low.x86_64.cpu.HaveAesHardware.check : Result (Option low.x86_64.cpu.HaveAesHardware)

opaque low.x86_64.cpu.HaveAvxMovbeForAesGcm.check
  : Result (Option low.x86_64.cpu.HaveAvxMovbeForAesGcm)

opaque low.x86_64.cpu.HaveVaesAvx2ForAesGcm.check
  : Result (Option low.x86_64.cpu.HaveVaesAvx2ForAesGcm)

opaque low.x86_64.cpu.HaveAvx512ForAesGcm.check
  : Result (Option low.x86_64.cpu.HaveAvx512ForAesGcm)

opaque low.x86_64.cpu.HaveSsse3.check : Result (Option low.x86_64.cpu.HaveSsse3)

/-- The SHA-256 routine the CPU runs, picked once. -/
opaque low.x86_64.sha256_mux.path : Result low.x86_64.sha256_mux.Path

/-! SHA-1 and SHA-256's block functions, whose contracts `Rind.X86_64.ShaBlocks`
states as hypotheses. SHA-1's dispatch caches its pick in a `OnceLock`, which
Aeneas cannot translate. -/

opaque low.x86_64.sha1_mux.sha1_compress_blocks
  : Array Std.U32 5#usize → Slice Std.U8 → Result (Array Std.U32 5#usize)

opaque low.x86_64.sha256.sha256_compress_blocks_shaext
  : Array Std.U32 8#usize → Slice Std.U8 → Slice Std.U8 → low.x86_64.cpu.HaveSha256 →
    Result (Array Std.U32 8#usize)

opaque low.x86_64.sha256.sha256_compress_blocks_avx
  : Array Std.U32 8#usize → Slice Std.U8 → low.x86_64.cpu.HaveAvx → Result (Array Std.U32 8#usize)

opaque low.x86_64.sha256.sha256_compress_blocks_avx2
  : Array Std.U32 8#usize → Slice Std.U8 → low.x86_64.cpu.HaveAvx2 → Result (Array Std.U32 8#usize)

opaque low.x86_64.sha256.sha256_compress_blocks_ssse3
  : Array Std.U32 8#usize → Slice Std.U8 → low.x86_64.cpu.HaveSsse3 →
    Result (Array Std.U32 8#usize)

opaque low.x86_64.sha256.sha256_compress_blocks_nohw
  : Array Std.U32 8#usize → Slice Std.U8 → Result (Array Std.U32 8#usize)

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
