import Rind.Aarch64.ChaCha20Poly1305Named

open VG VG.AArch64 rind.aarch64.asm Rind.AArch64.ChaCha20Poly1305 rind.spec

set_option linter.unusedSimpArgs false

namespace rind.aarch64.chacha20poly1305asm

/-! ## Vectors as four 32-bit lanes -/

local notation "W" => ofVWords

@[simp] theorem vword_W0 (a b c d : BitVec 32) : vword (W a b c d) 0 = a := by
  simp only [vword, ofVWords]; bv_decide
@[simp] theorem vword_W1 (a b c d : BitVec 32) : vword (W a b c d) 1 = b := by
  simp only [vword, ofVWords]; bv_decide
@[simp] theorem vword_W2 (a b c d : BitVec 32) : vword (W a b c d) 2 = c := by
  simp only [vword, ofVWords]; bv_decide
@[simp] theorem vword_W3 (a b c d : BitVec 32) : vword (W a b c d) 3 = d := by
  simp only [vword, ofVWords]; bv_decide

theorem add_W (a0 a1 a2 a3 b0 b1 b2 b3 : BitVec 32) :
    VArr.s4.map2 (fun _ x y => x + y) (W a0 a1 a2 a3) (W b0 b1 b2 b3) =
      W (a0 + b0) (a1 + b1) (a2 + b2) (a3 + b3) := by
  simp only [VArr.map2, vword_W0, vword_W1, vword_W2, vword_W3]

theorem getLsbD_W (a b c d : BitVec 32) (k : Nat) :
    (W a b c d).getLsbD k = if k < 32 then a.getLsbD k else if k < 64 then b.getLsbD (k - 32)
      else if k < 96 then c.getLsbD (k - 64) else d.getLsbD (k - 96) := by
  simp only [ofVWords, BitVec.getLsbD_append]
  split_ifs <;> first | rfl | omega

theorem getLsbD_ofVBytes (f : Nat → BitVec 8) (k : Nat) (hk : k < 128) :
    (ofVBytes f).getLsbD k = (f (k / 8)).getLsbD (k % 8) := by
  simp only [ofVBytes, BitVec.getLsbD_append]
  interval_cases k <;> simp only [Nat.reduceLT, Nat.reduceSub, Nat.reduceDiv, Nat.reduceMod, ↓reduceIte]

