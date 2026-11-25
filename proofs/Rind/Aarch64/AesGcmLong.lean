import Rind.Aarch64.AesGcm
import Rind.Aarch64.S2nBignum
open Aeneas Aeneas.Std Result rind.vale rind.simd Polynomial

/-!
# rind's AES-GCM on aarch64 past `short`'s lengths

`cipher` with the crypto extension's AES-128 or AES-256 key and a PMULL
table: `stitched` runs s2n-bignum's kernel on the whole blocks, whose
theorems `Rind.Aarch64.S2nBignum` restates, and `partial` the last partial
block. `Rind.S2nGcm` proves the kernels' spec Vale's, so `cipher` is Vale's
GCTR from the block after the counter block and GHASH over the AAD's and the
ciphertext's padded blocks, and `tagged_from` is GCTR and `gcm_hash` at every
length.
-/

local notation "P" => Polynomial (ZMod 2)
local notation "V" => core.core_arch.arm_shared.neon.uint64x2_t

namespace rind.aarch64.long

open rind.aarch64 rind.aarch64.pmull rind.s2n

/-! ## Byte order -/

theorem rev_leBytesToQuad32 (L : List (BitVec 8)) (hL : L.length = 16) :
    reverseBytesQuad32 (leBytesToQuad32 L) = leBytesToQuad32 L.reverse := by
  rw [reverseBytesQuad32, short.leQuad32ToBytes_leBytesToQuad32 L hL]

