import RindIsa.AArch64
import Rind.S2nGcm
import Mathlib.Tactic.IntervalCases

open VG VG.AArch64 VG.VectorCrypto rind.vale rind.simd rind.s2n

/-!
# What the instructions of aws-lc's eight-way AES-GCM kernels compute

The vector instructions of `RindIsa/AArch64/AesGcm8x192.lean`'s loops, as VG's
AArch64 model defines them, restated in the vocabulary rind's AES-GCM proofs
use: AESE and AESMC run FIPS 197's rounds as Vale states them
(`aesRounds192_eq`), so twelve of them are Vale's AES-192 (`evalCipher`);
PMULL is the carry-less product `clmul` (`polyMul_eq`); EXT by eight bytes,
TRN1, and TRN2 move the 64-bit halves `lo` and `hi`; REV64 is SP 800-38D's
byte order with its halves swapped (`rev64b_eq`); and REV32 with ADD on 32-bit
lanes steps the counter block (`add_ctr`).
-/

local notation "P" => Polynomial (ZMod 2)

set_option maxRecDepth 20000

namespace rind.aarch64.gcm8x192

/-! ## Bytes -/

theorem getLsbD_ofVBytes (f : Nat → BitVec 8) (k : Nat) :
    (ofVBytes f).getLsbD k = (decide (k < 128) && (f (k / 8)).getLsbD (k % 8)) := by
  by_cases hk : k < 128
  · simp only [ofVBytes, BitVec.getLsbD_append]
    interval_cases k <;> simp
  · rw [BitVec.getLsbD_of_ge _ _ (by omega)]; simp [hk]

theorem byte_ofVBytes (f : Nat → BitVec 8) {i : Nat} (hi : i < 16) : byte (ofVBytes f) i = f i := by
  apply BitVec.eq_of_getLsbD_eq; intro j hj
  simp only [byte, BitVec.getLsbD_extractLsb', hj, decide_true, Bool.true_and, getLsbD_ofVBytes,
    show 8 * i + j < 128 by omega, show (8 * i + j) / 8 = i by omega, show (8 * i + j) % 8 = j by omega]

theorem ofVBytes_eq (f : Nat → BitVec 8) : ofVBytes f = ofBytes f :=
  eq_of_byte_eq fun i hi => by rw [byte_ofVBytes f hi, byte_ofBytes f hi]

theorem vbyte_eq (x : BitVec 128) (i : Nat) : vbyte x i = byte x i := rfl

/-! ## AES -/

/-- FIPS 197's S-box, checked on every byte. -/
def sboxAgrees (n : Nat) : Bool := aesSbox (BitVec.ofNat 8 n) == rind.vale.sboxTree (BitVec.ofNat 8 n)

theorem sboxAgrees_all : (List.range 256).all sboxAgrees = true := by decide +kernel

theorem aesSbox_eq (b : BitVec 8) : aesSbox b = sbox b := by
  rw [sbox_eq_tree]
  have h := List.all_eq_true.1 sboxAgrees_all b.toNat (List.mem_range.2 b.isLt)
  simpa [sboxAgrees, BitVec.ofNat_toNat] using h

theorem aesMul_one (b : BitVec 8) : aesMul 1 b = b := by
  simp [aesMul, List.range_succ, Nat.repeat]

theorem aesMul_two (b : BitVec 8) : aesMul 2 b = xtime b := by
  simp [aesMul, List.range_succ, Nat.repeat, aesXtimes, xtime]; rfl

theorem aesMul_three (b : BitVec 8) : aesMul 3 b = xtime b ^^^ b := by
  simp [aesMul, List.range_succ, Nat.repeat, aesXtimes, xtime, BitVec.xor_comm]; rfl

/-- AESE's substitution and shift are Vale's, in the other order, which
commutes as the S-box acts on each byte. -/
theorem aese_eq (x : BitVec 128) : aesMapBytes aesSbox (aesShiftRows x) = shiftRows (subBytes x) := by
  apply eq_of_byte_eq; intro i hi
  simp only [aesMapBytes, aesShiftRows, shiftRows, subBytes, ofVBytes_eq, byte_ofBytes _ hi, vbyte_eq,
    aesSbox_eq]
  rw [byte_ofBytes _ (by omega)]

