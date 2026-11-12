import Rind.ValeBytes
import Rind.Lanes
open Aeneas Aeneas.Std rind.simd

/-!
# FIPS 197's AES on bytes, and its key schedule word by word

Vale's AES spec, `Rind.Vale`, ciphers `quad32`s under a schedule of 32-bit
words. `aesBlock` and `aesHeaderMask` restate it on bytes, as rind's AES and
RFC 9001's header protection take them, and the lemmas below unfold Vale's
`expandKey` one word and one round key at a time, as both targets' vector key
expansions compute them. Nothing here is a target's: `Rind.X86_64.AesKey` and
`Rind.Aarch64.AesKey` prove their translations against it.
-/

namespace rind.vale

/-- FIPS 197's cipher of the 16 bytes `block` under the key bytes `key`, as
Vale's `aes_encrypt_LE` reads both, little-endian. -/
def aesBlock (alg : Algorithm) (key block : List (BitVec 8)) : List (BitVec 8) :=
  leQuad32ToBytes (aesEncrypt alg (seqNat8ToSeqNat32LE key) (leBytesToQuad32 block))

/-- RFC 9001's AES header-protection mask: the first five bytes of the sample's
AES cipher under the header-protection key. -/
def aesHeaderMask (alg : Algorithm) (key sample : List (BitVec 8)) : List (BitVec 8) :=
  (aesBlock alg key sample).take 5

-- RFC 9001's appendix A.2: the client's Initial header-protection mask. Lean
-- evaluates the S-box and `MixColumns` that proofs keep opaque, so these check
-- the specs above against known answers.
#guard aesHeaderMask .AES_128
  ([0x9f, 0x50, 0x44, 0x9e, 0x04, 0xa0, 0xe8, 0x10, 0x28, 0x3a, 0x1e, 0x99, 0x33, 0xad, 0xed, 0xd2] : List (BitVec 8))
  [0xd1, 0xb1, 0xc9, 0x8d, 0xd7, 0x68, 0x9f, 0xb8, 0xec, 0x11, 0xd2, 0x42, 0xb1, 0x23, 0xdc, 0x9b] ==
  [0x43, 0x7b, 0x9a, 0xec, 0x36]

-- FIPS 197's appendix C.3: AES-256 of `00112233...ff`.
#guard aesBlock .AES_256 ((List.range 32).map fun i => BitVec.ofNat 8 i)
  ((List.range 16).map fun i => BitVec.ofNat 8 (17 * i)) ==
  [0x8e, 0xa2, 0xb7, 0xca, 0x51, 0x67, 0x45, 0xbf, 0xea, 0xfc, 0x49, 0x90, 0x4b, 0x49, 0x60, 0x89]

/-- The key length `alg` takes, which rind's AES supports. -/
def KeyLen (alg : Algorithm) (n : Nat) : Prop :=
  (alg = .AES_128 ∧ n = 16) ∨ (alg = .AES_256 ∧ n = 32)

/-! ## Bytes and lanes -/

