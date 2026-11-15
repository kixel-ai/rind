import Rind.X86_64.Lanes512
open Aeneas Aeneas.Std Result rind.vale rind.simd Polynomial

/-!
# rind's AVX-512 GHASH

`Rind.X86_64.AesGcmModel`'s `_mul16`, `_mul_tail`, and `GhashTableAvx512::add`
hash blocks as `ClmulTable::add` does, for a table of the key's 16 powers:
each lane sums schoolbook products of blocks with descending powers and folds
the sum once by the reflected modulus, which is `Rind.Gf128`'s `reduce_sum`
of the lane's products, and the lanes' folds are XORed.
-/

local notation "P" => Polynomial (ZMod 2)

set_option maxRecDepth 20000

namespace rind.x86_64

/-- The 512-bit GHASH's powers for the key `H`: H^16 down to H, each shifted
as Vale's `shift_key_1` does. -/
def Avx512Powers (H : P) (t : low.x86_64.ghash.GhashTableAvx512) : Prop :=
  ∃ s, low.x86_64.aes_gcm_vaes.VaesKernel.powers t.vaes = ok s ∧ s.val.length = 16 ∧
    ∀ i < 16, toPoly s.val[i]! = shiftKey1 128 gf128ModulusLowTerms (gPower H (16 - i))

/-! ## Folding a lane -/

theorem fold_eq (L M Hh : BitVec 128) :
    clmul c64 (lo (clmul c64 (lo L) ^^^ swap L ^^^ M)) ^^^ swap (clmul c64 (lo L) ^^^ swap L ^^^ M) ^^^ Hh =
      reduceModel L (M ^^^ L ^^^ Hh) Hh := by
  simp only [reduceModel]
  generalize clmul c64 (lo L) = a
  have e : M ^^^ L ^^^ Hh ^^^ L ^^^ Hh ^^^ swap L ^^^ a = a ^^^ swap L ^^^ M := by
    apply BitVec.eq_of_getLsbD_eq; intro k hk
    simp only [BitVec.getLsbD_xor]
    cases M.getLsbD k <;> cases L.getLsbD k <;> cases Hh.getLsbD k <;> cases (swap L).getLsbD k <;>
      cases a.getLsbD k <;> rfl
  rw [e]
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp only [BitVec.getLsbD_xor]
  cases Hh.getLsbD k <;> cases (swap (a ^^^ swap L ^^^ M)).getLsbD k <;>
    cases (clmul c64 (lo (a ^^^ swap L ^^^ M))).getLsbD k <;> rfl

/-- A lane's schoolbook sum, folded, is the sum of its products' own
reductions. -/
theorem fold_sum (L M Hh : BitVec 128) (ps : List (BitVec 128 × BitVec 128))
    (hk : toPoly L + X ^ 64 * toPoly M + X ^ 128 * toPoly Hh = (ps.map fun p => toPoly p.1 * toPoly p.2).sum) :
    toPoly (reduceModel L (M ^^^ L ^^^ Hh) Hh) = (ps.map fun p => toPoly (mulModel p.1 p.2)).sum := by
  refine reduce_sum _ _ _ ps ?_
  rw [← hk, kara, toPoly_xor, toPoly_xor]
  linear_combination (X ^ 64 * (toPoly L + toPoly Hh)) * two_eq_zero_P

