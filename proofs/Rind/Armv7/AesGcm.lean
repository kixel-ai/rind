import Rind.Armv7.AesNohwCtr
import Rind.Armv7.GhashNohw
import Rind.Armv7.CtEqual
open Aeneas Aeneas.Std Result rind.vale rind.simd Polynomial

/-!
# AES-GCM on armv7 without the crypto extension or NEON

`mid/portable/aes_gcm.rs`'s `Portable`: aws-lc's bitsliced AES in 32-bit
words, `Rind.Armv7.AesNohwCtr`'s counter mode, and its integer GHASH,
`Rind.Armv7.GhashNohw`'s, composed by `Parts::tagged`. `tagged_spec` proves
`tagged` for any `Parts` whose table hashes, whose `encrypt_block` is AES, and
whose `ctr` is GCTR, so the NEON and crypto-extension compositions need only
those; `Portable` is proven to be one. `AesGcm::new`, with the CPU checks
finding neither extension, keys `Portable`, and its `encrypt`, `decrypt`,
`encrypt_any`, and `decrypt_any` are then Vale's `gcm_encrypt_LE` and
`gcm_decrypt_LE`, over `Rind.Armv7.CtEqual`'s restatement of HOL Light's
proofs of the compares.
-/

local notation "P" => Polynomial (ZMod 2)

namespace rind.armv7

open low.portable.aes_nohw low.portable.ghash_nohw

/-! ## Blocks -/

