import Rind.Aarch64.GhashPmull
import Rind.Aarch64.AesModesLow
import Rind.GcmSpec
open Aeneas Aeneas.Std Result rind.vale rind.simd Polynomial
open core.core_arch.arm_shared.neon.generated core.core_arch.aarch64.neon.generated

/-!
# rind's one-pass AES-GCM for short messages on aarch64

`Rind.Aarch64.AesGcmModel`'s `short` is Vale's `gctr_encrypt_LE` and
`gcm_hash`: its counter blocks are `inc32` of the counter block, its rounds
FIPS 197's, `load` and `store` the bytes of a partial block, `KEEP` masks the
keystream past a short ciphertext chunk, and `Aggregate` is the Horner rule,
each group of up to eight blocks multiplied by descending powers of H and
reduced once, the first group short so the last ends with the length block.
-/

local notation "P" => Polynomial (ZMod 2)
local notation "V" => core.core_arch.arm_shared.neon.uint64x2_t

set_option maxRecDepth 20000

namespace rind.aarch64.short

open rind.aarch64.pmull

/-! ## Bytes -/

theorem getLsbD_loadBytes (l : List U8) {k : Nat} (hk : k < 128) :
    (loadBytes l).getLsbD k = (decide (k / 8 < l.length) && (l[k / 8]!).bv.getLsbD (k % 8)) := by
  rw [loadBytes, getLsbD_leBytesToQuad32 _ hk]
  by_cases h : k / 8 < l.length
  · simp [h, List.getElem!_eq_getElem?_getD]
  · simp only [h, decide_false, Bool.false_and, List.getElem!_eq_getElem?_getD, List.getElem?_map,
      List.getElem?_eq_none (show l.length ≤ k / 8 by omega), Option.map_none, Option.getD_none]
    change (0#8).getLsbD (k % 8) = false; simp

/-- Zeros after the bytes load nothing. -/
theorem loadBytes_append_zeros (l : List U8) (n : Nat) : loadBytes (l ++ List.replicate n 0#u8) = loadBytes l := by
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  rw [getLsbD_loadBytes _ hk, getLsbD_loadBytes _ hk]
  by_cases h : k / 8 < l.length
  · simp [h, List.getElem!_eq_getElem?_getD, List.getElem?_append_left h, show k / 8 < l.length + n by omega]
  · simp only [h, decide_false, Bool.false_and, List.length_append, List.length_replicate]
    by_cases h2 : k / 8 < l.length + n
    · simp [List.getElem!_eq_getElem?_getD, List.getElem?_append_right (by omega : l.length ≤ k / 8),
        List.getElem?_replicate, show k / 8 - l.length < n by omega]
    · simp [h2]

theorem getLsbD_swap' (v : BitVec 128) {k : Nat} (hk : k < 128) :
    (swap v).getLsbD k = v.getLsbD ((k + 64) % 128) := by
  rw [getLsbD_swap]; simp [hk]

/-- `reverse`, `REV64` then `EXT` by a doubleword: the block's bytes reversed. -/
theorem reverse_eq (b : BitVec 128) : low.aarch64.ghash.reverse b = ok (reverseBytesQuad32 b) := by
  unfold low.aarch64.ghash.reverse
  rw [vrev64q_u8, bind_ok, vreinterpretq_u64_u8, bind_ok, ext1_eq]
  refine congrArg ok ?_
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  rw [getLsbD_swap' _ hk, getLsbD_ofBytes _ (by omega), getLsbD_reverseBytesQuad32 _ hk, getLsbD_byte _ _ (by omega)]
  congr 1; omega

/-! ## The rounds -/

theorem foldlM_ok {α β : Type} (f : α → β → α) :
    ∀ (l : List β) (a : α), l.foldlM (fun a b => (ok (f a b) : Result α)) a = ok (l.foldl f a)
  | [], _ => rfl
  | b :: l, a => by simp only [List.foldlM_cons, bind_tc_ok, List.foldl_cons]; exact foldlM_ok f l (f a b)

/-- `encrypt` on FIPS 197's round keys is Vale's AES. -/
theorem encrypt_eq (alg : Algorithm) (kw : List (BitVec 32)) (rk : List (BitVec 128))
    (hrk : rk = keyToRoundKeys alg kw) (hl : rk.length = nr alg + 1) (b : BitVec 128) :
    low.aarch64.aes_gcm.encrypt rk b = ok (aesEncrypt alg kw b) := by
  have hnr : 1 ≤ nr alg := by cases alg <;> decide
  rw [low.aarch64.aes_gcm.encrypt, if_neg (by omega)]
  simp only [aesmc_eq, aeseMc, foldlM_ok, bind_ok, bind_tc_ok, aese_eq, veorq_u8, aesEncrypt, ← hrk, evalCipher_fold alg rk hl,
    hl, show nr alg + 1 - 2 = nr alg - 1 by omega, show nr alg + 1 - 1 = nr alg by omega]
  rfl

/-! ## The counter -/

/-- The 32-bit counter `from_be_bytes` reads from a counter block's last four
bytes is the low word of the block they load to, reversed. -/
theorem y0_ctr_eq (j0 : Quad32) (y0 : Std.Array U8 16#usize) (hy : loadBytes y0.val = reverseBytesQuad32 j0) :
    y0.val[12]!.bv ++ y0.val[13]!.bv ++ y0.val[14]!.bv ++ y0.val[15]!.bv = lane32 j0 0 := by
  have hl : y0.val.length = 16 := by simp
  have hj : j0 = reverseBytesQuad32 (loadBytes y0.val) := by rw [hy, reverseBytesQuad32_involutive]
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  rw [getLsbD_lane32, hj, getLsbD_reverseBytesQuad32 _ (by omega), getLsbD_loadBytes _ (by omega), hl]
  simp only [BitVec.getLsbD_append, hk, decide_true, Bool.true_and]
  interval_cases k <;> simp

/-- The counter block for message block `i`: the counter block `j0` with its
low word stepped `i`, in memory order. -/
theorem counter_eq (j0 : Quad32) (y0 : Std.Array U8 16#usize) (hy : loadBytes y0.val = reverseBytesQuad32 j0)
    (i : Nat) :
    let ctr : BitVec 32 := (y0.val[12]!.bv ++ y0.val[13]!.bv ++ y0.val[14]!.bv ++ y0.val[15]!.bv) +
      BitVec.ofNat 32 i
    ofLanes32 (fun l => if l = 3 then
        ctr.extractLsb' 0 8 ++ ctr.extractLsb' 8 8 ++ ctr.extractLsb' 16 8 ++ ctr.extractLsb' 24 8
      else lane32 (loadBytes y0.val) l) = reverseBytesQuad32 (inc32 j0 i) := by
  intro ctr
  have hc : ctr = lane32 j0 0 + BitVec.ofNat 32 i := by simp only [ctr, y0_ctr_eq j0 y0 hy]
  rw [hy, inc32_eq, ← hc]
  generalize ctr = c
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  rw [getLsbD_ofLanes32, getLsbD_reverseBytesQuad32 _ hk]
  simp only [hk, decide_true, Bool.true_and]
  by_cases h3 : k / 32 = 3
  · rw [ite_eq_left h3]
    simp only [BitVec.getLsbD_append, BitVec.getLsbD_extractLsb']
    have : 96 ≤ k := by omega
    interval_cases k <;> simp
  · rw [ite_eq_right h3, getLsbD_lane32, getLsbD_reverseBytesQuad32 _ (by omega)]
    simp only [show k % 32 < 32 by omega, decide_true, Bool.true_and, BitVec.getLsbD_append,
      BitVec.getLsbD_extractLsb', show 32 * (k / 32) + k % 32 = k by omega]
    simp only [show 8 * (15 - k / 8) + k % 8 - 32 < 96 by omega, decide_true, Bool.true_and]
    rw [ite_eq_right (by omega)]
    congr 1; omega

/-! ## Partial blocks -/

theorem loadBytes_nil : loadBytes [] = 0 := by
  apply BitVec.eq_of_getLsbD_eq; intro k hk; rw [getLsbD_loadBytes _ hk]; simp

/-- One of `load`'s moves: `size` more bytes, zero-padded to eight, shifted
past the `pos` bytes the word holds. -/
theorem loadParts_step (b : List U8) (pos size : Nat) (hs : size ≤ 8) (hp : pos + size ≤ b.length)
    (h16 : pos + size ≤ 16) :
    loadBytes (b.take pos) ||| (loadBytes ((b.drop pos).take size ++ List.replicate (8 - size) 0#u8) <<< (8 * pos)) =
      loadBytes (b.take (pos + size)) := by
  rw [loadBytes_append_zeros]
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  rw [BitVec.getLsbD_or, BitVec.getLsbD_shiftLeft, getLsbD_loadBytes _ hk, getLsbD_loadBytes _ hk]
  simp only [hk, decide_true, Bool.true_and, List.length_take, List.length_drop,
    show min pos b.length = pos by omega, show min size (b.length - pos) = size by omega,
    show min (pos + size) b.length = pos + size by omega]
  by_cases h1 : k < 8 * pos
  · have h2 : k / 8 < pos := by omega
    simp [h1, h2, show k / 8 < pos + size by omega, List.getElem!_eq_getElem?_getD, List.getElem?_take]
  · rw [getLsbD_loadBytes _ (by omega)]
    have e1 : (k - 8 * pos) / 8 = k / 8 - pos := by omega
    have e2 : (k - 8 * pos) % 8 = k % 8 := by omega
    simp only [h1, decide_false, Bool.not_false, Bool.true_and, show ¬ k / 8 < pos by omega, Bool.false_and,
      Bool.false_or, e1, e2]
    by_cases h2 : k / 8 < pos + size
    · simp [h2, show k / 8 - pos < size by omega, List.getElem!_eq_getElem?_getD, List.getElem?_take,
        List.getElem?_drop, show pos + (k / 8 - pos) = k / 8 by omega, show k / 8 - pos < b.length - pos by omega]
      rw [List.getElem?_eq_getElem (show k / 8 < b.length by omega)]; rfl
    · simp [h2, show ¬ k / 8 - pos < size by omega]

/-- The sizes `load` and `store` move for a slice of `n` bytes. -/
abbrev moved (n : Nat) (sizes : List Nat) : Nat := (sizes.filter fun s => decide (n &&& s ≠ 0)).sum

theorem moved_cons (n s : Nat) (sizes : List Nat) :
    moved n (s :: sizes) = (if n &&& s ≠ 0 then s else 0) + moved n sizes := by
  by_cases h : n &&& s ≠ 0 <;> simp [moved, List.filter_cons, h]

theorem moved_all : ∀ n < 16, moved n [8, 4, 2, 1] = n := by decide

theorem loadParts_eq (b : List U8) : ∀ (sizes : List Nat) (pos : Nat), (∀ s ∈ sizes, s ≤ 8) →
    pos + moved b.length sizes ≤ b.length → pos + moved b.length sizes ≤ 16 →
    low.aarch64.aes_gcm.loadParts b sizes (loadBytes (b.take pos), pos) =
      (loadBytes (b.take (pos + moved b.length sizes)), pos + moved b.length sizes)
  | [], pos, _, _, _ => by simp [low.aarch64.aes_gcm.loadParts, moved]
  | s :: sizes, pos, hs, h1, h2 => by
    rw [moved_cons] at h1 h2 ⊢
    rw [low.aarch64.aes_gcm.loadParts]
    have hs' : ∀ s ∈ sizes, s ≤ 8 := fun s h => hs s (by simp [h])
    by_cases hc : b.length &&& s ≠ 0
    · rw [ite_eq_left hc]
      rw [ite_eq_left hc] at h1 h2 ⊢
      dsimp only
      rw [loadParts_step b pos s (hs s (by simp)) (by omega) (by omega),
        loadParts_eq b sizes (pos + s) hs' (by omega) (by omega), Nat.add_assoc]
    · rw [ite_eq_right hc]
      rw [ite_eq_right hc, Nat.zero_add] at h1 h2 ⊢
      exact loadParts_eq b sizes pos hs' h1 h2

/-- `load` of up to a block's bytes: them, zero-padded. -/
theorem load_eq (b : List U8) (h : b.length ≤ 16) : low.aarch64.aes_gcm.load b = ok (loadBytes b) := by
  unfold low.aarch64.aes_gcm.load
  by_cases h16 : b.length = 16
  · rw [ite_eq_left h16]
  · rw [ite_eq_right h16]
    have hm := moved_all b.length (by omega)
    have := loadParts_eq b [8, 4, 2, 1] 0 (by simp) (by omega) (by omega)
    rw [List.take_zero, loadBytes_nil, Nat.zero_add, hm, List.take_of_length_le (le_refl _)] at this
    rw [this]

theorem storeBytes_val (v : BitVec 128) : (storeBytes v).val = (leQuad32ToBytes v).map fun b => (⟨b⟩ : U8) := by
  simp [storeBytes, Std.Array.from_val]

theorem length_storeBytes (v : BitVec 128) : (storeBytes v).val.length = 16 := by simp

theorem storeBytes_getElem! (v : BitVec 128) {i : Nat} (hi : i < 16) : ((storeBytes v).val[i]!).bv = byte v i := by
  have h1 : i < (leQuad32ToBytes v).length := by simp [leQuad32ToBytes]; omega
  rw [storeBytes_val, List.getElem!_eq_getElem?_getD, List.getElem?_map, List.getElem?_eq_getElem h1]
  show (leQuad32ToBytes v)[i] = byte v i
  rw [← leQuad32ToBytes_getElem! v hi, List.getElem!_eq_getElem?_getD, List.getElem?_eq_getElem h1]; rfl

/-- One of `store`'s moves: the word's bytes from `pos`, as its shift by
`pos` bytes lays them out first. -/
theorem storeBytes_shift (w : BitVec 128) (pos size : Nat) (hs : size ≤ 8) (h16 : pos + size ≤ 16) :
    ((storeBytes (w >>> (8 * pos))).val.take 8).take size = ((storeBytes w).val.drop pos).take size := by
  rw [List.take_take, show min size 8 = size by omega]
  apply List.ext_getElem (by simp; omega)
  intro j h1 h2
  simp only [storeBytes_val, List.getElem_take, List.getElem_drop, List.getElem_map, leQuad32ToBytes,
    List.getElem_range]
  congr 1
  apply BitVec.eq_of_getLsbD_eq; intro m hm
  simp only [BitVec.getLsbD_extractLsb', BitVec.getLsbD_ushiftRight, hm, decide_true, Bool.true_and]
  congr 1; omega

theorem storeParts_eq (n : Nat) (w : BitVec 128) (bytes : List U8) (hb : bytes.length = n) :
    ∀ (sizes : List Nat) (pos : Nat), (∀ s ∈ sizes, s ≤ 8) → pos + moved n sizes ≤ n → pos + moved n sizes ≤ 16 →
      low.aarch64.aes_gcm.storeParts n w sizes ((storeBytes w).val.take pos ++ bytes.drop pos, pos) =
        ((storeBytes w).val.take (pos + moved n sizes) ++ bytes.drop (pos + moved n sizes), pos + moved n sizes)
  | [], pos, _, _, _ => by simp [low.aarch64.aes_gcm.storeParts, moved]
  | s :: sizes, pos, hs, h1, h2 => by
    rw [moved_cons] at h1 h2 ⊢
    rw [low.aarch64.aes_gcm.storeParts]
    have hs' : ∀ s ∈ sizes, s ≤ 8 := fun s h => hs s (by simp [h])
    by_cases hc : n &&& s ≠ 0
    · rw [ite_eq_left hc]
      rw [ite_eq_left hc] at h1 h2 ⊢
      have hl : ((storeBytes w).val.take pos).length = pos := by rw [List.length_take, length_storeBytes]; omega
      have hd : ((storeBytes w).val.take pos ++ bytes.drop pos).drop (pos + s) = bytes.drop (pos + s) := by
        rw [List.drop_append, List.drop_drop, hl, List.drop_eq_nil_of_le (by rw [hl]; omega), List.nil_append]
        congr 1; omega
      dsimp only
      rw [List.take_left' hl, storeBytes_shift w pos s (hs s (by simp)) (by omega), hd, ← List.take_add]
      have := storeParts_eq n w bytes hb sizes (pos + s) hs' (by omega) (by omega)
      rw [Nat.add_assoc] at this
      exact this
    · rw [ite_eq_right hc]
      rw [ite_eq_right hc, Nat.zero_add] at h1 h2 ⊢
      exact storeParts_eq n w bytes hb sizes pos hs' h1 h2

/-- `store` of a block into up to a block's bytes: its first bytes. -/
theorem store_eq (b : List U8) (v : BitVec 128) (h : b.length ≤ 16) :
    low.aarch64.aes_gcm.store b v = ok ((storeBytes v).val.take b.length) := by
  unfold low.aarch64.aes_gcm.store
  by_cases h16 : b.length = 16
  · rw [ite_eq_left h16, h16, List.take_of_length_le (by simp)]
  · rw [ite_eq_right h16]
    have hm := moved_all b.length (by omega)
    have := storeParts_eq b.length v b rfl [8, 4, 2, 1] 0 (by simp) (by omega) (by omega)
    rw [List.take_zero, List.drop_zero, List.nil_append, Nat.zero_add, hm, List.drop_of_length_le (le_refl _),
      List.append_nil] at this
    rw [this]

theorem keep_eq (n : Nat) (h1 : 1 ≤ n) (h16 : n ≤ 16) :
    (low.aarch64.aes_gcm.KEEP.drop (16 - n)).take 16 = List.replicate n 0xff#u8 ++ List.replicate (16 - n) 0#u8 := by
  interval_cases n <;> decide

/-- `KEEP`'s mask keeps a block's first `n` bytes. -/
theorem mask_eq (v : BitVec 128) (n : Nat) (h16 : n ≤ 16) :
    v &&& loadBytes (List.replicate n 0xff#u8 ++ List.replicate (16 - n) 0#u8) = loadBytes ((storeBytes v).val.take n) := by
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  rw [BitVec.getLsbD_and, getLsbD_loadBytes _ hk, getLsbD_loadBytes _ hk]
  simp only [List.length_append, List.length_replicate, List.length_take, length_storeBytes,
    show n + (16 - n) = 16 by omega, show min n 16 = n by omega, show k / 8 < 16 by omega, decide_true,
    Bool.true_and]
  by_cases h : k / 8 < n
  · simp only [h, decide_true, Bool.true_and, List.getElem!_eq_getElem?_getD, List.getElem?_append_left
      (by simp; omega : k / 8 < (List.replicate n 0xff#u8).length), List.getElem?_replicate, h, ite_true,
      Option.getD_some, List.getElem?_take]
    rw [← List.getElem!_eq_getElem?_getD, storeBytes_getElem! _ (by omega), getLsbD_byte _ _ (by omega),
      show 8 * (k / 8) + k % 8 = k by omega]
    have : (0xff#u8).bv.getLsbD (k % 8) = true := by
      have hk8 : k % 8 < 8 := by omega
      interval_cases (k % 8) <;> decide
    rw [this, Bool.and_true]
  · simp only [h, decide_false, Bool.false_and, Bool.and_false]
    simp only [List.getElem!_eq_getElem?_getD, List.getElem?_append_right
      (by simp; omega : (List.replicate n 0xff#u8).length ≤ k / 8), List.getElem?_replicate, List.length_replicate,
      show k / 8 - n < 16 - n by omega, ite_true, Option.getD_some]
    simp [show (0#u8).bv = 0#8 from rfl]

/-! ## The length block -/

theorem leQuad32ToBytes_leBytesToQuad32 (M : List (BitVec 8)) (h : M.length = 16) :
    leQuad32ToBytes (leBytesToQuad32 M) = M := by
  apply List.ext_getElem (by simp [leQuad32ToBytes, h])
  intro i h1 h2
  have hi : i < 16 := by simpa [leQuad32ToBytes] using h1
  simp only [leQuad32ToBytes, List.getElem_map, List.getElem_range]
  have := byte_leBytesToQuad32 M hi
  rw [byte] at this
  rw [this, List.getElem!_eq_getElem?_getD, List.getElem?_eq_getElem h2, Option.getD_some]

/-- A `u128`'s big-endian bytes, loaded and reversed, are the `u128`. -/
theorem rev_load_be (u : Std.U128) : reverseBytesQuad32 (loadBytes (core.num.U128.to_be_bytes u).val) = u.bv := by
  have hb : (core.num.U128.to_be_bytes u).val.map (·.bv) = u.bv.toBEBytes := by
    simp only [core.num.U128.to_be_bytes, Std.Array.from_val, List.map_map]
    exact List.map_id _
  have hl : u.bv.toLEBytes.length = 16 := by simp
  rw [loadBytes, hb, BitVec.toBEBytes, reverseBytesQuad32,
    leQuad32ToBytes_leBytesToQuad32 _ (by simp [hl]), List.reverse_reverse, leBytesToQuad32,
    BitVec.fromLEBytes_toLEBytes (by decide)]
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp [hk]

end rind.aarch64.short