theorem aesMixColumns_eq (x : BitVec 128) : aesMixColumns x = mixColumns x := by
  rw [mixColumns_eq]
  apply eq_of_byte_eq; intro i hi
  simp only [aesMixColumns, aesMixWith, rind.vale.fips197MixColumns, ofVBytes_eq, byte_ofBytes _ hi, vbyte_eq,
    aesMul_one, aesMul_two, aesMul_three]
  interval_cases i <;> simp only [Nat.reduceMod, Nat.reduceDiv, Nat.reduceMul, Nat.reduceAdd] <;> ac_rfl

/-- One of AES's middle rounds as AESE and AESMC run it: the key added first. -/
def aesRound (x k : BitVec 128) : BitVec 128 := aesMixColumns (aesMapBytes aesSbox (aesShiftRows (x ^^^ k)))

/-- AES-192's rounds as twelve AESE and eleven AESMC run them on `x` with the
round keys `k 0` to `k 11`, before the last key is added. -/
def aesRounds192 (x : BitVec 128) (k : Nat → BitVec 128) : BitVec 128 :=
  aesMapBytes aesSbox (aesShiftRows
    (aesRound (aesRound (aesRound (aesRound (aesRound (aesRound (aesRound (aesRound (aesRound (aesRound
      (aesRound x (k 0)) (k 1)) (k 2)) (k 3)) (k 4)) (k 5)) (k 6)) (k 7)) (k 8)) (k 9)) (k 10) ^^^ k 11))

/-- The round keys `k 0` to `k 12`. -/
def keys13 (k : Nat → BitVec 128) : List (BitVec 128) := (List.range 13).map k

