module
public import Rind.Vale
public import Mathlib.Tactic.IntervalCases
@[expose] public section

/-! How Vale's byte and `quad32` conversions in `Rind.Vale` read bits. -/

namespace rind.vale

theorem getLsbD_leBytesToQuad32 (l : List (BitVec 8)) {k : Nat} (hk : k < 128) :
    (leBytesToQuad32 l).getLsbD k = (l[k / 8]!).getLsbD (k % 8) := by
  unfold leBytesToQuad32
  rw [BitVec.getLsbD_setWidth, decide_eq_true hk, Bool.true_and]
  have := BitVec.fromLEBytes_getElem! l k
  rw [BitVec.getElem!_eq_testBit_toNat] at this
  rw [← BitVec.testBit_toNat, this]
  rfl

theorem getElem!_range_map {α : Type} [Inhabited α] (f : Nat → α) {n i : Nat} (h : i < n) :
    ((List.range n).map f)[i]! = f i := by
  rw [List.getElem!_eq_getElem?_getD]; simp [h]

theorem getLsbD_byte (q : Quad32) (i : Nat) {j : Nat} (hj : j < 8) :
    (byte q i).getLsbD j = q.getLsbD (8 * i + j) := by
  simp [byte, BitVec.getLsbD_extractLsb', hj]

theorem getLsbD_ofBytes (f : Nat → BitVec 8) {k : Nat} (hk : k < 128) :
    (ofBytes f).getLsbD k = (f (k / 8)).getLsbD (k % 8) := by
  rw [ofBytes, getLsbD_leBytesToQuad32 _ hk, getElem!_range_map _ (by omega)]

theorem leQuad32ToBytes_getElem! (q : Quad32) {i : Nat} (h : i < 16) :
    (leQuad32ToBytes q)[i]! = byte q i := getElem!_range_map _ h

theorem getLsbD_reverseBytesQuad32 (q : Quad32) {k : Nat} (hk : k < 128) :
    (reverseBytesQuad32 q).getLsbD k = q.getLsbD (8 * (15 - k / 8) + k % 8) := by
  rw [reverseBytesQuad32, getLsbD_leBytesToQuad32 _ hk, List.getElem!_eq_getElem?_getD,
    List.getElem?_reverse (by simp [leQuad32ToBytes]; omega)]
  have : (leQuad32ToBytes q).length - 1 - k / 8 = 15 - k / 8 := by simp [leQuad32ToBytes]
  rw [this, ← List.getElem!_eq_getElem?_getD, leQuad32ToBytes_getElem! q (by omega),
    getLsbD_byte _ _ (by omega)]

theorem reverseBytesQuad32_involutive (q : Quad32) : reverseBytesQuad32 (reverseBytesQuad32 q) = q := by
  apply BitVec.eq_of_getLsbD_eq
  intro k hk
  rw [getLsbD_reverseBytesQuad32 _ hk, getLsbD_reverseBytesQuad32 _ (by omega)]
  congr 1; omega

/-! ## Bytes of vectors and words -/

/-- Byte `b` of a word, least significant first. -/
def wbyte (w : BitVec 32) (b : Nat) : BitVec 8 := w.extractLsb' (8 * b) 8

theorem eq_of_byte_eq {x y : Quad32} (h : ∀ i < 16, byte x i = byte y i) : x = y := by
  apply BitVec.eq_of_getLsbD_eq
  intro k hk
  have := congrArg (·.getLsbD (k % 8)) (h (k / 8) (by omega))
  simp only [getLsbD_byte _ _ (show k % 8 < 8 by omega)] at this
  rwa [show 8 * (k / 8) + k % 8 = k by omega] at this

theorem eq_of_wbyte_eq {x y : BitVec 32} (h : ∀ i < 4, wbyte x i = wbyte y i) : x = y := by
  apply BitVec.eq_of_getLsbD_eq
  intro k hk
  have := congrArg (·.getLsbD (k % 8)) (h (k / 8) (by omega))
  simp only [wbyte, BitVec.getLsbD_extractLsb', show k % 8 < 8 by omega, decide_true,
    Bool.true_and] at this
  rwa [show 8 * (k / 8) + k % 8 = k by omega] at this

theorem byte_xor (x y : Quad32) (i : Nat) : byte (x ^^^ y) i = byte x i ^^^ byte y i := by
  apply BitVec.eq_of_getLsbD_eq; intro j hj; simp [byte, hj]

theorem wbyte_xor (x y : BitVec 32) (i : Nat) : wbyte (x ^^^ y) i = wbyte x i ^^^ wbyte y i := by
  apply BitVec.eq_of_getLsbD_eq; intro j hj; simp [wbyte, hj]

theorem byte_ofBytes (f : Nat → BitVec 8) {i : Nat} (hi : i < 16) : byte (ofBytes f) i = f i := by
  apply BitVec.eq_of_getLsbD_eq; intro j hj
  rw [getLsbD_byte _ _ hj, getLsbD_ofBytes _ (by omega)]
  congr 2 <;> omega

theorem byte_leBytesToQuad32 (l : List (BitVec 8)) {i : Nat} (hi : i < 16) :
    byte (leBytesToQuad32 l) i = l[i]! := by
  apply BitVec.eq_of_getLsbD_eq; intro j hj
  rw [getLsbD_byte _ _ hj, getLsbD_leBytesToQuad32 _ (by omega)]
  congr 2 <;> omega

theorem byte_mkfour (w0 w1 w2 w3 : BitVec 32) {i : Nat} (hi : i < 16) :
    byte (mkfour w0 w1 w2 w3) i =
      wbyte (if i < 4 then w0 else if i < 8 then w1 else if i < 12 then w2 else w3) (i % 4) := by
  apply BitVec.eq_of_getLsbD_eq; intro j hj
  simp only [byte, mkfour, wbyte, BitVec.getLsbD_extractLsb', hj, decide_true, Bool.true_and,
    BitVec.getLsbD_append]
  by_cases h1 : i < 4 <;> by_cases h2 : i < 8 <;> by_cases h3 : i < 12 <;> simp_all <;>
    (try split_ifs) <;> first | omega | (congr 1; omega)

theorem byte_subBytes (q : Quad32) {i : Nat} (hi : i < 16) : byte (subBytes q) i = sbox (byte q i) :=
  byte_ofBytes _ hi

theorem byte_shiftRows (q : Quad32) {i : Nat} (hi : i < 16) :
    byte (shiftRows q) i = byte q (i % 4 + 4 * ((i / 4 + i % 4) % 4)) :=
  byte_ofBytes _ hi

theorem wbyte_subWord (w : BitVec 32) {b : Nat} (hb : b < 4) : wbyte (subWord w) b = sbox (wbyte w b) := by
  apply BitVec.eq_of_getLsbD_eq; intro j hj
  simp only [wbyte, subWord, BitVec.getLsbD_extractLsb', BitVec.getLsbD_append, hj, decide_true,
    Bool.true_and]
  interval_cases b <;> interval_cases j <;> simp

theorem wbyte_rotWord (w : BitVec 32) {b : Nat} (hb : b < 4) :
    wbyte (rotWord w) b = wbyte w ((b + 1) % 4) := by
  apply BitVec.eq_of_getLsbD_eq; intro j hj
  simp only [wbyte, rotWord, BitVec.getLsbD_extractLsb', hj, decide_true, Bool.true_and,
    BitVec.getLsbD_rotateRight]
  interval_cases b <;> interval_cases j <;> simp

/-- Vale's `sub_bytes` and `shift_rows`, a byte map and a byte permutation, commute. -/
theorem subBytes_shiftRows (q : Quad32) : subBytes (shiftRows q) = shiftRows (subBytes q) := by
  apply eq_of_byte_eq; intro i hi
  rw [byte_subBytes _ hi, byte_shiftRows _ hi, byte_shiftRows _ hi, byte_subBytes _ (by omega)]

end rind.vale
