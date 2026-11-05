import Rind.X86_64.Funs
import Rind.Vale
open Aeneas Aeneas.Std Result rind.vale

/-!
# Vale's AES-GCM contracts on x86_64

Each axiom restates the Vale procedure that one of HACL*'s AES-GCM routines
is printed from, at the HACL* revision `admin/import-hacl` imports
(f557259007db9933442dde10aa995c1b00bd3446), about the opaque Rust wrapper
around it in `low::x86_64::aes_gcm_avx`: `counter_block` around
`compute_iv_stdcall`, and `aead` around `gcm{128,256}_{encrypt,decrypt}_opt`,
which it picks by `ENC` and the key's size, one axiom for each. Vale's `requires` become the
axiom's hypotheses, and its `ensures` the result; the routines are Vale's
System V flavor, `win` false.

Vale's other preconditions hold for every call the wrappers' safe callers
make: each buffer is its own allocation, or the same buffer where Vale allows
it (the counter block and `compute_iv`'s output, the message read and
written in place), none wraps the address space, and the token proves the CPU
has AES-NI, PCLMULQDQ, AVX, SSE, and MOVBE. `len128x6 + 18 < 2^32` follows
from the message's length. The round keys are `HwKey`'s, at the start of
BoringSSL's `AES_KEY` layout `as_aes_key` passes; the GHASH key powers are
the wrapper's `hkeys`, each 16 bytes in order.

The restatement, and that rind's naked functions are Vale's printed text with
the wrappers passing the pointers and counts the procedures name, are trusted.
-/

namespace rind.x86_64

/-- A byte array's bytes. -/
abbrev bvs (l : List U8) : List (BitVec 8) := l.map (·.bv)