theorem aesRound_eq (x k k' : BitVec 128) : aesRound x k ^^^ k' = evalRound (x ^^^ k) k' := by
  rw [aesRound, aese_eq, aesMixColumns_eq, evalRound]

/-- Twelve rounds of AESE and AESMC and the last key are Vale's AES-192. -/
theorem aesRounds192_eq (x : BitVec 128) (k : Nat → BitVec 128) :
    aesRounds192 x k ^^^ k 12 = evalCipher .AES_192 x (keys13 k) := by
  simp only [aesRounds192, evalCipher, nr, keys13, evalRounds, aese_eq]
  simp only [aesRound_eq, BitVec.xor_assoc, BitVec.xor_self, BitVec.xor_zero]
  simp [List.getElem!_eq_getElem?_getD, aesRound_eq, BitVec.xor_assoc, BitVec.xor_self, BitVec.xor_zero]

/-! ## PMULL and the halves -/

theorem foldl_polyMul (a b : BitVec 64) : ∀ n,
    (List.range n).foldl (fun acc i => if a.getLsbD i then acc ^^^ (b.setWidth 128 <<< i) else acc) 0 =
      clmulAux b a n
  | 0 => rfl
  | n + 1 => by
    rw [List.range_succ, List.foldl_append, foldl_polyMul a b n, List.foldl_cons, List.foldl_nil, clmulAux]
    by_cases h : a.getLsbD n <;> simp [h]

theorem clmul_comm (a b : BitVec 64) : clmul a b = clmul b a :=
  toPoly_inj (by rw [toPoly_clmul, toPoly_clmul, mul_comm])

/-- PMULL's product is the carry-less product. -/
theorem polyMul_eq (a b : BitVec 64) : polyMul a b = clmul a b := by
  rw [polyMul, foldl_polyMul, clmul_comm]; unfold clmul; rfl

theorem vdword_zero (x : BitVec 128) : vdword x 0 = lo x := rfl
theorem vdword_one (x : BitVec 128) : vdword x 1 = hi x := rfl

theorem lo_swap (x : BitVec 128) : lo (swap x) = hi x := by simp [swap, lo_append]
theorem hi_swap (x : BitVec 128) : hi (swap x) = lo x := by simp [swap, hi_append]

theorem swap_xor (x y : BitVec 128) : swap (x ^^^ y) = swap x ^^^ swap y := by
  simp only [swap, lo_xor, hi_xor]
  apply BitVec.eq_of_getLsbD_eq; intro i hi'
  simp only [BitVec.getLsbD_append, BitVec.getLsbD_xor]
  split <;> rfl

theorem lo_setWidth (x : BitVec 64) : lo (x.setWidth 128) = x := by
  apply BitVec.eq_of_getLsbD_eq; intro i hi'
  simp [lo, BitVec.getLsbD_extractLsb', BitVec.getLsbD_setWidth, hi', show i < 128 by omega]

/-- EXT of a register with itself by eight bytes swaps its halves. -/
theorem ext_swap (x : BitVec 128) : ((x ++ x) >>> 64).extractLsb' 0 128 = swap x := by
  apply BitVec.eq_of_getLsbD_eq; intro i hi'
  rw [getLsbD_swap]
  simp only [BitVec.getLsbD_extractLsb', BitVec.getLsbD_ushiftRight, BitVec.getLsbD_append, hi',
    decide_true, Bool.true_and, Nat.zero_add]
  by_cases h : i < 64
  · simp [show 64 + i < 128 by omega, show (i + 64) % 128 = i + 64 by omega, Nat.add_comm]
    intro; omega
  · simp [show ¬ 64 + i < 128 by omega, show (i + 64) % 128 = i - 64 by omega, show 64 + i - 128 = i - 64 by omega]

theorem trn1_d2 (x y : BitVec 128) : VPermOp.trn1.eval .d2 x y = lo y ++ lo x := by
  simp [VPermOp.eval, VArr.lanes, VArr.ofLanes, ofVDwords, vdword, lo]

theorem trn2_d2 (x y : BitVec 128) : VPermOp.trn2.eval .d2 x y = hi y ++ hi x := by
  simp [VPermOp.eval, VArr.lanes, VArr.ofLanes, ofVDwords, vdword, hi]

/-- REV64 on bytes is SP 800-38D's byte order with the halves swapped. -/
theorem rev64b_eq (x : BitVec 128) : VRevOp.rev64b.eval x = swap (reverseBytesQuad32 x) := by
  apply eq_of_byte_eq; intro i hi
  rw [VRevOp.eval, byte_ofVBytes _ hi, vbyte_eq]
  apply BitVec.eq_of_getLsbD_eq; intro j hj
  rw [getLsbD_byte _ _ hj, getLsbD_byte _ _ hj, getLsbD_swap, getLsbD_reverseBytesQuad32 _ (by omega)]
  simp only [show 8 * i + j < 128 by omega, decide_true, Bool.true_and]
  congr 1
  interval_cases i <;> omega

/-! ## The counter -/

/-- Counter block `c` of `nonce`, as LD1 loads it: `ctr_block` in SP 800-38D's
byte order, reversed into lanes. -/
def ctrLane (nonce : BitVec 96) (c : Nat) : BitVec 128 := reverseBytesQuad32 (ctrBlock nonce c)

/-- `v31`, which the kernels add to the counter: one in the last 32-bit lane. -/
def ctrInc : BitVec 128 := ofVWords 0 0 0 1

theorem eq_of_vword_eq {x y : BitVec 128} (h : ∀ i < 4, vword x i = vword y i) : x = y := by
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  have := congrArg (·.getLsbD (k % 32)) (h (k / 32) (by omega))
  simp only [vword, BitVec.getLsbD_extractLsb', show k % 32 < 32 by omega, decide_true, Bool.true_and,
    show 32 * (k / 32) + k % 32 = k by omega] at this
  exact this

theorem vword_ofVWords (a b c d : BitVec 32) {i : Nat} (hi : i < 4) :
    vword (ofVWords a b c d) i = [a, b, c, d][i]! := by
  apply BitVec.eq_of_getLsbD_eq; intro j hj
  simp only [vword, ofVWords, BitVec.getLsbD_extractLsb', hj, decide_true, Bool.true_and,
    BitVec.getLsbD_append]
  interval_cases i <;> simp only [List.getElem!_cons_zero, List.getElem!_cons_succ] <;>
    split_ifs <;> first | omega | (congr 1; omega)

theorem vword_map2 (f : (w : Nat) → BitVec w → BitVec w → BitVec w) (x y : BitVec 128) {i : Nat} (hi : i < 4) :
    vword (VArr.s4.map2 f x y) i = f 32 (vword x i) (vword y i) := by
  simp only [VArr.map2, vword_ofVWords _ _ _ _ hi]
  interval_cases i <;> rfl

theorem byte_rev32b (x : BitVec 128) {k : Nat} (hk : k < 16) :
    byte (VRevOp.rev32b.eval x) k = byte x (4 * (k / 4) + (3 - k % 4)) := by
  rw [VRevOp.eval, byte_ofVBytes _ hk, vbyte_eq]

/-- REV32 of SP 800-38D's byte order reverses the order of the 32-bit words. -/
theorem vword_rev32b_rev (x : BitVec 128) {i : Nat} (hi : i < 4) :
    vword (VRevOp.rev32b.eval (reverseBytesQuad32 x)) i = vword x (3 - i) := by
  apply BitVec.eq_of_getLsbD_eq; intro j hj
  have hb : ∀ k < 16, byte (VRevOp.rev32b.eval (reverseBytesQuad32 x)) k =
      byte x (4 * (3 - k / 4) + k % 4) := by
    intro k hk
    rw [byte_rev32b _ hk]
    apply BitVec.eq_of_getLsbD_eq; intro m hm
    rw [getLsbD_byte _ _ hm, getLsbD_byte _ _ hm, getLsbD_reverseBytesQuad32 _ (by omega)]
    congr 1; interval_cases k <;> omega
  have := congrArg (·.getLsbD (j % 8)) (hb (4 * i + j / 8) (by omega))
  simp only [getLsbD_byte _ _ (show j % 8 < 8 by omega)] at this
  simp only [vword, BitVec.getLsbD_extractLsb', hj, decide_true, Bool.true_and]
  rw [show 32 * i + j = 8 * (4 * i + j / 8) + j % 8 by omega, this]
  congr 1; omega

theorem vword_ctrBlock_zero (nonce : BitVec 96) (c : Nat) : vword (ctrBlock nonce c) 0 = BitVec.ofNat 32 c := by
  apply BitVec.eq_of_getLsbD_eq; intro j hj
  simp only [vword, ctrBlock, BitVec.getLsbD_extractLsb', BitVec.getLsbD_append, hj, decide_true,
    Bool.true_and, Nat.mul_zero, Nat.zero_add, ite_true]

theorem vword_ctrBlock_succ (nonce : BitVec 96) (c c' : Nat) {i : Nat} (hi : 1 ≤ i) :
    vword (ctrBlock nonce c) i = vword (ctrBlock nonce c') i := by
  apply BitVec.eq_of_getLsbD_eq; intro j hj
  simp only [vword, ctrBlock, BitVec.getLsbD_extractLsb', BitVec.getLsbD_append, hj, decide_true,
    Bool.true_and, show ¬ (32 * i + j < 32) by omega, ite_false]

/-- REV32 undoes itself. -/
theorem rev32b_rev32b (x : BitVec 128) : VRevOp.rev32b.eval (VRevOp.rev32b.eval x) = x := by
  apply eq_of_byte_eq; intro i hi
  rw [byte_rev32b _ hi, byte_rev32b _ (by omega)]
  congr 1; interval_cases i <;> rfl

/-- ADD of `ctrInc` to the 32-bit lanes of a counter block, REV32 applied,
steps it. -/
theorem add_ctr (nonce : BitVec 96) (c : Nat) :
    VArr.s4.map2 (fun _ x y => x + y) (VRevOp.rev32b.eval (ctrLane nonce c)) ctrInc =
      VRevOp.rev32b.eval (ctrLane nonce (c + 1)) := by
  apply eq_of_vword_eq; intro i hi
  rw [vword_map2 _ _ _ hi, ctrLane, ctrLane, vword_rev32b_rev _ hi, vword_rev32b_rev _ hi, ctrInc,
    vword_ofVWords _ _ _ _ hi]
  interval_cases i
  · simp [vword_ctrBlock_succ nonce c (c + 1) (show 1 ≤ 3 - 0 by omega)]
  · simp [vword_ctrBlock_succ nonce c (c + 1) (show 1 ≤ 3 - 1 by omega)]
  · simp [vword_ctrBlock_succ nonce c (c + 1) (show 1 ≤ 3 - 2 by omega)]
  · simp [vword_ctrBlock_zero, BitVec.ofNat_add]

end rind.aarch64.gcm8x192