/-- `u128::from_be_bytes` of a block is its bytes loaded and reversed. -/
theorem from_be_eq (a : Std.Array U8 16#usize) :
    (core.num.U128.from_be_bytes a).bv = reverseBytesQuad32 (loadBytes a.val) := by
  rw [loadBytes, rev_leBytesToQuad32 _ (by simp), leBytesToQuad32]
  unfold core.num.U128.from_be_bytes
  apply BitVec.eq_of_toNat_eq
  have hb := (BitVec.fromLEBytes ((a.val.map (·.bv)).reverse)).isLt
  simp only [List.length_reverse, List.length_map, Std.Array.property] at hb
  simp only [BitVec.fromBEBytes, BitVec.toNat_cast, BitVec.toNat_setWidth, List.map_reverse]
  rw [Nat.mod_eq_of_lt (by simpa using hb)]
  rfl

theorem load_to_be (u : Std.U128) : loadBytes (core.num.U128.to_be_bytes u).val = reverseBytesQuad32 u.bv := by
  rw [← short.rev_load_be u, reverseBytesQuad32_involutive]

theorem rev_rev (x : BitVec 128) : reverseBytesQuad32 (reverseBytesQuad32 x) = x := reverseBytesQuad32_involutive x

theorem mkfour_zero : mkfour 0 0 0 0 = 0 := rfl

/-! ## The key table -/

theorem zipm_eq (a b : BitVec 128) : zipm a b = karatsubaMid b ++ karatsubaMid a := by
  have h : ∀ x : BitVec 128, lo (swap x ^^^ x) = karatsubaMid x := fun x => by
    rw [lo_xor, swap, lo_append, karatsubaMid, BitVec.xor_comm]; rfl
  rw [zipm, h, h]

/-- The table rind's `PmullTable::new` builds for the key `h` is the one the
kernels' theorems name. -/
theorem htable8_eq (h : BitVec 128) (t : low.aarch64.ghash.PmullTable) (ht : TableFor (toPoly h) t) :
    t.htable.val = htable8 (ghashTwist h) := by
  obtain ⟨p, hp, hv⟩ := ht
  have e : ∀ i < 8, hPower (ghashTwist h) i = p[i]! := fun i hi =>
    toPoly_inj (by rw [toPoly_hPower, hp i hi])
  rw [hv, htable8, htable4, e 0 (by omega), e 1 (by omega), e 2 (by omega), e 3 (by omega), e 4 (by omega),
    e 5 (by omega), e 6 (by omega), e 7 (by omega), htableOf]
  simp only [zipm_eq, List.cons_append, List.nil_append]
  rfl

/-! ## `stitched` -/

/-- What `stitched` ensures, as Vale states GCTR and GHASH: each output block
the input block XORed with the keystream of the counter block `j` advanced
`i`, the counter block advanced past the blocks, and the hash `x` advanced
over the ciphertext's blocks, the output's sealing and the input's opening,
under the key `H`. -/
def StitchedPost (ENC : Bool) (alg : Algorithm) (kw : List (BitVec 32)) (H : P) (x j : BitVec 128)
    (blocks : Slice (Std.Array U8 16#usize))
    (r : Std.Array U8 16#usize × Std.Array U8 16#usize × Slice (Std.Array U8 16#usize)) : Prop :=
  r.2.2.length = blocks.length ∧
  (∀ i < blocks.length, loadBytes r.2.2.val[i]!.val =
    loadBytes blocks.val[i]!.val ^^^ aesEncrypt alg kw (reverseBytesQuad32 (inc32 j i))) ∧
  loadBytes r.2.1.val = reverseBytesQuad32 (inc32 j blocks.length) ∧
  toPoly (reverseBytesQuad32 (loadBytes r.1.val)) = ghashPoly H (toPoly x)
    ((List.range blocks.length).map fun i => polyLE (loadBytes (if ENC then r.2.2 else blocks).val[i]!.val))

/-- The cipher of zero under the kernels' round keys, rind's keys reversed, is
the hash key, bytes reversed. -/
theorem cipher_zero (enc : BitVec 128 → List (BitVec 128) → BitVec 128) (alg : Algorithm)
    (kw : List (BitVec 32)) (keys : List (BitVec 128)) (hkeys : keys = keyToRoundKeys alg kw)
    (henc : ∀ x rk, reverseBytesQuad32 (enc x rk) = evalCipher alg (reverseBytesQuad32 x) (rk.map reverseBytesQuad32)) :
    enc 0#128 (keys.map reverseBytesQuad32) = reverseBytesQuad32 (aesEncrypt alg kw (mkfour 0 0 0 0)) := by
  have hrk : (keys.map reverseBytesQuad32).map reverseBytesQuad32 = keyToRoundKeys alg kw := by
    rw [List.map_map, ← hkeys]; simp [Function.comp_def, rev_rev]
  have hz : reverseBytesQuad32 0#128 = 0 := rev_zero
  rw [← rev_rev (enc _ _), henc, hrk, hz, mkfour_zero, aesEncrypt]

/-- One kernel's theorem, as `StitchedPost`. -/
theorem kernel_post (ENC : Bool) (enc : BitVec 128 → List (BitVec 128) → BitVec 128) (alg : Algorithm)
    (kw : List (BitVec 32)) (keys : List (BitVec 128)) (hkeys : keys = keyToRoundKeys alg kw)
    (henc : ∀ x rk, reverseBytesQuad32 (enc x rk) = evalCipher alg (reverseBytesQuad32 x) (rk.map reverseBytesQuad32))
    (x j : BitVec 128) (blocks : Slice (Std.Array U8 16#usize)) (r : low.aarch64.aes_gcm.KernelOut)
    (hashed : Nat → BitVec 128)
    (hhashed : hashed = if ENC then nistCipherBlock enc (j.extractLsb' 0 32).toNat (j.extractLsb' 32 96)
        (keys.map reverseBytesQuad32) (fun i => loadBytes blocks.val[i]!.val)
      else nistInputBlock (fun i => loadBytes blocks.val[i]!.val))
    (hr : GcmKernelOut enc hashed blocks.length x (j.extractLsb' 32 96) (j.extractLsb' 0 32).toNat
      (keys.map reverseBytesQuad32) (fun i => loadBytes blocks.val[i]!.val) r) :
    StitchedPost ENC alg kw (polyLE (aesEncrypt alg kw (mkfour 0 0 0 0))) x j blocks (r.2.1, r.2.2, r.1) := by
  obtain ⟨hl, hout, htag, hctr⟩ := hr
  have hrk : (keys.map reverseBytesQuad32).map reverseBytesQuad32 = keyToRoundKeys alg kw := by
    rw [List.map_map, ← hkeys]; simp [Function.comp_def, rev_rev]
  have hh : ∀ i < blocks.length,
      hashed i = reverseBytesQuad32 (loadBytes (if ENC then r.1 else blocks).val[i]!.val) := by
    intro i hi
    subst hhashed
    cases ENC
    · simp only [Bool.false_eq_true, ite_false, nistInputBlock, wordReversefields8]
    · simp only [ite_true, nistCipherBlock, cipherBlock, wordReversefields8, hout i hi]
  refine ⟨hl, fun i hi => ?_, ?_, ?_⟩
  · rw [hout i hi, aesCtrBlock_eq enc alg _ kw (henc · _) hrk j i, BitVec.xor_comm]
  · rw [hctr, wordReversefields8, ← inc32_ctrBlock, ctrBlock_split]
  · rw [htag, wordReversefields8, rev_rev, toPoly_nistGhash, cipher_zero enc alg kw keys hkeys henc, ← polyLE,
      listOfSeq, List.map_map]
    refine congrArg _ (List.map_congr_left fun i hi => ?_)
    rw [List.mem_range] at hi
    simp only [Function.comp_apply, hh i hi, polyLE]

/-- `stitched` with an AES-128 or AES-256 key and a table for its hash key:
s2n-bignum's kernels' theorems, as Vale states GCTR and GHASH. -/
theorem stitched_spec (ENC : Bool) (hk : low.aarch64.aes.HwKey) (alg : Algorithm) (kw : List (BitVec 32))
    (hkey : HwKeyIs alg kw hk) (h192 : alg ≠ .AES_192) (t : low.aarch64.ghash.PmullTable)
    (ht : TableFor (polyLE (aesEncrypt alg kw (mkfour 0 0 0 0))) t)
    (tag counter : Std.Array U8 16#usize) (x j : BitVec 128) (htag : loadBytes tag.val = reverseBytesQuad32 x)
    (hctr : loadBytes counter.val = reverseBytesQuad32 j) (blocks : Slice (Std.Array U8 16#usize))
    (hn : blocks.length < 2 ^ 57) :
    low.aarch64.aes_gcm.stitched ENC hk t tag counter blocks ⦃ r =>
      StitchedPost ENC alg kw (polyLE (aesEncrypt alg kw (mkfour 0 0 0 0))) x j blocks r ⦄ := by
  unfold low.aarch64.aes_gcm.stitched
  by_cases h0 : blocks.length = 0
  · simp only [h0, ite_true, WP.spec_ok]
    refine ⟨rfl, fun i hi => by omega, by rw [h0, inc32_zero, hctr], ?_⟩
    rw [h0, List.range_zero, List.map_nil, ghashPoly_nil, htag, rev_rev]
  simp only [h0, ite_false]
  have hin : ∀ keys : List (BitVec 128), GcmKernelIn blocks tag counter keys x (j.extractLsb' 32 96)
      (j.extractLsb' 0 32).toNat (keys.map reverseBytesQuad32) (fun i => loadBytes blocks.val[i]!.val) :=
    fun keys => ⟨by rw [htag, wordReversefields8], by rw [hctr, wordReversefields8, ctrBlock_split],
      by simp [List.map_map, Function.comp_def, wordReversefields8, rev_rev], fun _ _ => rfl⟩
  have htab : ∀ (enc : BitVec 128 → List (BitVec 128) → BitVec 128) (keys : List (BitVec 128)),
      keys = keyToRoundKeys alg kw →
      (∀ x rk, reverseBytesQuad32 (enc x rk) = evalCipher alg (reverseBytesQuad32 x) (rk.map reverseBytesQuad32)) →
      t.htable.val = htable8 (ghashTwist (enc 0#128 (keys.map reverseBytesQuad32))) := by
    intro enc keys hkeys henc
    rw [cipher_zero enc alg kw keys hkeys henc]
    rw [polyLE] at ht
    exact htable8_eq _ t ht
  have htab4 : ∀ (enc : BitVec 128 → List (BitVec 128) → BitVec 128) (keys : List (BitVec 128)),
      keys = keyToRoundKeys alg kw →
      (∀ x rk, reverseBytesQuad32 (enc x rk) = evalCipher alg (reverseBytesQuad32 x) (rk.map reverseBytesQuad32)) →
      (Std.Array.make 6#usize (t.htable.val.take 6) (by simp) : Std.Array V 6#usize).val =
        htable4 (ghashTwist (enc 0#128 (keys.map reverseBytesQuad32))) := by
    intro enc keys hkeys henc
    rw [Std.Array.make_val]
    rw [htab enc keys hkeys henc, htable8, List.take_left' (by rfl)]
  cases hk with
  | Aes192 k => obtain ⟨rfl, -⟩ := hkey; exact absurd rfl h192
  | Aes128 k =>
    obtain ⟨rfl, hrk⟩ := hkey
    cases ENC <;> rcases he : t.eight_way with _ | s <;> simp only
    · apply WP.spec_bind (aes128_gcm_dec_spec blocks tag counter k.round_keys _ x _ _ _ _ hn (hin _)
        (htab4 aes128Cipher _ hrk aes128Cipher_eq))
      intro r hr; rw [WP.spec_ok]
      exact kernel_post false aes128Cipher .AES_128 kw _ hrk aes128Cipher_eq x j blocks r _ rfl hr
    · apply WP.spec_bind (aes128_gcm_dec_alt_spec blocks tag counter k.round_keys _ x _ _ _ _ hn (hin _)
        (htab aes128Cipher _ hrk aes128Cipher_eq))
      intro r hr; rw [WP.spec_ok]
      exact kernel_post false aes128Cipher .AES_128 kw _ hrk aes128Cipher_eq x j blocks r _ rfl hr
    · apply WP.spec_bind (aes128_gcm_enc_spec blocks tag counter k.round_keys _ x _ _ _ _ hn (hin _)
        (htab4 aes128Cipher _ hrk aes128Cipher_eq))
      intro r hr; rw [WP.spec_ok]
      exact kernel_post true aes128Cipher .AES_128 kw _ hrk aes128Cipher_eq x j blocks r _ rfl hr
    · apply WP.spec_bind (aes128_gcm_enc_alt_spec blocks tag counter k.round_keys _ x _ _ _ _ hn (hin _)
        (htab aes128Cipher _ hrk aes128Cipher_eq))
      intro r hr; rw [WP.spec_ok]
      exact kernel_post true aes128Cipher .AES_128 kw _ hrk aes128Cipher_eq x j blocks r _ rfl hr
  | Aes256 k =>
    obtain ⟨rfl, hrk⟩ := hkey
    cases ENC <;> rcases he : t.eight_way with _ | s <;> simp only
    · apply WP.spec_bind (aes256_gcm_dec_spec blocks tag counter k.round_keys _ x _ _ _ _ hn (hin _)
        (htab4 aes256Cipher _ hrk aes256Cipher_eq))
      intro r hr; rw [WP.spec_ok]
      exact kernel_post false aes256Cipher .AES_256 kw _ hrk aes256Cipher_eq x j blocks r _ rfl hr
    · apply WP.spec_bind (aes256_gcm_dec_alt_spec blocks tag counter k.round_keys _ x _ _ _ _ hn (hin _)
        (htab aes256Cipher _ hrk aes256Cipher_eq))
      intro r hr; rw [WP.spec_ok]
      exact kernel_post false aes256Cipher .AES_256 kw _ hrk aes256Cipher_eq x j blocks r _ rfl hr
    · apply WP.spec_bind (aes256_gcm_enc_spec blocks tag counter k.round_keys _ x _ _ _ _ hn (hin _)
        (htab4 aes256Cipher _ hrk aes256Cipher_eq))
      intro r hr; rw [WP.spec_ok]
      exact kernel_post true aes256Cipher .AES_256 kw _ hrk aes256Cipher_eq x j blocks r _ rfl hr
    · apply WP.spec_bind (aes256_gcm_enc_alt_spec blocks tag counter k.round_keys _ x _ _ _ _ hn (hin _)
        (htab aes256Cipher _ hrk aes256Cipher_eq))
      intro r hr; rw [WP.spec_ok]
      exact kernel_post true aes256Cipher .AES_256 kw _ hrk aes256Cipher_eq x j blocks r _ rfl hr

end rind.aarch64.long