theorem toLEBytes_eq (v : BitVec 128) : v.toLEBytes = leQuad32ToBytes v := by
  apply List.ext_getElem (by simp [BitVec.toLEBytes_length, leQuad32ToBytes])
  intro i h1 h2
  have hi : i < 16 := by simpa [BitVec.toLEBytes_length] using h1
  apply BitVec.eq_of_getElem_eq; intro j hj
  rw [BitVec.getElem_toLEBytes_eq_getElem v i j h1 hj (by omega)]
  simp [leQuad32ToBytes, BitVec.getElem_extractLsb', BitVec.getLsbD_eq_getElem (show 8 * i + j < 128 by omega)]

theorem byte_ofLanes32 (f : Nat → BitVec 32) {i : Nat} (hi : i < 16) :
    byte (ofLanes32 f) i = wbyte (f (i / 4)) (i % 4) := by
  have := byte_mkfour (f 0) (f 1) (f 2) (f 3) hi
  rw [show ofLanes32 f = mkfour (f 0) (f 1) (f 2) (f 3) from rfl, this]
  congr 1
  by_cases h1 : i < 4 <;> by_cases h2 : i < 8 <;> by_cases h3 : i < 12 <;> simp [h1, h2, h3] <;>
    congr 1 <;> omega

theorem wbyte_lane32 (x : BitVec 128) (j : Nat) {b : Nat} (hb : b < 4) :
    wbyte (lane32 x j) b = byte x (4 * j + b) := by
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp [wbyte, lane32, byte, hk, show 8 * b + k < 32 by omega]
  congr 1; omega

theorem byte_shl8 (x : BitVec 128) (n : Nat) {i : Nat} (hi : i < 16) :
    byte (x <<< (8 * n)) i = if i < n then 0 else byte x (i - n) := by
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp only [byte, BitVec.getLsbD_extractLsb', hk, decide_true, Bool.true_and, BitVec.getLsbD_shiftLeft]
  split_ifs with h
  · simp; omega
  · simp [show 8 * i + k < 128 by omega, show ¬ 8 * i + k < 8 * n by omega, hk]
    congr 1; omega

theorem byte_shl (x : BitVec 128) (m : Nat) (hm : m % 8 = 0) {i : Nat} (hi : i < 16) :
    byte (x <<< m) i = if i < m / 8 then 0 else byte x (i - m / 8) := by
  rw [← byte_shl8 x (m / 8) hi, show 8 * (m / 8) = m by omega]

/-- The next round key after `t` in FIPS 197's schedule, whose first word adds `T`. -/
def nextKey (t : BitVec 128) (T : BitVec 32) : BitVec 128 :=
  let w4 := lane32 t 0 ^^^ T
  let w5 := lane32 t 1 ^^^ w4
  let w6 := lane32 t 2 ^^^ w5
  let w7 := lane32 t 3 ^^^ w6
  mkfour w4 w5 w6 w7

/-- `xor_prefix`'s value: each word XORed with those below it. -/
def xorPrefix (t : BitVec 128) : BitVec 128 := t ^^^ t <<< 32 ^^^ (t ^^^ t <<< 32) <<< 64


/-! ## Vale's key schedule, word by word -/

theorem getElem!_append_left' {α : Type} [Inhabited α] (l1 l2 : List α) {i : Nat} (h : i < l1.length) :
    (l1 ++ l2)[i]! = l1[i]! := by
  simp [List.getElem!_eq_getElem?_getD, List.getElem?_append_left h]

theorem getElem!_append_last {α : Type} [Inhabited α] (l : List α) (x : α) {i : Nat} (h : i = l.length) :
    (l ++ [x])[i]! = x := by
  subst h; simp

theorem expandKey_succ (alg : Algorithm) (key : List (BitVec 32)) (n : Nat) :
    ∃ x, expandKey alg key (n + 1) = expandKey alg key n ++ [x] := by
  simp only [expandKey]; split <;> exact ⟨_, rfl⟩

theorem expandKey_length (alg : Algorithm) (key : List (BitVec 32)) (n : Nat) :
    (expandKey alg key n).length = n := by
  induction n with
  | zero => rfl
  | succ n ih => obtain ⟨x, hx⟩ := expandKey_succ alg key n; rw [hx]; simp [ih]

/-- Word `i` of Vale's key schedule. -/
def keyWord (alg : Algorithm) (key : List (BitVec 32)) (i : Nat) : BitVec 32 :=
  (expandKey alg key (i + 1))[i]!

theorem expandKey_getElem! (alg : Algorithm) (key : List (BitVec 32)) {i n : Nat} (h : i < n) :
    (expandKey alg key n)[i]! = keyWord alg key i := by
  induction n with
  | zero => omega
  | succ n ih =>
    by_cases hin : i = n
    · subst hin; rfl
    · obtain ⟨x, hx⟩ := expandKey_succ alg key n
      rw [hx, getElem!_append_left' _ _ (by rw [expandKey_length]; omega), ih (by omega)]

theorem keyWord_key (alg : Algorithm) (key : List (BitVec 32)) {i : Nat} (h : i < nk alg) :
    keyWord alg key i = key[i]! := by
  unfold keyWord; rw [expandKey]; simp only [h, ite_true]
  exact getElem!_append_last _ _ (by rw [expandKey_length])

theorem keyWord_rec (alg : Algorithm) (key : List (BitVec 32)) {i : Nat} (h : nk alg ≤ i) :
    keyWord alg key i = keyWord alg key (i - nk alg) ^^^
      (if i % nk alg = 0 then subWord (rotWord (keyWord alg key (i - 1))) ^^^ aesRcon (i / nk alg - 1)
       else if nk alg > 6 ∧ i % nk alg = 4 then subWord (keyWord alg key (i - 1))
       else keyWord alg key (i - 1)) := by
  have hnk : 0 < nk alg := by cases alg <;> decide
  conv_lhs => unfold keyWord; rw [expandKey]
  simp only [show ¬ i < nk alg by omega, ite_false]
  rw [getElem!_append_last _ _ (by rw [expandKey_length])]
  simp only [expandKey_getElem! alg key (show i - nk alg < i by omega),
    expandKey_getElem! alg key (show i - 1 < i by omega)]

theorem keyScheduleToRoundKeys_eq (w : List (BitVec 32)) (n : Nat) :
    keyScheduleToRoundKeys n w =
      (List.range n).map fun r => mkfour w[4 * r]! w[4 * r + 1]! w[4 * r + 2]! w[4 * r + 3]! := by
  induction n with
  | zero => rfl
  | succ n ih => rw [keyScheduleToRoundKeys, ih, List.range_succ, List.map_append]; rfl

/-- Round key `r` of Vale's key schedule. -/
def roundKey (alg : Algorithm) (key : List (BitVec 32)) (r : Nat) : Quad32 :=
  mkfour (keyWord alg key (4 * r)) (keyWord alg key (4 * r + 1)) (keyWord alg key (4 * r + 2))
    (keyWord alg key (4 * r + 3))

theorem keyToRoundKeys_eq (alg : Algorithm) (key : List (BitVec 32)) :
    keyToRoundKeys alg key = (List.range (nr alg + 1)).map (roundKey alg key) := by
  rw [keyToRoundKeys, keyScheduleToRoundKeys_eq]
  apply List.map_congr_left
  intro r hr
  simp only [List.mem_range] at hr
  simp only [roundKey, nb, expandKey_getElem! alg key (show 4 * r + 3 < 4 * (nr alg + 1) by omega),
    expandKey_getElem! alg key (show 4 * r + 2 < 4 * (nr alg + 1) by omega),
    expandKey_getElem! alg key (show 4 * r + 1 < 4 * (nr alg + 1) by omega),
    expandKey_getElem! alg key (show 4 * r < 4 * (nr alg + 1) by omega)]

theorem lane32_mkfour (w0 w1 w2 w3 : BitVec 32) :
    lane32 (mkfour w0 w1 w2 w3) 0 = w0 ∧ lane32 (mkfour w0 w1 w2 w3) 1 = w1 ∧
      lane32 (mkfour w0 w1 w2 w3) 2 = w2 ∧ lane32 (mkfour w0 w1 w2 w3) 3 = w3 := by
  refine ⟨?_, ?_, ?_, ?_⟩ <;> apply eq_of_wbyte_eq <;> intro b hb <;>
    rw [wbyte_lane32 _ _ hb, byte_mkfour _ _ _ _ (by omega)] <;> simp <;>
    interval_cases b <;> simp


theorem roundKey128_succ (key : List (BitVec 32)) (r : Nat) :
    roundKey .AES_128 key (r + 1) = nextKey (roundKey .AES_128 key r)
      (subWord (rotWord (keyWord .AES_128 key (4 * r + 3))) ^^^ aesRcon r) := by
  obtain ⟨l0, l1, l2, l3⟩ := lane32_mkfour (keyWord .AES_128 key (4 * r)) (keyWord .AES_128 key (4 * r + 1))
    (keyWord .AES_128 key (4 * r + 2)) (keyWord .AES_128 key (4 * r + 3))
  simp only [roundKey, nextKey, l0, l1, l2, l3]
  have k4 := keyWord_rec .AES_128 key (i := 4 * (r + 1)) (by show 4 ≤ _; omega)
  have k5 := keyWord_rec .AES_128 key (i := 4 * (r + 1) + 1) (by show 4 ≤ _; omega)
  have k6 := keyWord_rec .AES_128 key (i := 4 * (r + 1) + 2) (by show 4 ≤ _; omega)
  have k7 := keyWord_rec .AES_128 key (i := 4 * (r + 1) + 3) (by show 4 ≤ _; omega)
  have hnk : nk .AES_128 = 4 := rfl
  rw [hnk] at k4 k5 k6 k7
  rw [ite_eq_left (by omega), show 4 * (r + 1) / 4 - 1 = r by omega, show 4 * (r + 1) - 4 = 4 * r by omega,
    show 4 * (r + 1) - 1 = 4 * r + 3 by omega] at k4
  rw [ite_eq_right (by omega), ite_eq_right (by omega), show 4 * (r + 1) + 1 - 4 = 4 * r + 1 by omega,
    show 4 * (r + 1) + 1 - 1 = 4 * (r + 1) by omega] at k5
  rw [ite_eq_right (by omega), ite_eq_right (by omega), show 4 * (r + 1) + 2 - 4 = 4 * r + 2 by omega,
    show 4 * (r + 1) + 2 - 1 = 4 * (r + 1) + 1 by omega] at k6
  rw [ite_eq_right (by omega), ite_eq_right (by omega), show 4 * (r + 1) + 3 - 4 = 4 * r + 3 by omega,
    show 4 * (r + 1) + 3 - 1 = 4 * (r + 1) + 2 by omega] at k7
  rw [k7, k6, k5, k4]

theorem getElem!_set {α : Type} [Inhabited α] (l : List α) {i : Nat} (j : Nat) (x : α) (hi : i < l.length) :
    (l.set i x)[j]! = if i = j then x else l[j]! := by
  simp only [List.getElem!_eq_getElem?_getD, List.getElem?_set]
  split <;> simp_all

theorem eq_range_map {α : Type} [Inhabited α] (l : List α) (f : Nat → α) {n : Nat} (hl : l.length = n)
    (h : ∀ r < n, l[r]! = f r) : l = (List.range n).map f := by
  apply List.ext_getElem (by simp [hl])
  intro r h1 h2
  have := h r (by omega)
  rw [List.getElem!_eq_getElem?_getD, List.getElem?_eq_getElem h1] at this
  simpa using this


/-! ## Key bytes as words -/

theorem wbyte_seqNat8ToSeqNat32LE (l : List (BitVec 8)) {i b : Nat} (hi : i < l.length / 4) (hb : b < 4) :
    wbyte (seqNat8ToSeqNat32LE l)[i]! b = l[4 * i + b]! := by
  rw [seqNat8ToSeqNat32LE, getElem!_range_map _ hi]
  apply BitVec.eq_of_getLsbD_eq; intro j hj
  simp only [wbyte, BitVec.getLsbD_extractLsb', hj, decide_true, Bool.true_and, BitVec.getLsbD_setWidth,
    show 8 * b + j < 32 by omega]
  have := BitVec.fromLEBytes_getElem! ((l.drop (4 * i)).take 4) (8 * b + j)
  rw [BitVec.getElem!_eq_testBit_toNat] at this
  rw [← BitVec.testBit_toNat, this, show (8 * b + j) / 8 = b by omega, show (8 * b + j) % 8 = j by omega]
  simp only [List.getElem!_eq_getElem?_getD, List.getElem?_take, show b < 4 by omega, ite_true,
    List.getElem?_drop]
  rfl

theorem load_eq_mkfour (l : List (BitVec 8)) (hl : l.length = 16) :
    leBytesToQuad32 l = mkfour (seqNat8ToSeqNat32LE l)[0]! (seqNat8ToSeqNat32LE l)[1]!
      (seqNat8ToSeqNat32LE l)[2]! (seqNat8ToSeqNat32LE l)[3]! := by
  apply eq_of_byte_eq; intro i hi
  rw [byte_leBytesToQuad32 _ hi, byte_mkfour _ _ _ _ hi]
  have hb : i % 4 < 4 := Nat.mod_lt _ (by decide)
  by_cases h1 : i < 4
  · rw [ite_eq_left h1, wbyte_seqNat8ToSeqNat32LE l (i := 0) (by omega) hb]; congr 1; omega
  by_cases h2 : i < 8
  · rw [ite_eq_right h1, ite_eq_left h2, wbyte_seqNat8ToSeqNat32LE l (i := 1) (by omega) hb]; congr 1; omega
  by_cases h3 : i < 12
  · rw [ite_eq_right h1, ite_eq_right h2, ite_eq_left h3, wbyte_seqNat8ToSeqNat32LE l (i := 2) (by omega) hb]; congr 1; omega
  · rw [ite_eq_right h1, ite_eq_right h2, ite_eq_right h3, wbyte_seqNat8ToSeqNat32LE l (i := 3) (by omega) hb]; congr 1; omega

theorem seqNat8ToSeqNat32LE_length (l : List (BitVec 8)) :
    (seqNat8ToSeqNat32LE l).length = l.length / 4 := by simp [seqNat8ToSeqNat32LE]


theorem load_words (l l' : List (BitVec 8)) (q : Nat) (hl : 16 * q + 16 ≤ l.length)
    (hl' : ∀ i < 16, l'[i]! = l[16 * q + i]!) :
    leBytesToQuad32 l' = mkfour (seqNat8ToSeqNat32LE l)[4 * q]! (seqNat8ToSeqNat32LE l)[4 * q + 1]!
      (seqNat8ToSeqNat32LE l)[4 * q + 2]! (seqNat8ToSeqNat32LE l)[4 * q + 3]! := by
  apply eq_of_byte_eq; intro i hi
  rw [byte_leBytesToQuad32 _ hi, byte_mkfour _ _ _ _ hi, hl' i hi]
  have hb : i % 4 < 4 := Nat.mod_lt _ (by decide)
  by_cases h1 : i < 4
  · rw [ite_eq_left h1, wbyte_seqNat8ToSeqNat32LE l (i := 4 * q) (by omega) hb]; congr 1; omega
  by_cases h2 : i < 8
  · rw [ite_eq_right h1, ite_eq_left h2, wbyte_seqNat8ToSeqNat32LE l (i := 4 * q + 1) (by omega) hb]; congr 1; omega
  by_cases h3 : i < 12
  · rw [ite_eq_right h1, ite_eq_right h2, ite_eq_left h3, wbyte_seqNat8ToSeqNat32LE l (i := 4 * q + 2) (by omega) hb]
    congr 1; omega
  · rw [ite_eq_right h1, ite_eq_right h2, ite_eq_right h3, wbyte_seqNat8ToSeqNat32LE l (i := 4 * q + 3) (by omega) hb]
    congr 1; omega

theorem roundKey256_even (key : List (BitVec 32)) (s : Nat) :
    roundKey .AES_256 key (2 * s + 2) = nextKey (roundKey .AES_256 key (2 * s))
      (subWord (rotWord (lane32 (roundKey .AES_256 key (2 * s + 1)) 3)) ^^^ aesRcon s) := by
  obtain ⟨l0, l1, l2, l3⟩ := lane32_mkfour (keyWord .AES_256 key (4 * (2 * s)))
    (keyWord .AES_256 key (4 * (2 * s) + 1)) (keyWord .AES_256 key (4 * (2 * s) + 2))
    (keyWord .AES_256 key (4 * (2 * s) + 3))
  have m3 := (lane32_mkfour (keyWord .AES_256 key (4 * (2 * s + 1)))
    (keyWord .AES_256 key (4 * (2 * s + 1) + 1)) (keyWord .AES_256 key (4 * (2 * s + 1) + 2))
    (keyWord .AES_256 key (4 * (2 * s + 1) + 3))).2.2.2
  simp only [roundKey, nextKey, l0, l1, l2, l3, m3]
  have hnk : nk .AES_256 = 8 := rfl
  have k0 := keyWord_rec .AES_256 key (i := 4 * (2 * s + 2)) (by rw [hnk]; omega)
  have k1 := keyWord_rec .AES_256 key (i := 4 * (2 * s + 2) + 1) (by rw [hnk]; omega)
  have k2 := keyWord_rec .AES_256 key (i := 4 * (2 * s + 2) + 2) (by rw [hnk]; omega)
  have k3 := keyWord_rec .AES_256 key (i := 4 * (2 * s + 2) + 3) (by rw [hnk]; omega)
  rw [hnk] at k0 k1 k2 k3
  rw [ite_eq_left (by omega), show 4 * (2 * s + 2) / 8 - 1 = s by omega,
    show 4 * (2 * s + 2) - 8 = 4 * (2 * s) by omega,
    show 4 * (2 * s + 2) - 1 = 4 * (2 * s + 1) + 3 by omega] at k0
  rw [ite_eq_right (by omega), ite_eq_right (by omega), show 4 * (2 * s + 2) + 1 - 8 = 4 * (2 * s) + 1 by omega,
    show 4 * (2 * s + 2) + 1 - 1 = 4 * (2 * s + 2) by omega] at k1
  rw [ite_eq_right (by omega), ite_eq_right (by omega), show 4 * (2 * s + 2) + 2 - 8 = 4 * (2 * s) + 2 by omega,
    show 4 * (2 * s + 2) + 2 - 1 = 4 * (2 * s + 2) + 1 by omega] at k2
  rw [ite_eq_right (by omega), ite_eq_right (by omega), show 4 * (2 * s + 2) + 3 - 8 = 4 * (2 * s) + 3 by omega,
    show 4 * (2 * s + 2) + 3 - 1 = 4 * (2 * s + 2) + 2 by omega] at k3
  rw [k3, k2, k1, k0]

theorem roundKey256_odd (key : List (BitVec 32)) (s : Nat) :
    roundKey .AES_256 key (2 * s + 3) = nextKey (roundKey .AES_256 key (2 * s + 1))
      (subWord (lane32 (roundKey .AES_256 key (2 * s + 2)) 3)) := by
  obtain ⟨l0, l1, l2, l3⟩ := lane32_mkfour (keyWord .AES_256 key (4 * (2 * s + 1)))
    (keyWord .AES_256 key (4 * (2 * s + 1) + 1)) (keyWord .AES_256 key (4 * (2 * s + 1) + 2))
    (keyWord .AES_256 key (4 * (2 * s + 1) + 3))
  have m3 := (lane32_mkfour (keyWord .AES_256 key (4 * (2 * s + 2)))
    (keyWord .AES_256 key (4 * (2 * s + 2) + 1)) (keyWord .AES_256 key (4 * (2 * s + 2) + 2))
    (keyWord .AES_256 key (4 * (2 * s + 2) + 3))).2.2.2
  simp only [roundKey, nextKey, l0, l1, l2, l3, m3]
  have hnk : nk .AES_256 = 8 := rfl
  have k0 := keyWord_rec .AES_256 key (i := 4 * (2 * s + 3)) (by rw [hnk]; omega)
  have k1 := keyWord_rec .AES_256 key (i := 4 * (2 * s + 3) + 1) (by rw [hnk]; omega)
  have k2 := keyWord_rec .AES_256 key (i := 4 * (2 * s + 3) + 2) (by rw [hnk]; omega)
  have k3 := keyWord_rec .AES_256 key (i := 4 * (2 * s + 3) + 3) (by rw [hnk]; omega)
  rw [hnk] at k0 k1 k2 k3
  rw [ite_eq_right (by omega), ite_eq_left (by omega), show 4 * (2 * s + 3) - 8 = 4 * (2 * s + 1) by omega,
    show 4 * (2 * s + 3) - 1 = 4 * (2 * s + 2) + 3 by omega] at k0
  rw [ite_eq_right (by omega), ite_eq_right (by omega), show 4 * (2 * s + 3) + 1 - 8 = 4 * (2 * s + 1) + 1 by omega,
    show 4 * (2 * s + 3) + 1 - 1 = 4 * (2 * s + 3) by omega] at k1
  rw [ite_eq_right (by omega), ite_eq_right (by omega), show 4 * (2 * s + 3) + 2 - 8 = 4 * (2 * s + 1) + 2 by omega,
    show 4 * (2 * s + 3) + 2 - 1 = 4 * (2 * s + 3) + 1 by omega] at k2
  rw [ite_eq_right (by omega), ite_eq_right (by omega), show 4 * (2 * s + 3) + 3 - 8 = 4 * (2 * s + 1) + 3 by omega,
    show 4 * (2 * s + 3) + 3 - 1 = 4 * (2 * s + 3) + 2 by omega] at k3
  rw [k3, k2, k1, k0]

/-- A round key whose first word adds `T`: its words, each XORed with those
below it, then `T` added to all four. -/
theorem nextKey_eq (t : BitVec 128) (T : BitVec 32) :
    xorPrefix t ^^^ ofLanes32 (fun _ => T) = nextKey t T := by
  apply eq_of_byte_eq
  intro i hi
  interval_cases i <;>
    simp (config := { decide := true }) [xorPrefix, byte_xor, byte_shl, byte_ofLanes32, nextKey, byte_mkfour,
      wbyte_xor, wbyte_lane32, BitVec.xor_assoc]

/-- `SubBytes` and `ShiftRows` of four equal words: `SubWord` of each, since
`ShiftRows` moves nothing. -/
theorem subBytes_shiftRows_dup (w : BitVec 32) :
    subBytes (shiftRows (ofLanes32 fun _ => w)) = ofLanes32 fun _ => subWord w := by
  apply eq_of_byte_eq
  intro i hi
  interval_cases i <;>
    simp (config := { decide := true }) [byte_subBytes, byte_shiftRows, byte_ofLanes32, wbyte_subWord]

end rind.vale