theorem getLsbD_vbyte (x : BitVec 128) (e j : Nat) :
    (vbyte x e).getLsbD j = (decide (j < 8) && x.getLsbD (8 * e + j)) := by
  simp only [vbyte, BitVec.getLsbD_extractLsb']

/-- Proves an identity of 128-bit vectors bit by bit, each a bit of a lane. -/
macro "lane_bits" : tactic => `(tactic| (
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp only [getLsbD_ofVBytes _ _ hk, getLsbD_vbyte, getLsbD_W, BitVec.getLsbD_extractLsb',
    BitVec.getLsbD_rotateLeft, BitVec.getLsbD_ushiftRight, BitVec.getLsbD_append]
  interval_cases k <;> simp only [Nat.reduceLT, Nat.reduceSub, Nat.reduceAdd, Nat.reduceMod,
    Nat.reduceMul, Nat.reduceDiv, ↓reduceIte, decide_true, decide_false, Bool.true_and,
    Bool.false_and]))

theorem xor_W (a0 a1 a2 a3 b0 b1 b2 b3 : BitVec 32) :
    W a0 a1 a2 a3 ^^^ W b0 b1 b2 b3 = W (a0 ^^^ b0) (a1 ^^^ b1) (a2 ^^^ b2) (a3 ^^^ b3) := by
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp only [BitVec.getLsbD_xor, getLsbD_W]
  split_ifs <;> rfl

theorem rev16_W (a b c d : BitVec 32) :
    VRevOp.eval .rev32h (W a b c d) = W (a.rotateLeft 16) (b.rotateLeft 16) (c.rotateLeft 16) (d.rotateLeft 16) := by
  simp only [VRevOp.eval]
  lane_bits

theorem sli12_W (c : BitVec 128) (b0 b1 b2 b3 : BitVec 32) :
    VArr.s4.map2 (fun w x y => VShiftOp.eval .sli 12 w x y)
      (VArr.s4.map2 (fun w x y => VShiftOp.eval .ushr 20 w x y) c (W b0 b1 b2 b3)) (W b0 b1 b2 b3) =
      W (b0.rotateLeft 12) (b1.rotateLeft 12) (b2.rotateLeft 12) (b3.rotateLeft 12) := by
  have e : ∀ b : BitVec 32, (b >>> 20 &&& ~~~(BitVec.allOnes 32 <<< 12)) ||| b <<< 12 = b.rotateLeft 12 := by
    intro b; apply BitVec.eq_of_getLsbD_eq; intro i hi; interval_cases i <;> simp
  simp only [VArr.map2, VShiftOp.eval, vword_W0, vword_W1, vword_W2, vword_W3, e]

theorem sli7_W (c : BitVec 128) (b0 b1 b2 b3 : BitVec 32) :
    VArr.s4.map2 (fun w x y => VShiftOp.eval .sli 7 w x y)
      (VArr.s4.map2 (fun w x y => VShiftOp.eval .ushr 25 w x y) c (W b0 b1 b2 b3)) (W b0 b1 b2 b3) =
      W (b0.rotateLeft 7) (b1.rotateLeft 7) (b2.rotateLeft 7) (b3.rotateLeft 7) := by
  have e : ∀ b : BitVec 32, (b >>> 25 &&& ~~~(BitVec.allOnes 32 <<< 7)) ||| b <<< 7 = b.rotateLeft 7 := by
    intro b; apply BitVec.eq_of_getLsbD_eq; intro i hi; interval_cases i <;> simp
  simp only [VArr.map2, VShiftOp.eval, vword_W0, vword_W1, vword_W2, vword_W3, e]

/-- The TBL indices that rotate each 32-bit lane left by 8, as `consts`'
words 8 to 11 hold them. -/
def rot8Tbl : BitVec 128 := W 0x02010003 0x06050407 0x0a09080b 0x0e0d0c0f

theorem tbl8_W (a b c d : BitVec 32) :
    (ofVBytes fun i => if (vbyte rot8Tbl i).toNat < 16 then vbyte (W a b c d) (vbyte rot8Tbl i).toNat else 0) =
      W (a.rotateLeft 8) (b.rotateLeft 8) (c.rotateLeft 8) (d.rotateLeft 8) := by
  have t : ∀ i, i < 16 → (vbyte rot8Tbl i).toNat = 4 * (i / 4) + (i % 4 + 3) % 4 := by
    intro i hi; interval_cases i <;> rfl
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp only [getLsbD_ofVBytes _ _ hk, getLsbD_W, BitVec.getLsbD_rotateLeft]
  interval_cases k <;> simp only [Nat.reduceLT, Nat.reduceSub, Nat.reduceAdd, Nat.reduceMod,
    Nat.reduceMul, Nat.reduceDiv, t 0 (by decide), t 1 (by decide), t 2 (by decide), t 3 (by decide),
    t 4 (by decide), t 5 (by decide), t 6 (by decide), t 7 (by decide), t 8 (by decide),
    t 9 (by decide), t 10 (by decide), t 11 (by decide), t 12 (by decide), t 13 (by decide),
    t 14 (by decide), t 15 (by decide), ↓reduceIte, getLsbD_vbyte, getLsbD_W, decide_true,
    decide_false, Bool.true_and, Bool.false_and]

theorem ext4_W (a b c d : BitVec 32) : ((W a b c d ++ W a b c d) >>> 32).extractLsb' 0 128 = W b c d a := by
  lane_bits

theorem ext8_W (a b c d : BitVec 32) : ((W a b c d ++ W a b c d) >>> 64).extractLsb' 0 128 = W c d a b := by
  lane_bits

theorem ext12_W (a b c d : BitVec 32) : ((W a b c d ++ W a b c d) >>> 96).extractLsb' 0 128 = W d a b c := by
  lane_bits

/-! ## The double rounds -/

/-- Row `k` of a block's state, as one vector register holds it. -/
def row (x : List chacha20.Word) (k : Nat) : BitVec 128 := W x[4 * k]! x[4 * k + 1]! x[4 * k + 2]! x[4 * k + 3]!

/-- `s` holds the block state `x` in rows, row `k` in `r<k>`. -/
def Rows (s : S) (r0 r1 r2 r3 : VReg) (x : List chacha20.Word) : Prop :=
  s.vg.v r0 = row x 0 ∧ s.vg.v r1 = row x 1 ∧ s.vg.v r2 = row x 2 ∧ s.vg.v r3 = row x 3

/-- A state is its sixteen words. -/
theorem list16 {α : Type} [Inhabited α] (x : List α) (h : x.length = 16) :
    x = [x[0]!, x[1]!, x[2]!, x[3]!, x[4]!, x[5]!, x[6]!, x[7]!, x[8]!, x[9]!, x[10]!, x[11]!, x[12]!,
      x[13]!, x[14]!, x[15]!] := by
  apply List.ext_getElem (by simp [h])
  intro i h1 _
  rw [h] at h1
  interval_cases i <;> simp [List.getElem!_eq_getElem?_getD, List.getElem?_eq_getElem, h]

theorem quarterRound_length (x : List chacha20.Word) (a b c d : Nat) :
    (chacha20.quarterRound x a b c d).length = x.length := by
  simp [chacha20.quarterRound]

theorem innerBlock_length (x : List chacha20.Word) : (chacha20.innerBlock x).length = x.length := by
  simp [chacha20.innerBlock, quarterRound_length]

/-- `doubleRound1` runs RFC 8439's double round on each of its 1 block, block `i`'s rows in
`v<i>`, `v<5 + i>`, `v<10 + i>`, and `v<15 + i>`, with `v26` the rotation's TBL indices. -/
theorem doubleRound1_ok (s : S) (x : List chacha20.Word) (hxl : x.length = 16)
    (hx : Rows s .v0 .v5 .v10 .v15 x) (h26 : s.vg.v .v26 = rot8Tbl) :
    ∃ s', execBlock I doubleRound1 s = some (s', []) ∧ Rows s' .v0 .v5 .v10 .v15 (chacha20.innerBlock x) ∧
      s'.vg.mem = s.vg.mem ∧ Frame s s' [.v0, .v5, .v10, .v15, .v20] [] := by
  obtain ⟨hx0, hx1, hx2, hx3⟩ := hx
  simp only [row, Nat.reduceMul, Nat.reduceAdd] at hx0 hx1 hx2 hx3
  rw [list16 x hxl]
  apply ex_of_eq
  · rw [execBlock_acc]
    simp only [doubleRound1]
    a64_run [vop, VShiftOp.ok, VArr.esize, Nat.reduceLeDiff, Bool.and_self, decide_true, h26, add_W, xor_W,
      rev16_W, sli12_W, sli7_W, tbl8_W, ext4_W, ext8_W, ext12_W, hx0, hx1, hx2, hx3]
    apply congrArg some; exact Prod.ext rfl rfl
  · exact rfl
  · refine ⟨?_, ?_, ?_⟩
    iterate 1
      refine ⟨?_, ?_, ?_, ?_⟩ <;>
      · simp only [Rows, row, v_setV, reduceCtorEq, ↓reduceIte, Nat.reduceMul, Nat.reduceAdd]
        simp only [chacha20.innerBlock, chacha20.quarterRound, chacha20.qr, List.getElem!_cons_succ,
          List.getElem!_cons_zero, List.set_cons_succ, List.set_cons_zero]
    all_goals a64_out

/-- `doubleRound2` runs RFC 8439's double round on each of its 2 blocks, block `i`'s rows in
`v<i>`, `v<5 + i>`, `v<10 + i>`, and `v<15 + i>`, with `v26` the rotation's TBL indices. -/
theorem doubleRound2_ok (s : S) (x y : List chacha20.Word) (hxl : x.length = 16) (hyl : y.length = 16)
    (hx : Rows s .v0 .v5 .v10 .v15 x) (hy : Rows s .v1 .v6 .v11 .v16 y) (h26 : s.vg.v .v26 = rot8Tbl) :
    ∃ s', execBlock I doubleRound2 s = some (s', []) ∧ Rows s' .v0 .v5 .v10 .v15 (chacha20.innerBlock x) ∧ Rows s' .v1 .v6 .v11 .v16 (chacha20.innerBlock y) ∧
      s'.vg.mem = s.vg.mem ∧ Frame s s' [.v0, .v1, .v5, .v6, .v10, .v11, .v15, .v16, .v20] [] := by
  obtain ⟨hx0, hx1, hx2, hx3⟩ := hx
  simp only [row, Nat.reduceMul, Nat.reduceAdd] at hx0 hx1 hx2 hx3
  obtain ⟨hy0, hy1, hy2, hy3⟩ := hy
  simp only [row, Nat.reduceMul, Nat.reduceAdd] at hy0 hy1 hy2 hy3
  rw [list16 x hxl, list16 y hyl]
  apply ex_of_eq
  · rw [execBlock_acc]
    simp only [doubleRound2]
    a64_run [vop, VShiftOp.ok, VArr.esize, Nat.reduceLeDiff, Bool.and_self, decide_true, h26, add_W, xor_W,
      rev16_W, sli12_W, sli7_W, tbl8_W, ext4_W, ext8_W, ext12_W, hx0, hx1, hx2, hx3, hy0, hy1, hy2, hy3]
    apply congrArg some; exact Prod.ext rfl rfl
  · exact rfl
  · refine ⟨?_, ?_, ?_, ?_⟩
    iterate 2
      refine ⟨?_, ?_, ?_, ?_⟩ <;>
      · simp only [Rows, row, v_setV, reduceCtorEq, ↓reduceIte, Nat.reduceMul, Nat.reduceAdd]
        simp only [chacha20.innerBlock, chacha20.quarterRound, chacha20.qr, List.getElem!_cons_succ,
          List.getElem!_cons_zero, List.set_cons_succ, List.set_cons_zero]
    all_goals a64_out

/-- `doubleRound3` runs RFC 8439's double round on each of its 3 blocks, block `i`'s rows in
`v<i>`, `v<5 + i>`, `v<10 + i>`, and `v<15 + i>`, with `v26` the rotation's TBL indices. -/
theorem doubleRound3_ok (s : S) (x y z : List chacha20.Word) (hxl : x.length = 16) (hyl : y.length = 16) (hzl : z.length = 16)
    (hx : Rows s .v0 .v5 .v10 .v15 x) (hy : Rows s .v1 .v6 .v11 .v16 y) (hz : Rows s .v2 .v7 .v12 .v17 z) (h26 : s.vg.v .v26 = rot8Tbl) :
    ∃ s', execBlock I doubleRound3 s = some (s', []) ∧ Rows s' .v0 .v5 .v10 .v15 (chacha20.innerBlock x) ∧ Rows s' .v1 .v6 .v11 .v16 (chacha20.innerBlock y) ∧ Rows s' .v2 .v7 .v12 .v17 (chacha20.innerBlock z) ∧
      s'.vg.mem = s.vg.mem ∧ Frame s s' [.v0, .v1, .v2, .v5, .v6, .v7, .v10, .v11, .v12, .v15, .v16, .v17, .v20] [] := by
  obtain ⟨hx0, hx1, hx2, hx3⟩ := hx
  simp only [row, Nat.reduceMul, Nat.reduceAdd] at hx0 hx1 hx2 hx3
  obtain ⟨hy0, hy1, hy2, hy3⟩ := hy
  simp only [row, Nat.reduceMul, Nat.reduceAdd] at hy0 hy1 hy2 hy3
  obtain ⟨hz0, hz1, hz2, hz3⟩ := hz
  simp only [row, Nat.reduceMul, Nat.reduceAdd] at hz0 hz1 hz2 hz3
  rw [list16 x hxl, list16 y hyl, list16 z hzl]
  apply ex_of_eq
  · rw [execBlock_acc]
    simp only [doubleRound3]
    a64_run [vop, VShiftOp.ok, VArr.esize, Nat.reduceLeDiff, Bool.and_self, decide_true, h26, add_W, xor_W,
      rev16_W, sli12_W, sli7_W, tbl8_W, ext4_W, ext8_W, ext12_W, hx0, hx1, hx2, hx3, hy0, hy1, hy2, hy3, hz0, hz1, hz2, hz3]
    apply congrArg some; exact Prod.ext rfl rfl
  · exact rfl
  · refine ⟨?_, ?_, ?_, ?_, ?_⟩
    iterate 3
      refine ⟨?_, ?_, ?_, ?_⟩ <;>
      · simp only [Rows, row, v_setV, reduceCtorEq, ↓reduceIte, Nat.reduceMul, Nat.reduceAdd]
        simp only [chacha20.innerBlock, chacha20.quarterRound, chacha20.qr, List.getElem!_cons_succ,
          List.getElem!_cons_zero, List.set_cons_succ, List.set_cons_zero]
    all_goals a64_out


end rind.aarch64.chacha20poly1305asm

#print axioms rind.aarch64.chacha20poly1305asm.rev16_W
#print axioms rind.aarch64.chacha20poly1305asm.ext4_W
#print axioms rind.aarch64.chacha20poly1305asm.tbl8_W
#print axioms rind.aarch64.chacha20poly1305asm.sli12_W
#print axioms rind.aarch64.chacha20poly1305asm.xor_W
