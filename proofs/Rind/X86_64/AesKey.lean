import Rind.X86_64.Ghash
open Aeneas Aeneas.Std Result rind.vale rind.simd

namespace rind.x86_64

/-! ## Vectors as bytes and `u128`s -/

theorem load_eq (b : Std.Array Std.U8 16#usize) : low.x86_64.aes.load b = ok (loadBytes b.val) := by
  simp only [low.x86_64.aes.load, lift, core.num.U128.from_le_bytes, bind_ok, u128_to_m128i_eq, loadBytes,
    leBytesToQuad32]
  congr 1
  apply BitVec.eq_of_getLsbD_eq; intro i hi
  simp [hi]

theorem toLEBytes_eq (v : BitVec 128) : v.toLEBytes = leQuad32ToBytes v := by
  apply List.ext_getElem (by simp [BitVec.toLEBytes_length, leQuad32ToBytes])
  intro i h1 h2
  have hi : i < 16 := by simpa [BitVec.toLEBytes_length] using h1
  apply BitVec.eq_of_getElem_eq; intro j hj
  rw [BitVec.getElem_toLEBytes_eq_getElem v i j h1 hj (by omega)]
  simp [leQuad32ToBytes, BitVec.getElem_extractLsb', BitVec.getLsbD_eq_getElem (show 8 * i + j < 128 by omega)]

theorem store_eq (v : BitVec 128) : low.x86_64.aes.store v = ok (storeBytes v) := by
  have h64 : (64#i32).val ≥ 0 := by decide
  have t64 : (64#i32).toNat = 64 := by decide
  simp only [low.x86_64.aes.store, core.core_arch.x86_64.sse2._mm_cvtsi128_si64,
    core.core_arch.x86.sse2._mm_unpackhi_epi64, lift, IScalar.hcast, core.convert.num.FromU128U64.from,
    HShiftLeft.hShiftLeft, UScalar.shiftLeft_IScalar, h64, ite_true, t64, UScalar.shiftLeft, bind_ok,
    UScalarTy.numBits, show 64 < 128 by decide]
  have e : ((((lane64 (lane64 v 1 ++ lane64 v 1) 0).signExtend 64).setWidth 128).shiftLeft 64 |||
      ((lane64 v 0).signExtend 64).setWidth 128 : BitVec 128) = v := by
    apply BitVec.eq_of_getLsbD_eq; intro i hi
    simp only [lane64, BitVec.getLsbD_or, BitVec.getLsbD_setWidth, BitVec.getLsbD_signExtend,
      BitVec.getLsbD_extractLsb', BitVec.getLsbD_append, BitVec.shiftLeft_eq, BitVec.getLsbD_shiftLeft]
    by_cases h : i < 64
    · simp [h, hi]
    · simp [h, hi, show i - 64 < 64 by omega, show 64 + (i - 64) = i by omega, show i - 64 < 128 by omega]
  have hbv : ∀ x : BitVec 64, U64.bv (UScalar.mk x) = x := fun _ => rfl
  have hor : ∀ x y : BitVec 128, (@UScalar.mk .U128 x ||| @UScalar.mk .U128 y) = @UScalar.mk .U128 (x ||| y) :=
    fun _ _ => rfl
  simp only [hbv, hor, e]
  simp only [core.num.U128.to_le_bytes, storeBytes, toLEBytes_eq]

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

theorem rcon_eq {r : Nat} (hr : r < 10) : aesRcon r = (low.x86_64.aes.RCON.val[r]!).bv := by
  interval_cases r <;> (unfold low.x86_64.aes.RCON; decide)

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

/-- AES-128's round key after round key `s`. -/
theorem aes128_next (kw : List (BitVec 32)) {s : Nat} (hs : s < 10) :
    xorPrefix (roundKey .AES_128 kw s) ^^^ subRotWord (roundKey .AES_128 kw s) low.x86_64.aes.RCON.val[s]! =
      roundKey .AES_128 kw (s + 1) := by
  rw [rot_step, roundKey128_succ, rcon_eq hs]
  simp only [roundKey, (lane32_mkfour _ _ _ _).2.2.2]

/-- `aes128_expand`'s loop: from round key `iter.start`, held in `t` and
`out`, it writes the rest. -/
theorem aes128_loop_spec (kw : List (BitVec 32)) (iter : core.ops.range.Range Usize)
    (t : core.core_arch.x86.__m128i) (out : Std.Array core.core_arch.x86.__m128i 11#usize)
    (hs : iter.start.val ≤ 10) (he : iter.end.val = 10) (ht : t = roundKey .AES_128 kw iter.start.val)
    (ho : ∀ r ≤ iter.start.val, out.val[r]! = roundKey .AES_128 kw r) :
    low.x86_64.aes.aes128_expand_loop iter t out ⦃ rk => ∀ r < 11, rk.val[r]! = roundKey .AES_128 kw r ⦄ := by
  unfold low.x86_64.aes.aes128_expand_loop
  apply loop.spec_decr_nat (fun x => 10 - x.1.start.val)
    (fun x => x.1.start.val ≤ 10 ∧ x.1.end.val = 10 ∧ x.2.1 = roundKey .AES_128 kw x.1.start.val ∧
      ∀ r ≤ x.1.start.val, x.2.2.val[r]! = roundKey .AES_128 kw r)
  · rintro ⟨it, t, out⟩ ⟨hs, he, ht, ho⟩
    simp only at hs he ht ho ⊢
    unfold low.x86_64.aes.aes128_expand_loop.body
    by_cases hlt : it.start.val < it.end.val
    · step with core.iter.range.IteratorRange.next_Usize_some_spec as ⟨o, it', ho', hst, hen⟩
      subst ho'
      simp only [xor_prefix_eq, sub_rot_word_eq, core.core_arch.x86.sse2._mm_xor_si128, bind_ok]
      step*
      have hi1 : i1 = low.x86_64.aes.RCON.val[it.start.val]! := by
        rw [i1_post]; exact (getElem!_pos _ _ _).symm
      refine ⟨by omega, by rw [hen]; exact he, ?_, ?_, by omega⟩
      · rw [hst, ht, hi1]; exact aes128_next kw (by omega)
      · intro r hr
        rw [a_post, Std.Array.set_val_eq, getElem!_set _ _ _ (by simp; omega), i2_post]
        split_ifs with h
        · rw [← h, ht, hi1]; exact aes128_next kw (by omega)
        · exact ho r (by omega)
    · step with core.iter.range.IteratorRange.next_Usize_none_spec as ⟨o, it', ho', hit⟩
      subst ho'
      simp only [WP.spec_ok]
      intro r hr
      exact ho r (by omega)
  · exact ⟨hs, he, ht, ho⟩

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

/-- The AES-128 key `key` expands to FIPS 197's round keys, each its 16 bytes in order. -/
@[step]
theorem aes128_expand_spec (key : Std.Array Std.U8 16#usize)
    (out : Std.Array core.core_arch.x86.__m128i 11#usize) :
    low.x86_64.aes.aes128_expand key out ⦃ rk =>
      rk.val = keyToRoundKeys .AES_128 (seqNat8ToSeqNat32LE (key.val.map (·.bv))) ⦄ := by
  set kw := seqNat8ToSeqNat32LE (key.val.map (·.bv))
  have hl : (key.val.map (·.bv)).length = 16 := by simp
  have h0 : loadBytes key.val = roundKey .AES_128 kw 0 := by
    simp only [roundKey, keyWord_key .AES_128 kw (show 0 < 4 by decide),
      keyWord_key .AES_128 kw (show 1 < 4 by decide), keyWord_key .AES_128 kw (show 2 < 4 by decide),
      keyWord_key .AES_128 kw (show 3 < 4 by decide), Nat.mul_zero, Nat.zero_add]
    exact load_eq_mkfour _ hl
  unfold low.x86_64.aes.aes128_expand
  simp only [load_eq, bind_ok]
  apply WP.spec_mono (aes128_loop_spec kw _ _ _ (by simp) (by simp) (by rw [h0]; simp) ?_)
  · intro rk hrk
    rw [keyToRoundKeys_eq]
    exact eq_range_map _ _ (by simp [nr]) hrk
  · intro r hr
    simp only [show r = 0 by simpa using hr, Std.Array.repeat_val]
    simp [h0]

/-! ## AES-256 -/

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

theorem sub_step' (a b : BitVec 128) :
    xorPrefix b ^^^ subBytes (shiftRows (ofLanes32 fun i => lane32 a (255 / 4 ^ i % 4))) =
      nextKey b (subWord (lane32 a 3)) := by
  apply eq_of_byte_eq
  intro i hi
  interval_cases i <;>
    simp (config := { decide := true }) [xorPrefix, byte_xor, byte_shl, byte_ofLanes32, byte_subBytes,
      byte_shiftRows, nextKey, byte_mkfour, wbyte_xor, wbyte_subWord, wbyte_lane32, BitVec.xor_assoc]

/-- AES-256's even round key after round keys `2 * s` and `2 * s + 1`. -/
theorem aes256_next_even (kw : List (BitVec 32)) {s : Nat} (hs : s < 7) :
    xorPrefix (roundKey .AES_256 kw (2 * s)) ^^^
        subRotWord (roundKey .AES_256 kw (2 * s + 1)) low.x86_64.aes.RCON.val[s]! =
      roundKey .AES_256 kw (2 * s + 2) := by
  rw [rot_step, roundKey256_even, rcon_eq (by omega)]

/-- `aes256_expand`'s loop: from round keys `2 * iter.start` and the next,
held in `a`, `b`, and `out`, it writes the rest. -/
theorem aes256_loop_spec (kw : List (BitVec 32)) (iter : core.ops.range.Range Usize)
    (a b : core.core_arch.x86.__m128i) (out : Std.Array core.core_arch.x86.__m128i 15#usize)
    (hs : iter.start.val ≤ 6) (he : iter.end.val = 7) (ha : a = roundKey .AES_256 kw (2 * iter.start.val))
    (hb : b = roundKey .AES_256 kw (2 * iter.start.val + 1))
    (ho : ∀ r ≤ 2 * iter.start.val + 1, out.val[r]! = roundKey .AES_256 kw r) :
    low.x86_64.aes.aes256_expand_loop iter a b out ⦃ rk => ∀ r < 15, rk.val[r]! = roundKey .AES_256 kw r ⦄ := by
  unfold low.x86_64.aes.aes256_expand_loop
  apply loop.spec_decr_nat (fun x => 7 - x.1.start.val)
    (fun x => x.1.start.val ≤ 6 ∧ x.1.end.val = 7 ∧ x.2.1 = roundKey .AES_256 kw (2 * x.1.start.val) ∧
      x.2.2.1 = roundKey .AES_256 kw (2 * x.1.start.val + 1) ∧
      ∀ r ≤ 2 * x.1.start.val + 1, x.2.2.2.val[r]! = roundKey .AES_256 kw r)
  · rintro ⟨it, a, b, out⟩ ⟨hs, he, ha, hb, ho⟩
    simp only at hs he ha hb ho ⊢
    unfold low.x86_64.aes.aes256_expand_loop.body
    step with core.iter.range.IteratorRange.next_Usize_some_spec as ⟨o, it', ho', hst, hen⟩
    subst ho'
    have e255 : (255#i32).bv.toNat = 255 := by decide
    simp only [xor_prefix_eq, sub_rot_word_eq, core.core_arch.x86.sse2._mm_xor_si128, bind_ok,
      low.x86_64.aes.zero, core.core_arch.x86.sse2._mm_shuffle_epi32,
      core.core_arch.x86.sse2._mm_setzero_si128, core.core_arch.x86.aes._mm_aesenclast_si128, e255,
      show ∀ x : BitVec 128, x ^^^ (0 : BitVec 128) = x from fun x => BitVec.xor_zero, sub_step']
    step*
    all_goals
      have hi1 : i1 = low.x86_64.aes.RCON.val[it.start.val]! := by
        rw [i1_post]; exact (getElem!_pos _ _ _).symm
      have ha1 : xorPrefix a ^^^ subRotWord b i1 = roundKey .AES_256 kw (2 * it.start.val + 2) := by
        rw [ha, hb, hi1]; exact aes256_next_even kw (by omega)
    case h1 =>
      have hs6 : it.start.val = 6 := by rw [‹it.start = 6#usize›]; rfl
      intro r hr
      rw [index_mut_back_post, Std.Array.set_val_eq, getElem!_set _ _ _ (by simp; omega), i3_post, i2_post]
      split_ifs with h
      · rw [← h, ha1]
      · exact ho r (by omega)
    have hs6 : it.start.val ≠ 6 := fun h => ‹¬it.start = 6#usize› (UScalar.eq_of_val_eq (by rw [h]; rfl))
    have hb1 : nextKey b (subWord (lane32 (xorPrefix a ^^^ subRotWord b i1) 3)) =
        roundKey .AES_256 kw (2 * it.start.val + 3) := by
      rw [ha1, hb, roundKey256_odd]
    refine ⟨by omega, by rw [hen]; exact he, ?_, ?_, ?_, by omega⟩
    · rw [hst, ha1, show 2 * (it.start.val + 1) = 2 * it.start.val + 2 by omega]
    · rw [hst, hb1, show 2 * (it.start.val + 1) + 1 = 2 * it.start.val + 3 by omega]
    · intro r hr
      rw [a2_post, Std.Array.set_val_eq, getElem!_set _ _ _ (by simp; omega), index_mut_back_post,
        Std.Array.set_val_eq, getElem!_set _ _ _ (by simp; omega), i4_post, i3_post, i2_post]
      split_ifs with h h'
      · rw [← h, hb1]
      · rw [← h', ha1]
      · exact ho r (by omega)
  · exact ⟨hs, he, ha, hb, ho⟩

/-- The AES-256 key `key` expands to FIPS 197's round keys, each its 16 bytes in order. -/
@[step]
theorem aes256_expand_spec (key : Std.Array Std.U8 32#usize)
    (out : Std.Array core.core_arch.x86.__m128i 15#usize) :
    low.x86_64.aes.aes256_expand key out ⦃ rk =>
      rk.val = keyToRoundKeys .AES_256 (seqNat8ToSeqNat32LE (key.val.map (·.bv))) ⦄ := by
  set l := key.val.map (·.bv)
  set kw := seqNat8ToSeqNat32LE l
  have hl : l.length = 32 := by simp [l]
  unfold low.x86_64.aes.aes256_expand
  step*
  have hsl : s.len = 16#usize := by scalar_tac
  simp only [core.array.TryFromSharedArraySlice.try_from, hsl, ↓reduceDIte, core.result.Result.unwrap,
    bind_ok, load_eq]
  step*
  have hsl1 : s1.len = 16#usize := by scalar_tac
  simp only [hsl1, ↓reduceDIte, bind_ok, Std.Array.from_val]
  step*
  have hkl : key.val.length = 32 := by simp
  have h0 : loadBytes s.val = roundKey .AES_256 kw 0 := by
    simp only [roundKey, keyWord_key .AES_256 kw (show 0 < 8 by decide),
      keyWord_key .AES_256 kw (show 1 < 8 by decide), keyWord_key .AES_256 kw (show 2 < 8 by decide),
      keyWord_key .AES_256 kw (show 3 < 8 by decide), Nat.mul_zero, Nat.zero_add, loadBytes]
    refine load_words l _ 0 (by omega) ?_
    intro i hi
    have hk : i < key.val.length := by omega
    simp [l, s_post, List.slice, List.getElem!_eq_getElem?_getD, hi, List.getElem?_eq_getElem hk]
  have h1 : loadBytes s1.val = roundKey .AES_256 kw 1 := by
    simp only [roundKey, keyWord_key .AES_256 kw (show 4 < 8 by decide),
      keyWord_key .AES_256 kw (show 5 < 8 by decide), keyWord_key .AES_256 kw (show 6 < 8 by decide),
      keyWord_key .AES_256 kw (show 7 < 8 by decide), Nat.mul_one, loadBytes]
    refine load_words l _ 1 (by omega) ?_
    intro i hi
    simp [l, s1_post, List.getElem!_eq_getElem?_getD, List.getElem?_drop]
  apply WP.spec_mono (aes256_loop_spec kw _ _ _ _ (by simp) (by simp) (by rw [h0]; simp) (by rw [h1]; simp) ?_)
  · intro rk hrk
    rw [keyToRoundKeys_eq]
    exact eq_range_map _ _ (by simp [nr]) hrk
  · intro r hr
    rw [a3_post, Std.Array.set_val_eq, getElem!_set _ _ _ (by simp), Std.Array.repeat_val]
    have hr' : r ≤ 1 := by simpa using hr
    split_ifs with h
    · rw [← show (1#usize : Usize).val = 1 from rfl] at h1; rw [← h, h1]
    · have : r = 0 := by simp at h; omega
      subst this; simp [h0]

/-! ## The block cipher -/

theorem aesenc_eq (s k : BitVec 128) : core.core_arch.x86.aes._mm_aesenc_si128 s k = ok (evalRound s k) := by
  simp only [core.core_arch.x86.aes._mm_aesenc_si128, evalRound, subBytes_shiftRows]

theorem aesenclast_eq (s k : BitVec 128) :
    core.core_arch.x86.aes._mm_aesenclast_si128 s k = ok (shiftRows (subBytes s) ^^^ k) := by
  simp only [core.core_arch.x86.aes._mm_aesenclast_si128, subBytes_shiftRows]

/-- `aes128_block` encrypts with the round keys `rk` as Vale's `eval_cipher` does. -/
theorem aes128_block_spec (rk : Std.Array core.core_arch.x86.__m128i 11#usize) (b : Std.Array Std.U8 16#usize) :
    low.x86_64.aes.aes128_block rk b = ok (storeBytes (evalCipher .AES_128 (loadBytes b.val) rk.val)) := by
  obtain ⟨l, hl, rfl⟩ : ∃ l h, rk = Std.Array.make _ l h := ⟨rk.val, rk.property, Std.Array.ext _ _ (by simp [Std.Array.make_val])⟩
  unfold low.x86_64.aes.aes128_block
  match l, hl with
  | [k0, k1, k2, k3, k4, k5, k6, k7, k8, k9, k10], _ =>
    simp [Std.Array.make_val, load_eq, store_eq, Std.Array.index_usize, aesenc_eq, aesenclast_eq,
      core.core_arch.x86.sse2._mm_xor_si128, evalCipher, evalRounds, nr]

/-- `aes256_block` encrypts with the round keys `rk` as Vale's `eval_cipher` does. -/
theorem aes256_block_spec (rk : Std.Array core.core_arch.x86.__m128i 15#usize) (b : Std.Array Std.U8 16#usize) :
    low.x86_64.aes.aes256_block rk b = ok (storeBytes (evalCipher .AES_256 (loadBytes b.val) rk.val)) := by
  obtain ⟨l, hl, rfl⟩ : ∃ l h, rk = Std.Array.make _ l h := ⟨rk.val, rk.property, Std.Array.ext _ _ (by simp [Std.Array.make_val])⟩
  unfold low.x86_64.aes.aes256_block
  match l, hl with
  | [k0, k1, k2, k3, k4, k5, k6, k7, k8, k9, k10, k11, k12, k13, k14], _ =>
    simp [Std.Array.make_val, load_eq, store_eq, Std.Array.index_usize, aesenc_eq, aesenclast_eq,
      core.core_arch.x86.sse2._mm_xor_si128, evalCipher, evalRounds, nr]

theorem load_zero : loadBytes (Std.Array.repeat 16#usize 0#u8).val = mkfour 0 0 0 0 := by
  simp only [loadBytes, Std.Array.repeat_val]
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  rw [getLsbD_leBytesToQuad32 _ hk]
  have : k / 8 < 16 := by omega
  simp only [List.getElem!_eq_getElem?_getD, List.getElem?_map, List.getElem?_replicate]
  rw [ite_eq_left (by simpa using this)]
  simp [mkfour]

/-- A block read big-endian, as `u128::from_be_bytes` reads `storeBytes`'s bytes, is
Vale's `reverse_bytes_quad32` of it. -/
theorem from_be_bytes_store (q : BitVec 128) :
    (core.num.U128.from_be_bytes (storeBytes q)).bv = reverseBytesQuad32 q := by
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  have e : (storeBytes q).val.map U8.bv = leQuad32ToBytes q := by
    simp [storeBytes, Std.Array.from_val, Function.comp_def]
  simp only [core.num.U128.from_be_bytes, reverseBytesQuad32, leBytesToQuad32, BitVec.fromBEBytes]
  rw [BitVec.getLsbD_setWidth, decide_eq_true hk, Bool.true_and, BitVec.getLsbD_cast, BitVec.getLsbD_cast, e]

end rind.x86_64
