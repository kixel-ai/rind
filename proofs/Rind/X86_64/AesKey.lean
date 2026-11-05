import Rind.X86_64.AesNi
import Rind.ValeBytes
open Aeneas Aeneas.Std Result rind.vale rind.simd

namespace rind.x86_64

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

theorem xor_prefix_eq (t : BitVec 128) : low.x86_64.aes.xor_prefix t = ok (xorPrefix t) := by
  have e4 : (4#i32).bv.toNat % 256 = 4 := by decide
  have e8 : (8#i32).bv.toNat % 256 = 8 := by decide
  simp only [low.x86_64.aes.xor_prefix, core.core_arch.x86.sse2._mm_slli_si128,
    core.core_arch.x86.sse2._mm_xor_si128, bind_ok, e4, e8, show ¬ (4 > 15) by omega,
    show ¬ (8 > 15) by omega, ite_false, xorPrefix]

/-- `sub_rot_word`'s value. -/
def subRotWord (t : BitVec 128) (rcon : Std.I32) : BitVec 128 :=
  subBytes (shiftRows (ofBytes fun i =>
    if (byte (leBytesToQuad32 [(13#i8).bv, (14#i8).bv, (15#i8).bv, (12#i8).bv, (13#i8).bv, (14#i8).bv,
      (15#i8).bv, (12#i8).bv, (13#i8).bv, (14#i8).bv, (15#i8).bv, (12#i8).bv, (13#i8).bv, (14#i8).bv,
      (15#i8).bv, (12#i8).bv]) i).msb then 0
    else byte t ((byte (leBytesToQuad32 [(13#i8).bv, (14#i8).bv, (15#i8).bv, (12#i8).bv, (13#i8).bv,
      (14#i8).bv, (15#i8).bv, (12#i8).bv, (13#i8).bv, (14#i8).bv, (15#i8).bv, (12#i8).bv, (13#i8).bv,
      (14#i8).bv, (15#i8).bv, (12#i8).bv]) i).toNat % 16))) ^^^ ofLanes32 fun _ => rcon.bv

theorem sub_rot_word_eq (t : BitVec 128) (rcon : Std.I32) :
    low.x86_64.aes.sub_rot_word t rcon = ok (subRotWord t rcon) := by
  simp only [low.x86_64.aes.sub_rot_word, core.core_arch.x86.sse2._mm_setr_epi8,
    core.core_arch.x86.ssse3._mm_shuffle_epi8, core.core_arch.x86.sse2._mm_set1_epi32,
    core.core_arch.x86.aes._mm_aesenclast_si128, bind_ok, subRotWord]

/-- A round key whose first word takes `RotWord`, `SubWord`, and the round constant. -/
theorem rot_step (t u : BitVec 128) (rcon : Std.I32) :
    xorPrefix t ^^^ subRotWord u rcon = nextKey t (subWord (rotWord (lane32 u 3)) ^^^ rcon.bv) := by
  apply eq_of_byte_eq
  intro i hi
  interval_cases i <;>
    simp (config := { decide := true }) [xorPrefix, subRotWord, byte_xor, byte_shl, byte_ofLanes32,
      byte_subBytes, byte_shiftRows, byte_ofBytes, byte_leBytesToQuad32, nextKey, byte_mkfour, wbyte_xor,
      wbyte_subWord, wbyte_rotWord, wbyte_lane32, BitVec.xor_assoc]

/-- `aes256_expand`'s second key of a pair: the vector its first word takes
`SubWord` alone from. -/
theorem sub_step (a b : BitVec 128) :
    (do
      let w ← core.core_arch.x86.sse2._mm_shuffle_epi32 255#i32 a
      let z ← core.core_arch.x86.sse2._mm_setzero_si128
      core.core_arch.x86.aes._mm_aesenclast_si128 w z) >>= (fun sub => ok (xorPrefix b ^^^ sub)) =
      ok (nextKey b (subWord (lane32 a 3))) := by
  have e : (255#i32).bv.toNat = 255 := by decide
  simp only [core.core_arch.x86.sse2._mm_shuffle_epi32, core.core_arch.x86.sse2._mm_setzero_si128,
    core.core_arch.x86.aes._mm_aesenclast_si128, bind_ok, e]
  simp only [bind_tc_ok, show ∀ x : BitVec 128, x ^^^ (0 : BitVec 128) = x from fun x => BitVec.xor_zero]
  congr 1
  apply eq_of_byte_eq
  intro i hi
  interval_cases i <;>
    simp (config := { decide := true }) [xorPrefix, byte_xor, byte_shl, byte_ofLanes32, byte_subBytes,
      byte_shiftRows, nextKey, byte_mkfour, wbyte_xor, wbyte_subWord, wbyte_lane32, BitVec.xor_assoc]

/-! ## Vale's key schedule, word by word -/

theorem getElem!_append_left' {α : Type} [Inhabited α] (l1 l2 : List α) {i : Nat} (h : i < l1.length) :
    (l1 ++ l2)[i]! = l1[i]! := by
  simp [List.getElem!_eq_getElem?_getD, List.getElem?_append_left h]

theorem getElem!_append_last {α : Type} [Inhabited α] (l : List α) (x : α) {i : Nat} (h : i = l.length) :
    (l ++ [x])[i]! = x := by
  subst h; simp [List.getElem!_eq_getElem?_getD]

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

theorem rcon_eq {r : Nat} (hr : r < 10) : aesRcon r = (low.x86_64.aes.RCON[r]!).bv := by
  interval_cases r <;> decide

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
  rw [if_pos (by omega), show 4 * (r + 1) / 4 - 1 = r by omega, show 4 * (r + 1) - 4 = 4 * r by omega,
    show 4 * (r + 1) - 1 = 4 * r + 3 by omega] at k4
  rw [if_neg (by omega), if_neg (by omega), show 4 * (r + 1) + 1 - 4 = 4 * r + 1 by omega,
    show 4 * (r + 1) + 1 - 1 = 4 * (r + 1) by omega] at k5
  rw [if_neg (by omega), if_neg (by omega), show 4 * (r + 1) + 2 - 4 = 4 * r + 2 by omega,
    show 4 * (r + 1) + 2 - 1 = 4 * (r + 1) + 1 by omega] at k6
  rw [if_neg (by omega), if_neg (by omega), show 4 * (r + 1) + 3 - 4 = 4 * r + 3 by omega,
    show 4 * (r + 1) + 3 - 1 = 4 * (r + 1) + 2 by omega] at k7
  rw [k7, k6, k5, k4]

theorem rcon_drop {r : Nat} (hr : r < 10) :
    low.x86_64.aes.RCON.drop r = low.x86_64.aes.RCON[r]! :: low.x86_64.aes.RCON.drop (r + 1) := by
  interval_cases r <;> rfl

theorem aes128_loop (key : List (BitVec 32)) (n : Nat) (hn : n ≤ 10) :
    low.x86_64.aes.aes128_expand_loop (roundKey .AES_128 key (10 - n)) (low.x86_64.aes.RCON.drop (10 - n)) =
      ok ((List.range' (11 - n) n).map (roundKey .AES_128 key)) := by
  induction n with
  | zero => simp [low.x86_64.aes.RCON, low.x86_64.aes.aes128_expand_loop]
  | succ n ih =>
    rw [rcon_drop (by omega), show 10 - (n + 1) + 1 = 10 - n by omega, low.x86_64.aes.aes128_expand_loop,
      xor_prefix_eq, sub_rot_word_eq]
    simp only [bind_ok, core.core_arch.x86.sse2._mm_xor_si128, rot_step]
    have hk : nextKey (roundKey .AES_128 key (10 - (n + 1)))
        (subWord (rotWord (lane32 (roundKey .AES_128 key (10 - (n + 1))) 3)) ^^^
          (low.x86_64.aes.RCON[10 - (n + 1)]!).bv) = roundKey .AES_128 key (10 - n) := by
      rw [show 10 - n = 10 - (n + 1) + 1 by omega, roundKey128_succ, ← rcon_eq (by omega)]
      simp only [roundKey, (lane32_mkfour _ _ _ _).2.2.2]
    rw [hk, ih (by omega), show 11 - (n + 1) = 10 - n by omega, List.range'_succ,
      show 10 - n + 1 = 11 - n by omega]
    simp only [bind_ok, List.map_cons]

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
  · rw [if_pos h1, wbyte_seqNat8ToSeqNat32LE l (i := 0) (by omega) hb]; congr 1; omega
  by_cases h2 : i < 8
  · rw [if_neg h1, if_pos h2, wbyte_seqNat8ToSeqNat32LE l (i := 1) (by omega) hb]; congr 1; omega
  by_cases h3 : i < 12
  · rw [if_neg h1, if_neg h2, if_pos h3, wbyte_seqNat8ToSeqNat32LE l (i := 2) (by omega) hb]; congr 1; omega
  · rw [if_neg h1, if_neg h2, if_neg h3, wbyte_seqNat8ToSeqNat32LE l (i := 3) (by omega) hb]; congr 1; omega

theorem seqNat8ToSeqNat32LE_length (l : List (BitVec 8)) :
    (seqNat8ToSeqNat32LE l).length = l.length / 4 := by simp [seqNat8ToSeqNat32LE]

/-- The AES-128 key `key` expands to FIPS 197's round keys, each its 16 bytes in order. -/
theorem aes128_expand_spec (key : Std.Array Std.U8 16#usize)
    (out : Std.Array core.core_arch.x86.__m128i 11#usize) :
    ∃ rk, low.x86_64.aes.aes128_expand key out = ok rk ∧
      rk.val = keyToRoundKeys .AES_128 (seqNat8ToSeqNat32LE (key.val.map (·.bv))) := by
  set kw := seqNat8ToSeqNat32LE (key.val.map (·.bv))
  have hl : (key.val.map (·.bv)).length = 16 := by simp
  have h0 : low.x86_64.aes.load key.val = roundKey .AES_128 kw 0 := by
    simp only [roundKey, keyWord_key .AES_128 kw (show 0 < 4 by decide),
      keyWord_key .AES_128 kw (show 1 < 4 by decide), keyWord_key .AES_128 kw (show 2 < 4 by decide),
      keyWord_key .AES_128 kw (show 3 < 4 by decide), Nat.mul_zero, Nat.zero_add]
    exact load_eq_mkfour _ hl
  have hloop := aes128_loop kw 10 le_rfl
  simp only [Nat.sub_self, List.drop_zero] at hloop
  unfold low.x86_64.aes.aes128_expand
  simp only [h0, hloop, bind_ok]
  rw [dif_pos (by simp)]
  refine ⟨_, rfl, ?_⟩
  rw [Std.Array.from_val, keyToRoundKeys_eq]
  rfl

/-! ## AES-256 -/

theorem load_words (l l' : List (BitVec 8)) (q : Nat) (hl : 16 * q + 16 ≤ l.length)
    (hl' : ∀ i < 16, l'[i]! = l[16 * q + i]!) :
    leBytesToQuad32 l' = mkfour (seqNat8ToSeqNat32LE l)[4 * q]! (seqNat8ToSeqNat32LE l)[4 * q + 1]!
      (seqNat8ToSeqNat32LE l)[4 * q + 2]! (seqNat8ToSeqNat32LE l)[4 * q + 3]! := by
  apply eq_of_byte_eq; intro i hi
  rw [byte_leBytesToQuad32 _ hi, byte_mkfour _ _ _ _ hi, hl' i hi]
  have hb : i % 4 < 4 := Nat.mod_lt _ (by decide)
  by_cases h1 : i < 4
  · rw [if_pos h1, wbyte_seqNat8ToSeqNat32LE l (i := 4 * q) (by omega) hb]; congr 1; omega
  by_cases h2 : i < 8
  · rw [if_neg h1, if_pos h2, wbyte_seqNat8ToSeqNat32LE l (i := 4 * q + 1) (by omega) hb]; congr 1; omega
  by_cases h3 : i < 12
  · rw [if_neg h1, if_neg h2, if_pos h3, wbyte_seqNat8ToSeqNat32LE l (i := 4 * q + 2) (by omega) hb]
    congr 1; omega
  · rw [if_neg h1, if_neg h2, if_neg h3, wbyte_seqNat8ToSeqNat32LE l (i := 4 * q + 3) (by omega) hb]
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
  rw [if_pos (by omega), show 4 * (2 * s + 2) / 8 - 1 = s by omega,
    show 4 * (2 * s + 2) - 8 = 4 * (2 * s) by omega,
    show 4 * (2 * s + 2) - 1 = 4 * (2 * s + 1) + 3 by omega] at k0
  rw [if_neg (by omega), if_neg (by omega), show 4 * (2 * s + 2) + 1 - 8 = 4 * (2 * s) + 1 by omega,
    show 4 * (2 * s + 2) + 1 - 1 = 4 * (2 * s + 2) by omega] at k1
  rw [if_neg (by omega), if_neg (by omega), show 4 * (2 * s + 2) + 2 - 8 = 4 * (2 * s) + 2 by omega,
    show 4 * (2 * s + 2) + 2 - 1 = 4 * (2 * s + 2) + 1 by omega] at k2
  rw [if_neg (by omega), if_neg (by omega), show 4 * (2 * s + 2) + 3 - 8 = 4 * (2 * s) + 3 by omega,
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
  rw [if_neg (by omega), if_pos (by omega), show 4 * (2 * s + 3) - 8 = 4 * (2 * s + 1) by omega,
    show 4 * (2 * s + 3) - 1 = 4 * (2 * s + 2) + 3 by omega] at k0
  rw [if_neg (by omega), if_neg (by omega), show 4 * (2 * s + 3) + 1 - 8 = 4 * (2 * s + 1) + 1 by omega,
    show 4 * (2 * s + 3) + 1 - 1 = 4 * (2 * s + 3) by omega] at k1
  rw [if_neg (by omega), if_neg (by omega), show 4 * (2 * s + 3) + 2 - 8 = 4 * (2 * s + 1) + 2 by omega,
    show 4 * (2 * s + 3) + 2 - 1 = 4 * (2 * s + 3) + 1 by omega] at k2
  rw [if_neg (by omega), if_neg (by omega), show 4 * (2 * s + 3) + 3 - 8 = 4 * (2 * s + 1) + 3 by omega,
    show 4 * (2 * s + 3) + 3 - 1 = 4 * (2 * s + 3) + 2 by omega] at k3
  rw [k3, k2, k1, k0]

theorem sub_step' (a b : BitVec 128) :
    xorPrefix b ^^^ subBytes (shiftRows (ofLanes32 fun i => lane32 a (255 / 4 ^ i % 4))) =
      nextKey b (subWord (lane32 a 3)) := by
  apply eq_of_byte_eq
  intro i hi
  interval_cases i <;>
    simp (config := { decide := true }) [xorPrefix, byte_xor, byte_shl, byte_ofLanes32, byte_subBytes,
      byte_shiftRows, nextKey, byte_mkfour, wbyte_xor, wbyte_subWord, wbyte_lane32, BitVec.xor_assoc]

theorem rcon7_drop {s : Nat} (hs : s < 7) :
    (low.x86_64.aes.RCON.take 7).drop s = low.x86_64.aes.RCON[s]! :: (low.x86_64.aes.RCON.take 7).drop (s + 1) := by
  interval_cases s <;> rfl

theorem aes256_loop (key : List (BitVec 32)) (n : Nat) (hn1 : 1 ≤ n) (hn : n ≤ 7) :
    low.x86_64.aes.aes256_expand_loop (roundKey .AES_256 key (2 * (7 - n)))
        (roundKey .AES_256 key (2 * (7 - n) + 1)) ((low.x86_64.aes.RCON.take 7).drop (7 - n)) =
      ok ((List.range' (2 * (7 - n) + 2) (2 * n - 1)).map (roundKey .AES_256 key)) := by
  have he : ∀ s, s < 7 → nextKey (roundKey .AES_256 key (2 * s))
      (subWord (rotWord (lane32 (roundKey .AES_256 key (2 * s + 1)) 3)) ^^^ (low.x86_64.aes.RCON[s]!).bv) =
      roundKey .AES_256 key (2 * s + 2) := by
    intro s hs; rw [roundKey256_even, rcon_eq (by omega)]
  have e255 : (255#i32).bv.toNat = 255 := by decide
  induction n, hn1 using Nat.le_induction with
  | base =>
    rw [rcon7_drop (by omega)]
    simp only [low.x86_64.aes.aes256_expand_loop, xor_prefix_eq, sub_rot_word_eq, bind_ok,
      core.core_arch.x86.sse2._mm_xor_si128, rot_step, he 6 (by omega)]
    rfl
  | succ n hn1 ih =>
    rw [rcon7_drop (by omega), show 7 - (n + 1) + 1 = 7 - n by omega]
    have hne : (low.x86_64.aes.RCON.take 7).drop (7 - n) ≠ [] := by
      rw [rcon7_drop (by omega)]; exact List.cons_ne_nil _ _
    simp only [low.x86_64.aes.aes256_expand_loop, xor_prefix_eq, sub_rot_word_eq, bind_ok,
      core.core_arch.x86.sse2._mm_xor_si128, rot_step, he (7 - (n + 1)) (by omega), hne, ite_false,
      core.core_arch.x86.sse2._mm_shuffle_epi32, core.core_arch.x86.sse2._mm_setzero_si128,
      core.core_arch.x86.aes._mm_aesenclast_si128, e255,
      show ∀ x : BitVec 128, x ^^^ (0 : BitVec 128) = x from fun x => BitVec.xor_zero, sub_step',
      ← roundKey256_odd]
    rw [show 2 * (7 - (n + 1)) + 2 = 2 * (7 - n) by omega,
      show 2 * (7 - n) + 1 = 2 * (7 - (n + 1)) + 3 by omega] at *
    rw [ih (by omega)]
    simp only [bind_ok]
    rw [show 2 * (n + 1) - 1 = 2 * n - 1 + 1 + 1 by omega, List.range'_succ, List.range'_succ,
      show 2 * (7 - (n + 1)) + 3 = 2 * (7 - n) + 1 by omega, show 2 * (7 - n) + 1 + 1 = 2 * (7 - n) + 2 by omega]
    rfl

/-- The AES-256 key `key` expands to FIPS 197's round keys, each its 16 bytes in order. -/
theorem aes256_expand_spec (key : Std.Array Std.U8 32#usize)
    (out : Std.Array core.core_arch.x86.__m128i 15#usize) :
    ∃ rk, low.x86_64.aes.aes256_expand key out = ok rk ∧
      rk.val = keyToRoundKeys .AES_256 (seqNat8ToSeqNat32LE (key.val.map (·.bv))) := by
  set l := key.val.map (·.bv)
  set kw := seqNat8ToSeqNat32LE l
  have hl : l.length = 32 := by simp [l]
  have h0 : low.x86_64.aes.load (key.val.take 16) = roundKey .AES_256 kw 0 := by
    simp only [roundKey, keyWord_key .AES_256 kw (show 0 < 8 by decide),
      keyWord_key .AES_256 kw (show 1 < 8 by decide), keyWord_key .AES_256 kw (show 2 < 8 by decide),
      keyWord_key .AES_256 kw (show 3 < 8 by decide), Nat.mul_zero, Nat.zero_add]
    refine load_words l _ 0 (by omega) ?_
    intro i hi
    have hk : i < key.val.length := by simp; omega
    simp [l, List.getElem!_eq_getElem?_getD, hi, List.getElem?_eq_getElem hk]
  have h1 : low.x86_64.aes.load (key.val.drop 16) = roundKey .AES_256 kw 1 := by
    simp only [roundKey, keyWord_key .AES_256 kw (show 4 < 8 by decide),
      keyWord_key .AES_256 kw (show 5 < 8 by decide), keyWord_key .AES_256 kw (show 6 < 8 by decide),
      keyWord_key .AES_256 kw (show 7 < 8 by decide), Nat.mul_one]
    refine load_words l _ 1 (by omega) ?_
    intro i hi
    simp [l, List.getElem!_eq_getElem?_getD, List.getElem?_drop]
  have hloop := aes256_loop kw 7 (by omega) le_rfl
  simp only [Nat.sub_self, List.drop_zero, Nat.mul_zero, Nat.zero_add] at hloop
  unfold low.x86_64.aes.aes256_expand
  simp only [h0, h1, hloop, bind_ok]
  rw [dif_pos (by simp)]
  refine ⟨_, rfl, ?_⟩
  rw [Std.Array.from_val, keyToRoundKeys_eq]
  rfl

end rind.x86_64