theorem blockQ_load (a : Std.Array U8 16#usize) : blockQ a = loadBytes a.val := blockQ_eq a

theorem blockBE_blockQ (a : Std.Array U8 16#usize) : blockBE a.val = reverseBytesQuad32 (blockQ a) := by
  rw [blockBE, blockQ_load]

theorem blockQ_to_be (u : U128) : blockQ (core.num.U128.to_be_bytes u) = reverseBytesQuad32 u.bv := by
  rw [← blockBE_to_be u, blockBE_blockQ, reverseBytesQuad32_involutive]

theorem add32_bv (b : BitVec 128) (n : BitVec 32) :
    (b &&& ~~~0xffffffff#128) ||| (b.setWidth 32 + n).setWidth 128 = b.extractLsb' 32 96 ++ (b.extractLsb' 0 32 + n) := by
  bv_decide

/-- `add32` steps the counter block's low word by `n`, as `inc32` does. -/
theorem add32_spec (J : Quad32) (block : Std.Array U8 16#usize) (hb : blockQ block = reverseBytesQuad32 J)
    (n : U32) : mid.aes_gcm.add32 block n ⦃ r => blockQ r = reverseBytesQuad32 (inc32 J n.val) ⦄ := by
  unfold mid.aes_gcm.add32
  step*
  simp only [lift, bind_ok, WP.spec_ok]
  rw [blockQ_to_be]
  apply congrArg
  have hbv : b.bv = J := by
    rw [b_post, fromBE_blockBE, blockBE_blockQ, hb, reverseBytesQuad32_involutive]
  have c : (~~~4294967295#u128 : U128).bv = ~~~0xffffffff#128 := rfl
  have hn : BitVec.ofNat 32 n.val = n.bv := by simp
  simp only [UScalar.bv_or, i2_post1, i1_post, c, core.convert.num.FromU128U32.from_bv_eq, ctr_post,
    core.num.U32.wrapping_add_bv_eq, i_post, UScalar.cast_bv_eq, hbv, inc32_eq, hn, UScalarTy.U32_numBits_eq,
    UScalarTy.U128_numBits_eq]
  exact add32_bv J n.bv

theorem usize_lt (n : Usize) : n.val < 2 ^ 64 := by
  have := n.hmax
  rcases System.Platform.numBits_eq with h | h
  · simp_all [UScalarTy.Usize_numBits_eq]; omega
  · simp_all [UScalarTy.Usize_numBits_eq]

/-- `lengths` is GCM's last GHASH block, the AAD's and the message's bit
lengths, as GHASH reads it. -/
theorem lengths_spec (aad msg : Usize) (ha : 8 * aad.val < 2 ^ 64) (hm : 8 * msg.val < 2 ^ 64) :
    mid.aes_gcm.lengths aad msg ⦃ r =>
      blockBE r.val = insertNat64 (insertNat64 (mkfour 0 0 0 0) (8 * aad.val) 1) (8 * msg.val) 0 ⦄ := by
  unfold mid.aes_gcm.lengths
  have hab := usize_lt aad
  have hmb := usize_lt msg
  step*
  have h1 : i1.bv = BitVec.ofNat 128 (8 * aad.val) := by
    apply BitVec.eq_of_toNat_eq
    rw [UScalar.bv_toNat, i1_post, i_post, UScalar.cast_val_eq, BitVec.toNat_ofNat]
    simp only [UScalarTy.U128_numBits_eq]
    rw [Nat.mod_eq_of_lt (by omega), Nat.mod_eq_of_lt (by omega)]; ring
  have h4 : i4.bv = BitVec.ofNat 128 (8 * msg.val) := by
    apply BitVec.eq_of_toNat_eq
    rw [UScalar.bv_toNat, i4_post, i3_post, UScalar.cast_val_eq, BitVec.toNat_ofNat]
    simp only [UScalarTy.U128_numBits_eq]
    rw [Nat.mod_eq_of_lt (by omega), Nat.mod_eq_of_lt (by omega)]; ring
  rw [blockBE_to_be, ← lengths_eq _ _ hm]
  simp only [i5_post1, i2_post1, h1, h4]

/-! ## GHASH over bytes -/

/-- A `Ghash` instance and table that hash as GHASH does under the key `H`. -/
def GhashFor (H : P) {T : Type} (G : mid.aes_gcm.Ghash T) (t : T) : Prop :=
  ∀ xi input, G.ghash t xi input ⦃ r =>
    toPoly (blockBE r.val) = ghashPoly H (toPoly (blockBE xi.val)) (input.val.map fun b => toPoly (blockBE b.val)) ⦄

theorem nohw_ghashFor (H : P) (hH : Small H) (t : NohwTable) (ht : TableFor H t) :
    GhashFor H NohwTable.Insts.RindMidAes_gcmGhash t :=
  fun xi input => ghash_spec H hH t ht xi input

theorem as_chunks_spec (N : Usize) (hN : N.val ≠ 0) (s : Slice U8) :
    core.slice.Slice.as_chunks N s ⦃ p =>
      p.1.val.map (·.val) = chunksOf N.val s.val ∧ p.2.val = chunksRest N.val s.val ⦄ := by
  simp only [core.slice.Slice.as_chunks, hN, ite_false, WP.spec_ok]
  refine ⟨?_, by simp [Slice.from_val, chunksRest, Slice.length, Nat.mul_comm]⟩
  apply List.ext_getElem (by simp [Slice.from_val, chunksOf, Slice.length])
  intro i h1 h2
  simp [Slice.from_val, chunksOf, Std.Array.from_val, Nat.mul_comm]

/-- `ghash` folds `data` into `xi`, its last block padded with zeros. -/
theorem ghash_pad_spec (H : P) {T : Type} (G : mid.aes_gcm.Ghash T) (t : T) (hG : GhashFor H G t)
    (xi : Std.Array U8 16#usize) (data : Slice U8) :
    mid.aes_gcm.ghash G t xi data ⦃ r =>
      toPoly (blockBE r.val) = ghashPoly H (toPoly (blockBE xi.val)) ((padBlocks data.val).map toPoly) ⦄ := by
  unfold mid.aes_gcm.ghash
  step with as_chunks_spec 16#usize (by decide) data as ⟨blocks, tail, hb, ht⟩
  step with hG xi blocks as ⟨x1, hx1⟩
  have hbm : blocks.val.map (fun b => toPoly (blockBE b.val)) = (chunksOf 16 data.val).map (toPoly ∘ blockBE) := by
    simp only [← hb, List.map_map, Function.comp_def]
  step as ⟨b, hbe⟩
  split
  · rename_i hb1
    have he : chunksRest 16 data.val = [] := by
      rw [← ht]; simpa [Slice.length, hb1] using hbe
    rw [WP.spec_ok, hx1, hbm, padBlocks, he, ite_eq_left rfl, List.append_nil, List.map_map]
  · rename_i hb1
    have he : chunksRest 16 data.val ≠ [] := by
      rw [← ht]; intro h; apply hb1; simp [hbe, Slice.length, h]
    have htl : tail.length < 16 := by
      simp only [Slice.length, ht, chunksRest_length]; omega
    step with Array.index_mut_SliceIndexRangeToUsizeSlice (Std.Array.repeat 16#usize 0#u8)
      { «end» := tail.len } (by scalar_tac) as ⟨s, back, hs, hsl, hback⟩
    step with core.slice.Slice.copy_from_slice.step_spec _ s tail (by rw [hsl]; simp) as ⟨s1, hs1⟩
    step*
    apply WP.spec_mono (hG x1 s2)
    intro r hr
    have hs2 : s2.val = [back tail] := by rw [s2_post, hs1]; simp [Std.Array.to_slice, Std.Array.make]
    have hlast : (back tail).val = tail.val ++ List.replicate (16 - tail.val.length) 0#u8 := by
      have hrep : (Std.Array.repeat 16#usize 0#u8).val = List.replicate 16 0#u8 := rfl
      simp only [Slice.length] at htl
      rw [hback, hrep, List.setSlice!]
      simp only [List.take_zero, List.length_replicate, Nat.sub_zero, Nat.min_eq_left htl.le,
        List.take_of_length_le le_rfl, Nat.zero_add, List.drop_replicate, List.nil_append]
    rw [hr, hs2, List.map_singleton, hx1, hbm, padBlocks, ite_eq_right he, List.map_append, ghashPoly_append,
      List.map_map, List.map_singleton, ← ht, tailBlock, hlast]

theorem blockBE_zero : blockBE (Std.Array.repeat 16#usize 0#u8).val = 0 := by
  apply eq_of_byte_eq; intro i hi
  rw [blockBE, byte_reverseBytes _ hi, loadBytes, byte_leBytesToQuad32 _ (by omega)]
  have hz : (0 : Quad32) = 0#128 := rfl
  simp [Std.Array.repeat, byte, hz, show 15 - i < 16 by omega]
  interval_cases i <;> rfl

/-! ## The counter block -/

/-- A 96-bit IV, then the counter 1, is `compute_iv_BE`'s counter block. -/
theorem load_counter (hLE : Quad32) (l : List U8) (hl : l.length = 12) :
    loadBytes (l ++ [0#u8, 0#u8, 0#u8, 1#u8]) = reverseBytesQuad32 (computeIvBE hLE (l.map (·.bv))) := by
  rw [computeIvBE_96 hLE _ (by simp [hl])]
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  rw [getLsbD_reverseBytesQuad32 _ hk, loadBytes, getLsbD_leBytesToQuad32 _ hk]
  by_cases h : k < 96
  · have hj : ¬ 8 * (15 - k / 8) + k % 8 < 32 := by omega
    have h96 : 8 * (15 - k / 8) + k % 8 - 32 < 96 := by omega
    simp only [BitVec.getLsbD_append, hj, ite_false, BitVec.getLsbD_extractLsb', h96, decide_true, Bool.true_and]
    rw [getLsbD_reverseBytesQuad32 _ (by omega), getLsbD_leBytesToQuad32 _ (by omega)]
    have e1 : (32 + (8 * (15 - k / 8) + k % 8 - 32)) / 8 = 15 - k / 8 := by omega
    have e2 : (32 + (8 * (15 - k / 8) + k % 8 - 32)) % 8 = k % 8 := by omega
    rw [e1, e2, show 8 * (15 - (15 - k / 8)) + k % 8 = k by omega]
    simp only [List.getElem!_eq_getElem?_getD, List.map_append, List.getElem?_append_left
      (by simp [hl]; omega : k / 8 < (l.map (·.bv)).length)]
  · have hl' : (l.map (·.bv)).length = 12 := by simp [hl]
    have hj : 8 * (15 - k / 8) + k % 8 < 32 := by omega
    simp only [BitVec.getLsbD_append, hj, ite_true, List.getElem!_eq_getElem?_getD, List.map_append,
      List.getElem?_append_right (by omega : (l.map (·.bv)).length ≤ k / 8), hl']
    interval_cases k <;> decide

/-- `initial_counter` is `compute_iv_BE`'s counter block for an IV under 2^61
bytes, on a table that hashes as GHASH does under the key `hLE`. -/
theorem initial_counter_spec (hLE : Quad32) {T : Type} (G : mid.aes_gcm.Ghash T) (t : T)
    (hG : GhashFor (polyLE hLE) G t) (iv : Slice U8) (hiv : iv.length < 2 ^ 61) :
    mid.aes_gcm.initial_counter G t iv ⦃ y0 =>
      blockQ y0 = reverseBytesQuad32 (computeIvBE hLE (iv.val.map (·.bv))) ⦄ := by
  unfold mid.aes_gcm.initial_counter
  have hl := Slice.len_val iv
  by_cases h12 : iv.len = 12#usize
  · simp only [h12, ↓reduceIte]
    have h12' : iv.length = 12 := by rw [← hl, h12]; rfl
    step with Array.index_mut_SliceIndexRangeToUsizeSlice (Std.Array.repeat 16#usize 0#u8)
      { «end» := 12#usize } (by scalar_tac) as ⟨s, back, hs, hsl, hback⟩
    step with core.slice.Slice.copy_from_slice.step_spec _ s iv (by rw [hsl, h12']) as ⟨s1, hs1⟩
    step*
    rw [blockQ_load, ← load_counter hLE iv.val h12']
    congr 1
    have hrep : (Std.Array.repeat 16#usize 0#u8).val = List.replicate 16 0#u8 := rfl
    simp only [Slice.length] at h12'
    rw [y0_post, Std.Array.set_val_eq, hback, hs1, hrep, List.setSlice!]
    simp [h12']
  · simp only [h12, ↓reduceIte]
    have h12' : iv.length ≠ 12 := by intro h; apply h12; scalar_tac
    step with ghash_pad_spec (polyLE hLE) G t hG _ iv as ⟨y1, hy1⟩
    step with lengths_spec 0#usize iv.len (by simp) (by rw [hl]; omega) as ⟨a, ha⟩
    step*
    apply WP.spec_mono (hG y1 s)
    intro y0 hy0
    have hs : s.val = [a] := by rw [s_post]; simp [Std.Array.to_slice, Std.Array.make]
    have hx := gcmHash_eq hLE [] iv.val (blockBE y0.val) (by
      rw [hy0, hs, List.map_singleton, hy1, blockBE_zero, toPoly_zero, ghashPoly_cons, ghashPoly_nil, ha,
        padBlocks_nil, List.nil_append, hl, List.length_nil, Nat.mul_zero])
    rw [computeIvBE_other _ _ (by simpa using h12'), List.map_nil] at *
    rw [← hx, reverseBytesQuad32_involutive, blockBE_blockQ, reverseBytesQuad32_involutive]

end rind.armv7