theorem imm_facts :
    (I32.bv 0#i32).toNat % 4 = 0 ∧ (I32.bv 1#i32).toNat % 4 = 1 ∧ (I32.bv 2#i32).toNat % 4 = 2 ∧
    (I32.bv 3#i32).toNat % 4 = 3 ∧ (I32.bv 0#i32).getLsbD 0 = false ∧ (I32.bv 0#i32).getLsbD 4 = false ∧
    (I32.bv 1#i32).getLsbD 0 = true ∧ (I32.bv 1#i32).getLsbD 4 = false ∧
    (I32.bv 16#i32).getLsbD 0 = false ∧ (I32.bv 16#i32).getLsbD 4 = true ∧
    (I32.bv 17#i32).getLsbD 0 = true ∧ (I32.bv 17#i32).getLsbD 4 = true := by decide

theorem polyLo_hi : hi low.x86_64.ghash.polyLo = c64 := by decide

/-! ## `_mul16` -/

/-- `_mul16` of 16 blocks, four to a vector, the first in lane 0, is the sum
of the blocks times H^16 down to H. -/
theorem mul16_spec (H : P) (hH : Small H) (t : low.x86_64.ghash.GhashTableAvx512) (ht : Avx512Powers H t)
    (x : Nat → BitVec 128) :
    ∃ y, low.x86_64.ghash._mul16 t (ofLanes128 fun j => x j) (ofLanes128 fun j => x (4 + j))
      (ofLanes128 fun j => x (8 + j)) (ofLanes128 fun j => x (12 + j)) = ok y ∧
      toPoly y = sumPow H ((List.range 16).map (toPoly ∘ x)) := by
  obtain ⟨s, hs, hl, hp⟩ := ht
  obtain ⟨i0, i1, i2, i3, a0, a4, b0, b4, c0, c4, d0, d4⟩ := imm_facts
  simp only [low.x86_64.ghash._mul16, low.x86_64.ghash.GhashTableAvx512.powers, hs, hl, ite_true, bind_ok]
  simp only [List.range_succ, List.range_zero, List.map_cons, List.map_nil, List.nil_append, List.cons_append,
    List.getElem!_cons_zero, List.getElem!_cons_succ, Nat.mul_zero, Nat.zero_add]
  simp only [broadcast512_eq, clmul512_eq, xor512_eq, ternary512_eq, ternary512q_eq, shuffle512_eq,
    low.x86_64.ghash.sumLanes, extract512_eq, ternary128_eq, core.core_arch.x86.sse2._mm_xor_si128, bind_ok,
    i0, i1, i2, i3, a0, a4, b0, b4, c0, c4, d0, d4, ite_true, ite_false, Bool.false_eq_true, polyLo_hi,
    lane64_0, lane64_1, Nat.add_zero, Nat.reduceMul, Nat.reduceAdd]
  simp only [fold_eq]
  refine ⟨_, rfl, ?_⟩
  have hx : ∀ (a b : BitVec 128), toPoly a * toPoly b = (toPoly (lo a) + X ^ 64 * toPoly (hi a)) *
      (toPoly (lo b) + X ^ 64 * toPoly (hi b)) := fun a b => by rw [← toPoly_halves, ← toPoly_halves]
  rw [toPoly_xor, toPoly_xor, toPoly_xor]
  rw [fold_sum _ _ _ [(x 0, s.val[0]!), (x 4, s.val[4]!), (x 8, s.val[8]!), (x 12, s.val[12]!)] (by
      simp only [toPoly_xor, toPoly_clmul, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, hx]; ring),
    fold_sum _ _ _ [(x 1, s.val[1]!), (x 5, s.val[5]!), (x 9, s.val[9]!), (x 13, s.val[13]!)] (by
      simp only [toPoly_xor, toPoly_clmul, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, hx]; ring),
    fold_sum _ _ _ [(x 2, s.val[2]!), (x 6, s.val[6]!), (x 10, s.val[10]!), (x 14, s.val[14]!)] (by
      simp only [toPoly_xor, toPoly_clmul, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, hx]; ring),
    fold_sum _ _ _ [(x 3, s.val[3]!), (x 7, s.val[7]!), (x 11, s.val[11]!), (x 15, s.val[15]!)] (by
      simp only [toPoly_xor, toPoly_clmul, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, hx]; ring)]
  have hm : ∀ (a : BitVec 128) (i : Nat), i < 16 →
      toPoly (mulModel a s.val[i]!) = gf128MulRev (toPoly a) (gPower H (16 - i)) :=
    fun a i hi => mul_data _ _ _ (small_gPower H hH _) (hp i hi)
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, hm _ _ (by omega : (0:Nat) < 16),
    hm _ _ (by omega : (1:Nat) < 16), hm _ _ (by omega : (2:Nat) < 16), hm _ _ (by omega : (3:Nat) < 16),
    hm _ _ (by omega : (4:Nat) < 16), hm _ _ (by omega : (5:Nat) < 16), hm _ _ (by omega : (6:Nat) < 16),
    hm _ _ (by omega : (7:Nat) < 16), hm _ _ (by omega : (8:Nat) < 16), hm _ _ (by omega : (9:Nat) < 16),
    hm _ _ (by omega : (10:Nat) < 16), hm _ _ (by omega : (11:Nat) < 16), hm _ _ (by omega : (12:Nat) < 16),
    hm _ _ (by omega : (13:Nat) < 16), hm _ _ (by omega : (14:Nat) < 16), hm _ _ (by omega : (15:Nat) < 16),
    sumPow_cons, sumPow_nil, List.length_cons, List.length_nil, Function.comp]
  ring

/-! ## `GhashTableAvx512::add` -/

theorem pshufb_byteswap (v : BitVec 128) : pshufb v 0x00010203_04050607_08090a0b_0c0d0e0f#128 = reverseBytesQuad32 v := by
  have h := shuffle_byteswap v
  simp only [shuffle_epi8_eq, Result.ok.injEq] at h
  exact h

theorem drop_take_drop {α : Type} (l : List α) (a j : Nat) (hj : 16 * j + 16 ≤ 64) :
    (((l.drop a).take 64).drop (16 * j)).take 16 = (l.drop (a + 16 * j)).take 16 := by
  rw [List.drop_take, List.take_take, List.drop_drop, show min 16 (64 - 16 * j) = 16 by omega]

/-- A 64-byte load's lanes are the 16-byte loads of its blocks. -/
theorem loadBytes512_chunk (c : List U8) (v : Nat) :
    loadBytes512 ((c.drop (64 * v)).take 64) = ofLanes128 fun j => loadBytes ((c.drop (16 * (4 * v + j))).take 16) := by
  unfold loadBytes512
  apply ofLanes128_ext
  intro j hj
  rw [drop_take_drop _ _ _ (by omega), show 64 * v + 16 * j = 16 * (4 * v + j) by ring]

theorem getElem!_chunksOf {α : Type} [Inhabited α] (k : Nat) (l : List α) (i : Nat) (hi : i < l.length / k) :
    (chunksOf k l)[i]! = (l.drop (k * i)).take k := by
  simp [chunksOf, hi]

/-- `hash16` of a 256-byte chunk: GHASH of its blocks from `current`. -/
theorem hash16_spec (H : P) (hH : Small H) (t : low.x86_64.ghash.GhashTableAvx512) (ht : Avx512Powers H t)
    (c : List U8) (hc : c.length = 256) (current : BitVec 128) :
    ∃ y, low.x86_64.ghash.hash16 t (ofLanes128 fun _ => 0x00010203_04050607_08090a0b_0c0d0e0f#128)
      ((chunksOf 64 c).map loadBytes512) current = ok y ∧
      toPoly y = ghashPoly H (toPoly current) ((padBlocks c).map toPoly) := by
  let X : Nat → BitVec 128 := fun b => if b = 0 then current ^^^ blockBE ((c.drop 0).take 16)
    else blockBE ((c.drop (16 * b)).take 16)
  obtain ⟨y, hy, hyp⟩ := mul16_spec H hH t ht X
  refine ⟨y, ?_, ?_⟩
  · rw [← hy]
    have hl : c.length / 64 = 4 := by omega
    simp only [low.x86_64.ghash.hash16, chunksOf, hl, List.range_succ, List.range_zero, List.map_cons,
      List.map_nil, List.nil_append, List.cons_append, List.getElem!_cons_zero, List.getElem!_cons_succ,
      ]
    simp only [loadBytes512_chunk, pshufb512_eq, setzero512_eq, insert512_eq, xor512q_eq, bind_ok, pshufb_byteswap]
    have i0 : (I32.bv 0#i32).toNat % 4 = 0 := by decide
    have e0 : (ofLanes128 fun j => reverseBytesQuad32 (loadBytes (List.take 16 (List.drop (16 * (4 * 0 + j)) c))) ^^^
        if j = (I32.bv 0#i32).toNat % 4 then current else 0) = ofLanes128 fun j => X j := by
      apply ofLanes128_ext; intro j hj
      rw [i0]; simp only [X, blockBE]
      by_cases h : j = 0
      · subst h; simp [BitVec.xor_comm]
      · simp [h]
    have ev : ∀ v, 0 < v → (ofLanes128 fun j => reverseBytesQuad32 (loadBytes (List.take 16 (List.drop (16 * (4 * v + j)) c)))) =
        ofLanes128 fun j => X (4 * v + j) := fun v hv => by
      apply ofLanes128_ext; intro j hj
      simp only [X, blockBE]
      have h : ¬(4 * v + j = 0) := by omega
      simp only [h, ite_false]
    rw [e0, ev 1 (by decide), ev 2 (by decide), ev 3 (by decide)]
  · have hpad : padBlocks c = (List.range 16).map fun b => blockBE ((c.drop (16 * b)).take 16) := by
      rw [padBlocks, show chunksRest 16 c = [] from List.eq_nil_of_length_eq_zero (by rw [chunksRest_length, hc])]
      simp [chunksOf, hc]
    have hti : (List.range 16).map X = tailInputs current (padBlocks c) := by
      rw [hpad]; simp [List.range_succ, X, tailInputs]
    rw [hyp, ← sumPow_tailInputs H current _ (by rw [hpad]; simp), ← hti, List.map_map]