/-- Vale's `compute_iv` with no whole blocks of nonce and a 12-byte one, the
first 12 bytes of the counter block it writes over:
`Compute_iv_stdcall`, whose `ensures` is the counter block, read as a
`quad32`, at
https://github.com/hacl-star/hacl-star/blob/f557259007db9933442dde10aa995c1b00bd3446/vale/code/crypto/aes/x64/Vale.AES.X64.GCMencryptOpt.vaf#L1850 -/
@[step]
axiom counter_block_spec (nonce : Std.Array U8 12#usize) (iv : Std.Array U8 16#usize)
    (hkeys : Std.Array core.core_arch.x86.__m128i 8#usize) (t : low.x86_64.cpu.HaveAvxMovbeForAesGcm)
    (hh : hkeysReqsPub hkeys.val (reverseBytesQuad32 (reverseBytesQuad32 hkeys.val[2]!))) :
    low.x86_64.aes_gcm_avx.counter_block nonce iv hkeys t ⦃ j0 =>
      leBytesToQuad32 (bvs j0.val) =
        computeIvBE (reverseBytesQuad32 hkeys.val[2]!) ((bvs iv.val).take 12) ⦄

/-- What Vale's AEAD procedures require of the buffers rind passes, for an
algorithm with `nk` key words: the AAD's whole blocks and its partial block's
16 bytes, the message's whole blocks, of which the six-block loop's share is
`six`, at least `minSix` when not zero, and its partial block's 16 bytes, and
lengths under 2^32. -/
structure AeadBuffers (b : low.x86_64.aes_gcm_avx.Buffers) (minSix : Nat) : Prop where
  aad : b.aad.length < 2 ^ 32
  aad_whole : b.aad_whole.val = b.aad.length / 16 * 16
  aad_partial : b.aad_partial.length = 16
  blocks : b.blocks.length % 16 = 0
  six : b.six.val % 6 = 0 ∧ 16 * b.six.val ≤ b.blocks.length ∧ (0 < b.six.val → minSix ≤ b.six.val)
  partial_len : b.partial.length = 16
  len : b.blocks.length ≤ b.len.val ∧ b.len.val < b.blocks.length + 16
  len32 : b.len.val < 2 ^ 32
  scratch : b.scratch.length = 144

/-- The AAD Vale hashes: the whole blocks, then the partial block, cut to the AAD's length. -/
def authBytes (b : low.x86_64.aes_gcm_avx.Buffers) : List (BitVec 8) :=
  (bvs (b.aad.val.take b.aad_whole.val) ++ bvs b.aad_partial.val).take b.aad.length

/-- The message Vale reads, or the one it writes: the whole blocks, then the
partial block, cut to the message's length. -/
def messageBytes (b : low.x86_64.aes_gcm_avx.Buffers) (len : Nat) : List (BitVec 8) :=
  (bvs b.blocks.val ++ bvs b.partial.val).take len

/-- `gcm128_encrypt_opt`: `Gcm_blocks_stdcall` for `AES_128`, whose `ensures` is
AES-GCM's ciphertext in the message's blocks and its tag, at
https://github.com/hacl-star/hacl-star/blob/f557259007db9933442dde10aa995c1b00bd3446/vale/code/crypto/aes/x64/Vale.AES.X64.GCMencryptOpt.vaf#L1562 -/
@[step]
axiom gcm128_encrypt_opt_spec (k : low.x86_64.aes.AesKey128) (kw : List (BitVec 32))
    (hkw : kw.length = nk .AES_128) (hrk : k.round_keys.val = keyToRoundKeys .AES_128 kw)
    (hkeys : Std.Array core.core_arch.x86.__m128i 8#usize)
    (hh : hkeysReqsPub hkeys.val (reverseBytesQuad32 (aesEncrypt .AES_128 kw (mkfour 0 0 0 0))))
    (iv : List (BitVec 8)) (hiv : 1 ≤ iv.length ∧ 8 * iv.length < 2 ^ 64)
    (b : low.x86_64.aes_gcm_avx.Buffers) (hb : AeadBuffers b 18)
    (hj0 : leBytesToQuad32 (bvs b.iv.val) = computeIvBE (aesEncrypt .AES_128 kw (mkfour 0 0 0 0)) iv)
    (t : low.x86_64.cpu.HaveAvxMovbeForAesGcm) :
    low.x86_64.aes_gcm_avx.aead true (.Aes128 k) hkeys b t ⦃ r =>
      let out := gcmEncrypt .AES_128 (seqNat32ToSeqNat8LE kw) iv (messageBytes b b.len.val) (authBytes b)
      r.2.blocks.length = b.blocks.length ∧ r.2.partial.length = 16 ∧
        messageBytes r.2 b.len.val = out.1 ∧ bvs r.2.tag.val = out.2 ⦄

/-- `gcm256_encrypt_opt`: `Gcm_blocks_stdcall` for `AES_256`, whose `ensures` is
AES-GCM's ciphertext in the message's blocks and its tag, at
https://github.com/hacl-star/hacl-star/blob/f557259007db9933442dde10aa995c1b00bd3446/vale/code/crypto/aes/x64/Vale.AES.X64.GCMencryptOpt.vaf#L1562 -/
@[step]
axiom gcm256_encrypt_opt_spec (k : low.x86_64.aes.AesKey256) (kw : List (BitVec 32))
    (hkw : kw.length = nk .AES_256) (hrk : k.round_keys.val = keyToRoundKeys .AES_256 kw)
    (hkeys : Std.Array core.core_arch.x86.__m128i 8#usize)
    (hh : hkeysReqsPub hkeys.val (reverseBytesQuad32 (aesEncrypt .AES_256 kw (mkfour 0 0 0 0))))
    (iv : List (BitVec 8)) (hiv : 1 ≤ iv.length ∧ 8 * iv.length < 2 ^ 64)
    (b : low.x86_64.aes_gcm_avx.Buffers) (hb : AeadBuffers b 18)
    (hj0 : leBytesToQuad32 (bvs b.iv.val) = computeIvBE (aesEncrypt .AES_256 kw (mkfour 0 0 0 0)) iv)
    (t : low.x86_64.cpu.HaveAvxMovbeForAesGcm) :
    low.x86_64.aes_gcm_avx.aead true (.Aes256 k) hkeys b t ⦃ r =>
      let out := gcmEncrypt .AES_256 (seqNat32ToSeqNat8LE kw) iv (messageBytes b b.len.val) (authBytes b)
      r.2.blocks.length = b.blocks.length ∧ r.2.partial.length = 16 ∧
        messageBytes r.2 b.len.val = out.1 ∧ bvs r.2.tag.val = out.2 ⦄

/-- `gcm128_decrypt_opt`: `Gcm_blocks_decrypt_stdcall` for `AES_128`, whose `ensures` is
AES-GCM's plaintext in the message's blocks, and a zero
result exactly when the tag matches, at
https://github.com/hacl-star/hacl-star/blob/f557259007db9933442dde10aa995c1b00bd3446/vale/code/crypto/aes/x64/Vale.AES.X64.GCMdecryptOpt.vaf#L764 -/
@[step]
axiom gcm128_decrypt_opt_spec (k : low.x86_64.aes.AesKey128) (kw : List (BitVec 32))
    (hkw : kw.length = nk .AES_128) (hrk : k.round_keys.val = keyToRoundKeys .AES_128 kw)
    (hkeys : Std.Array core.core_arch.x86.__m128i 8#usize)
    (hh : hkeysReqsPub hkeys.val (reverseBytesQuad32 (aesEncrypt .AES_128 kw (mkfour 0 0 0 0))))
    (iv : List (BitVec 8)) (hiv : 1 ≤ iv.length ∧ 8 * iv.length < 2 ^ 64)
    (b : low.x86_64.aes_gcm_avx.Buffers) (hb : AeadBuffers b 6)
    (hj0 : leBytesToQuad32 (bvs b.iv.val) = computeIvBE (aesEncrypt .AES_128 kw (mkfour 0 0 0 0)) iv)
    (t : low.x86_64.cpu.HaveAvxMovbeForAesGcm) :
    low.x86_64.aes_gcm_avx.aead false (.Aes128 k) hkeys b t ⦃ r =>
      let out := gcmDecrypt .AES_128 (seqNat32ToSeqNat8LE kw) iv (messageBytes b b.len.val) (authBytes b)
        (bvs b.tag.val)
      r.2.blocks.length = b.blocks.length ∧ r.2.partial.length = 16 ∧
        messageBytes r.2 b.len.val = out.1 ∧ (r.1.val = 0 ↔ out.2 = true) ⦄

/-- `gcm256_decrypt_opt`: `Gcm_blocks_decrypt_stdcall` for `AES_256`, whose `ensures` is
AES-GCM's plaintext in the message's blocks, and a zero
result exactly when the tag matches, at
https://github.com/hacl-star/hacl-star/blob/f557259007db9933442dde10aa995c1b00bd3446/vale/code/crypto/aes/x64/Vale.AES.X64.GCMdecryptOpt.vaf#L764 -/
@[step]
axiom gcm256_decrypt_opt_spec (k : low.x86_64.aes.AesKey256) (kw : List (BitVec 32))
    (hkw : kw.length = nk .AES_256) (hrk : k.round_keys.val = keyToRoundKeys .AES_256 kw)
    (hkeys : Std.Array core.core_arch.x86.__m128i 8#usize)
    (hh : hkeysReqsPub hkeys.val (reverseBytesQuad32 (aesEncrypt .AES_256 kw (mkfour 0 0 0 0))))
    (iv : List (BitVec 8)) (hiv : 1 ≤ iv.length ∧ 8 * iv.length < 2 ^ 64)
    (b : low.x86_64.aes_gcm_avx.Buffers) (hb : AeadBuffers b 6)
    (hj0 : leBytesToQuad32 (bvs b.iv.val) = computeIvBE (aesEncrypt .AES_256 kw (mkfour 0 0 0 0)) iv)
    (t : low.x86_64.cpu.HaveAvxMovbeForAesGcm) :
    low.x86_64.aes_gcm_avx.aead false (.Aes256 k) hkeys b t ⦃ r =>
      let out := gcmDecrypt .AES_256 (seqNat32ToSeqNat8LE kw) iv (messageBytes b b.len.val) (authBytes b)
        (bvs b.tag.val)
      r.2.blocks.length = b.blocks.length ∧ r.2.partial.length = 16 ∧
        messageBytes r.2 b.len.val = out.1 ∧ (r.1.val = 0 ↔ out.2 = true) ⦄

end rind.x86_64
