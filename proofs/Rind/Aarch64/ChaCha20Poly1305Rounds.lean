import Rind.Aarch64.ChaCha20Poly1305Named

open VG VG.AArch64 rind.aarch64.asm Rind.AArch64.ChaCha20Poly1305 rind.spec

set_option linter.unusedSimpArgs false

/-!
# ChaCha20's rounds in rind's copy of aws-lc's aarch64 ChaCha20-Poly1305

Seal and open keep ChaCha20 states in NEON registers in two layouts: a
block's rows in four registers (`Rows`), as the one-, two-, and three-block
double rounds `doubleRound1` to `doubleRound3` take them; and four blocks in
vertical lanes, word `i` of block `l` in lane `l` of one register (`Vert`),
beside a fifth in rows, as the halves `roundA` and `roundB` of the
five-block double round take them (`ChaCha20Poly1305Named`). Each register
is four 32-bit lanes, `ofVWords`, and each instruction of the rounds a
lane-wise operation on them (`add_W`, `xor_W`, `rev16_W`, `sli12_W`,
`sli7_W`, `tbl8_W`, and `ext4_W` to `ext12_W` for the lane rotations), so
running a block symbolically leaves every register four lanes of words,
which `simp` then matches against RFC 8439's `innerBlock`
(`Rind/Spec.lean`). `doubleRound1_ok` to `doubleRound3_ok`, `roundA_ok`,
and `roundB_ok` prove each block; `rounds1_ok`, `rounds3_ok`, and
`rounds5_ok` the loops of ten double rounds on `x6` around them.
-/

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


/-! ## The double round over five blocks -/

/-- RFC 8439's column rounds, the first half of `innerBlock`. -/
def colRound (x : List chacha20.Word) : List chacha20.Word :=
  let x := chacha20.quarterRound x 0 4 8 12
  let x := chacha20.quarterRound x 1 5 9 13
  let x := chacha20.quarterRound x 2 6 10 14
  chacha20.quarterRound x 3 7 11 15

/-- RFC 8439's diagonal rounds, the second half. -/
def diagRound (x : List chacha20.Word) : List chacha20.Word :=
  let x := chacha20.quarterRound x 0 5 10 15
  let x := chacha20.quarterRound x 1 6 11 12
  let x := chacha20.quarterRound x 2 7 8 13
  chacha20.quarterRound x 3 4 9 14

theorem innerBlock_eq (x : List chacha20.Word) : chacha20.innerBlock x = diagRound (colRound x) := rfl

theorem colRound_length (x : List chacha20.Word) : (colRound x).length = x.length := by
  simp [colRound, quarterRound_length]

theorem diagRound_length (x : List chacha20.Word) : (diagRound x).length = x.length := by
  simp [diagRound, quarterRound_length]

/-- Word `i` of four blocks' states, block `l`'s in lane `l`. -/
def lanes (a b c d : List chacha20.Word) (i : Nat) : BitVec 128 := W a[i]! b[i]! c[i]! d[i]!

/-- `s` holds four blocks' states in vertical lanes, word `i` in `v<5 (i / 4) + i % 4>`. -/
def Vert (s : S) (a b c d : List chacha20.Word) : Prop :=
  s.vg.v .v0 = lanes a b c d 0 ∧
    s.vg.v .v1 = lanes a b c d 1 ∧
    s.vg.v .v2 = lanes a b c d 2 ∧
    s.vg.v .v3 = lanes a b c d 3 ∧
    s.vg.v .v5 = lanes a b c d 4 ∧
    s.vg.v .v6 = lanes a b c d 5 ∧
    s.vg.v .v7 = lanes a b c d 6 ∧
    s.vg.v .v8 = lanes a b c d 7 ∧
    s.vg.v .v10 = lanes a b c d 8 ∧
    s.vg.v .v11 = lanes a b c d 9 ∧
    s.vg.v .v12 = lanes a b c d 10 ∧
    s.vg.v .v13 = lanes a b c d 11 ∧
    s.vg.v .v15 = lanes a b c d 12 ∧
    s.vg.v .v16 = lanes a b c d 13 ∧
    s.vg.v .v17 = lanes a b c d 14 ∧
    s.vg.v .v18 = lanes a b c d 15

/-- Row `k` of a block's state turned `k` lanes down, as the diagonal rounds take it. -/
def drow (x : List chacha20.Word) (k : Nat) : BitVec 128 :=
  W x[4 * k + k % 4]! x[4 * k + (k + 1) % 4]! x[4 * k + (k + 2) % 4]! x[4 * k + (k + 3) % 4]!

/-- `s` holds the block state `x` in turned rows, row `k` in `r<k>`. -/
def Diag (s : S) (r0 r1 r2 r3 : VReg) (x : List chacha20.Word) : Prop :=
  s.vg.v r0 = drow x 0 ∧ s.vg.v r1 = drow x 1 ∧ s.vg.v r2 = drow x 2 ∧ s.vg.v r3 = drow x 3

/-- `roundA` runs RFC 8439's column rounds on its five blocks, then turns the fifth's rows to its diagonals. -/
theorem roundA_ok (s : S) (a b c d e : List chacha20.Word) (hal : a.length = 16) (hbl : b.length = 16)
    (hcl : c.length = 16) (hdl : d.length = 16) (hel : e.length = 16) (hv : Vert s a b c d)
    (he : Rows s .v4 .v9 .v14 .v19 e) (h26 : s.vg.v .v26 = rot8Tbl) :
    ∃ s', execBlock I roundA s = some (s', []) ∧
      Vert s' (colRound a) (colRound b) (colRound c) (colRound d) ∧ Diag s' .v4 .v9 .v14 .v19 (colRound e) ∧
      s'.vg.mem = s.vg.mem ∧ Frame s s' [.v0, .v1, .v2, .v3, .v4, .v5, .v6, .v7, .v8, .v9, .v10, .v11, .v12, .v13, .v14, .v15, .v16, .v17, .v18, .v19, .v20] [] := by
  obtain ⟨hv0, hv1, hv2, hv3, hv4, hv5, hv6, hv7, hv8, hv9, hv10, hv11, hv12, hv13, hv14, hv15⟩ := hv
  obtain ⟨he0, he1, he2, he3⟩ := he
  simp only [lanes, row, drow, Nat.reduceMul, Nat.reduceAdd, Nat.reduceMod] at hv0 hv1 hv2 hv3 hv4 hv5 hv6 hv7 hv8 hv9 hv10 hv11 hv12 hv13 hv14 hv15 he0 he1 he2 he3
  rw [list16 a hal, list16 b hbl, list16 c hcl, list16 d hdl, list16 e hel]
  apply ex_of_eq
  · rw [execBlock_acc]
    simp only [roundA]
    a64_run [vop, VShiftOp.ok, VArr.esize, Nat.reduceLeDiff, Bool.and_self, decide_true, h26, add_W, xor_W,
      rev16_W, sli12_W, sli7_W, tbl8_W, ext4_W, ext8_W, ext12_W, hv0, hv1, hv2, hv3, hv4, hv5, hv6, hv7, hv8, hv9, hv10, hv11, hv12, hv13, hv14, hv15, he0, he1, he2, he3]
    apply congrArg some; exact Prod.ext rfl rfl
  · exact rfl
  · refine ⟨?_, ?_, ?_, ?_⟩
    · refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩ <;>
      · simp only [lanes, v_setV, reduceCtorEq, ↓reduceIte]
        simp only [colRound, chacha20.quarterRound, chacha20.qr, List.getElem!_cons_succ,
          List.getElem!_cons_zero, List.set_cons_succ, List.set_cons_zero]
    · refine ⟨?_, ?_, ?_, ?_⟩ <;>
      · simp only [row, drow, v_setV, reduceCtorEq, ↓reduceIte, Nat.reduceMul, Nat.reduceAdd, Nat.reduceMod]
        simp only [colRound, chacha20.quarterRound, chacha20.qr, List.getElem!_cons_succ,
          List.getElem!_cons_zero, List.set_cons_succ, List.set_cons_zero]
    all_goals a64_out

/-- `roundB` runs RFC 8439's diagonal rounds on its five blocks, then turns the fifth's rows back. -/
theorem roundB_ok (s : S) (a b c d e : List chacha20.Word) (hal : a.length = 16) (hbl : b.length = 16)
    (hcl : c.length = 16) (hdl : d.length = 16) (hel : e.length = 16) (hv : Vert s a b c d)
    (he : Diag s .v4 .v9 .v14 .v19 e) (h26 : s.vg.v .v26 = rot8Tbl) :
    ∃ s', execBlock I roundB s = some (s', []) ∧
      Vert s' (diagRound a) (diagRound b) (diagRound c) (diagRound d) ∧ Rows s' .v4 .v9 .v14 .v19 (diagRound e) ∧
      s'.vg.mem = s.vg.mem ∧ Frame s s' [.v0, .v1, .v2, .v3, .v4, .v5, .v6, .v7, .v8, .v9, .v10, .v11, .v12, .v13, .v14, .v15, .v16, .v17, .v18, .v19, .v20] [] := by
  obtain ⟨hv0, hv1, hv2, hv3, hv4, hv5, hv6, hv7, hv8, hv9, hv10, hv11, hv12, hv13, hv14, hv15⟩ := hv
  obtain ⟨he0, he1, he2, he3⟩ := he
  simp only [lanes, row, drow, Nat.reduceMul, Nat.reduceAdd, Nat.reduceMod] at hv0 hv1 hv2 hv3 hv4 hv5 hv6 hv7 hv8 hv9 hv10 hv11 hv12 hv13 hv14 hv15 he0 he1 he2 he3
  rw [list16 a hal, list16 b hbl, list16 c hcl, list16 d hdl, list16 e hel]
  apply ex_of_eq
  · rw [execBlock_acc]
    simp only [roundB]
    a64_run [vop, VShiftOp.ok, VArr.esize, Nat.reduceLeDiff, Bool.and_self, decide_true, h26, add_W, xor_W,
      rev16_W, sli12_W, sli7_W, tbl8_W, ext4_W, ext8_W, ext12_W, hv0, hv1, hv2, hv3, hv4, hv5, hv6, hv7, hv8, hv9, hv10, hv11, hv12, hv13, hv14, hv15, he0, he1, he2, he3]
    apply congrArg some; exact Prod.ext rfl rfl
  · exact rfl
  · refine ⟨?_, ?_, ?_, ?_⟩
    · refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩ <;>
      · simp only [lanes, v_setV, reduceCtorEq, ↓reduceIte]
        simp only [diagRound, chacha20.quarterRound, chacha20.qr, List.getElem!_cons_succ,
          List.getElem!_cons_zero, List.set_cons_succ, List.set_cons_zero]
    · refine ⟨?_, ?_, ?_, ?_⟩ <;>
      · simp only [row, drow, v_setV, reduceCtorEq, ↓reduceIte, Nat.reduceMul, Nat.reduceAdd, Nat.reduceMod]
        simp only [diagRound, chacha20.quarterRound, chacha20.qr, List.getElem!_cons_succ,
          List.getElem!_cons_zero, List.set_cons_succ, List.set_cons_zero]
    all_goals a64_out


/-- `roundA` then `roundB`: RFC 8439's double round on each of the five blocks. -/
theorem round5_ok (s : S) (a b c d e : List chacha20.Word) (hal : a.length = 16) (hbl : b.length = 16)
    (hcl : c.length = 16) (hdl : d.length = 16) (hel : e.length = 16) (hv : Vert s a b c d)
    (he : Rows s .v4 .v9 .v14 .v19 e) (h26 : s.vg.v .v26 = rot8Tbl) :
    ∃ s', execBlock I (roundA ++ roundB) s = some (s', []) ∧
      Vert s' (chacha20.innerBlock a) (chacha20.innerBlock b) (chacha20.innerBlock c)
        (chacha20.innerBlock d) ∧ Rows s' .v4 .v9 .v14 .v19 (chacha20.innerBlock e) ∧
      s'.vg.mem = s.vg.mem ∧ Frame s s' [.v0, .v1, .v2, .v3, .v4, .v5, .v6, .v7, .v8, .v9, .v10, .v11, .v12,
        .v13, .v14, .v15, .v16, .v17, .v18, .v19, .v20] [] := by
  obtain ⟨s₁, x₁, hv₁, he₁, hm₁, f₁⟩ := roundA_ok s a b c d e hal hbl hcl hdl hel hv he h26
  obtain ⟨s₂, x₂, hv₂, he₂, hm₂, f₂⟩ := roundB_ok s₁ (colRound a) (colRound b) (colRound c) (colRound d)
    (colRound e) (by rw [colRound_length, hal]) (by rw [colRound_length, hbl])
    (by rw [colRound_length, hcl]) (by rw [colRound_length, hdl]) (by rw [colRound_length, hel]) hv₁ he₁
    (by rw [f₁.v _ (by decide), h26])
  refine ⟨s₂, ?_, hv₂, he₂, hm₂.trans hm₁, f₁.trans f₂⟩
  rw [execBlock_append_of x₁ x₂]; rfl

/-! ## The round loops -/

theorem iterate_length (x : List chacha20.Word) (j : Nat) : (chacha20.innerBlock^[j] x).length = x.length := by
  induction j with
  | zero => rfl
  | succ j ih => rw [Function.iterate_succ_apply', innerBlock_length, ih]

/-- `subs x6, x6, #1` counts a double round off `x6`, and `b.hi` loops while
some are left. -/
theorem subs6_ok (s : S) (j : Nat) (hj : j < 10) (h6 : s.vg.gpr .x6 = BitVec.ofNat 64 (10 - j)) :
    ∃ s', execBlock I [.subsImm .x6 .x6 1] s = some (s', []) ∧
      s'.vg.gpr .x6 = BitVec.ofNat 64 (10 - (j + 1)) ∧ I.eval (.flags .hi) s' = some (decide (j + 1 < 10)) ∧
      s'.vg.v = s.vg.v ∧ s'.vg.mem = s.vg.mem ∧ Frame s s' [] [.x6] := by
  have hlt : (s.vg.gpr .x6).toNat < 2 ^ 63 := by rw [h6, BitVec.toNat_ofNat]; omega
  have fl := subFlags_addWithCarry s.vg .x6 (s.vg.gpr .x6) 1 (by norm_num) hlt
  refine ⟨⟨s.vg.addWithCarry .x .x6 (s.vg.gpr .x6) (~~~BitVec.ofNat 64 1) true, s.x29⟩, ?_, ?_, ?_, rfl, rfl,
    ?_⟩
  · rw [execBlock_acc]; a64_run [and_true]
  · simp only [gpr_addWithCarry, ↓reduceIte, adcV_not, h6]
    rw [ofNat_sub _ _ (by omega) (by omega)]; congr 1
  · show some (CondCode.holds _ .hi) = _
    rw [CondCode.holds, fl.c, fl.zf, h6, BitVec.toNat_ofNat, Nat.mod_eq_of_lt (by omega)]
    by_cases h : j + 1 < 10
    · rw [decide_eq_true (by omega : 1 ≤ 10 - j), decide_eq_false (by omega : ¬ 10 - j = 1),
        decide_eq_true h]; rfl
    · rw [decide_eq_true (by omega : 1 ≤ 10 - j), decide_eq_true (by omega : 10 - j = 1),
        decide_eq_false h]; rfl
  · exact ⟨fun r hr => by simp at hr; simp [hr], fun _ _ => rfl, rfl, rfl, rfl⟩

/-- A loop of ten double rounds on `x6`: `b` then `subs x6, x6, #1`, while `b.hi`. -/
theorem rounds_loop (b : List Ins) (vs : List VReg) (P : Nat → S → Prop)
    (hP : ∀ j s s', s'.vg.v = s.vg.v → P j s → P j s')
    (hstep : ∀ j s, P j s → j < 10 → ∃ s', execBlock I b s = some (s', []) ∧ P (j + 1) s' ∧
      s'.vg.mem = s.vg.mem ∧ Frame s s' vs [])
    (s : S) (h0 : P 0 s) (h6 : s.vg.gpr .x6 = 10#64) :
    ∃ t s', Exec I (.loop (.block (b ++ [.subsImm .x6 .x6 1])) (.flags .hi)) s t s' ∧ P 10 s' ∧
      s'.vg.gpr .x6 = 0#64 ∧ s'.vg.mem = s.vg.mem ∧ Frame s s' vs [.x6] := by
  have := loop_ok (body := .block (b ++ [.subsImm .x6 .x6 1])) (c := .flags .hi)
    (fun j s' => P j s' ∧ s'.vg.gpr .x6 = BitVec.ofNat 64 (10 - j) ∧ s'.vg.mem = s.vg.mem ∧
      Frame s s' vs [.x6]) (fun j => j < 10) (fun j => decide (j + 1 < 10)) (fun _ => []) 1
    (fun j s₀ ⟨hp, h6', hm, f⟩ hj => by
      obtain ⟨s₁, x₁, hp₁, hm₁, f₁⟩ := hstep j s₀ hp hj
      obtain ⟨s₂, x₂, h6₂, hc, hv₂, hm₂, f₂⟩ := subs6_ok s₁ j hj (by rw [f₁.gpr _ (by simp), h6'])
      refine ⟨s₂, Exec.block (by simpa using execBlock_append_of x₁ x₂), hc, hP _ _ _ hv₂ hp₁, h6₂,
        by rw [hm₂, hm₁, hm], f.trans ((f₁.mono (fun _ h => h) (by simp)).trans (f₂.mono (by simp) ?_))⟩
      simp)
    9 0 s ⟨h0, by rw [h6], rfl, Frame.refl _ _ _⟩ (fun i hi => by omega)
    (fun i hi => by simp only [decide_eq_true_eq]; omega) (by decide)
  obtain ⟨s', x, hp, h6', hm, f⟩ := this
  exact ⟨_, s', x, hp, by rw [h6'], hm, f⟩

/-- Ten double rounds on one block, as `open`'s first block and its 64-byte tail take them. -/
theorem rounds1_ok (s : S) (x : List chacha20.Word) (hxl : x.length = 16)
    (hx : Rows s .v0 .v5 .v10 .v15 x) (h26 : s.vg.v .v26 = rot8Tbl) (h6 : s.vg.gpr .x6 = 10#64) :
    ∃ t s', Exec I (.loop (.block (doubleRound1 ++ [.subsImm .x6 .x6 1])) (.flags .hi)) s t s' ∧
      Rows s' .v0 .v5 .v10 .v15 (chacha20.innerBlock^[10] x) ∧ s'.vg.gpr .x6 = 0#64 ∧
      s'.vg.mem = s.vg.mem ∧ Frame s s' [.v0, .v5, .v10, .v15, .v20] [.x6] := by
  obtain ⟨t, s', x', ⟨h1, -⟩, h6', hm, f⟩ := rounds_loop doubleRound1 _
    (fun j s => Rows s .v0 .v5 .v10 .v15 (chacha20.innerBlock^[j] x) ∧ s.vg.v .v26 = rot8Tbl)
    (fun j s s' hv h => by simpa only [Rows, hv] using h)
    (fun j s ⟨h1, h26⟩ _ => by
      obtain ⟨s', x', h1', hm, f⟩ := doubleRound1_ok s _ (by rw [iterate_length, hxl]) h1 h26
      simp only [← Function.iterate_succ_apply' chacha20.innerBlock] at h1'
      exact ⟨s', x', ⟨h1', by rw [f.v _ (by decide), h26]⟩, hm, f⟩)
    s ⟨hx, h26⟩ h6
  exact ⟨t, s', x', h1, h6', hm, f⟩

/-- Ten double rounds on three blocks, as `seal`'s and `open`'s short paths run them. -/
theorem rounds3_ok (s : S) (x y z : List chacha20.Word) (hxl : x.length = 16) (hyl : y.length = 16)
    (hzl : z.length = 16) (hx : Rows s .v0 .v5 .v10 .v15 x) (hy : Rows s .v1 .v6 .v11 .v16 y)
    (hz : Rows s .v2 .v7 .v12 .v17 z) (h26 : s.vg.v .v26 = rot8Tbl) (h6 : s.vg.gpr .x6 = 10#64) :
    ∃ t s', Exec I (.loop (.block (doubleRound3 ++ [.subsImm .x6 .x6 1])) (.flags .hi)) s t s' ∧
      Rows s' .v0 .v5 .v10 .v15 (chacha20.innerBlock^[10] x) ∧
      Rows s' .v1 .v6 .v11 .v16 (chacha20.innerBlock^[10] y) ∧
      Rows s' .v2 .v7 .v12 .v17 (chacha20.innerBlock^[10] z) ∧ s'.vg.gpr .x6 = 0#64 ∧
      s'.vg.mem = s.vg.mem ∧
      Frame s s' [.v0, .v1, .v2, .v5, .v6, .v7, .v10, .v11, .v12, .v15, .v16, .v17, .v20] [.x6] := by
  obtain ⟨t, s', x', ⟨h1, h2, h3, -⟩, h6', hm, f⟩ := rounds_loop doubleRound3 _
    (fun j s => Rows s .v0 .v5 .v10 .v15 (chacha20.innerBlock^[j] x) ∧
      Rows s .v1 .v6 .v11 .v16 (chacha20.innerBlock^[j] y) ∧
      Rows s .v2 .v7 .v12 .v17 (chacha20.innerBlock^[j] z) ∧ s.vg.v .v26 = rot8Tbl)
    (fun j s s' hv h => by simpa only [Rows, hv] using h)
    (fun j s ⟨h1, h2, h3, h26⟩ _ => by
      obtain ⟨s', x', h1', h2', h3', hm, f⟩ := doubleRound3_ok s _ _ _ (by rw [iterate_length, hxl])
        (by rw [iterate_length, hyl]) (by rw [iterate_length, hzl]) h1 h2 h3 h26
      simp only [← Function.iterate_succ_apply' chacha20.innerBlock] at h1' h2' h3'
      exact ⟨s', x', ⟨h1', h2', h3', by rw [f.v _ (by decide), h26]⟩, hm, f⟩)
    s ⟨hx, hy, hz, h26⟩ h6
  exact ⟨t, s', x', h1, h2, h3, h6', hm, f⟩

/-- Ten double rounds on the five blocks, as `seal`'s first 320 bytes take them. -/
theorem rounds5_ok (s : S) (a b c d e : List chacha20.Word) (hal : a.length = 16) (hbl : b.length = 16)
    (hcl : c.length = 16) (hdl : d.length = 16) (hel : e.length = 16) (hv : Vert s a b c d)
    (he : Rows s .v4 .v9 .v14 .v19 e) (h26 : s.vg.v .v26 = rot8Tbl) (h6 : s.vg.gpr .x6 = 10#64) :
    ∃ t s', Exec I (.loop (.block (roundA ++ roundB ++ [.subsImm .x6 .x6 1])) (.flags .hi)) s t s' ∧
      Vert s' (chacha20.innerBlock^[10] a) (chacha20.innerBlock^[10] b) (chacha20.innerBlock^[10] c)
        (chacha20.innerBlock^[10] d) ∧ Rows s' .v4 .v9 .v14 .v19 (chacha20.innerBlock^[10] e) ∧
      s'.vg.gpr .x6 = 0#64 ∧ s'.vg.mem = s.vg.mem ∧
      Frame s s' [.v0, .v1, .v2, .v3, .v4, .v5, .v6, .v7, .v8, .v9, .v10, .v11, .v12, .v13, .v14, .v15, .v16,
        .v17, .v18, .v19, .v20] [.x6] := by
  obtain ⟨t, s', x', ⟨h1, h2, -⟩, h6', hm, f⟩ := rounds_loop (roundA ++ roundB) _
    (fun j s => Vert s (chacha20.innerBlock^[j] a) (chacha20.innerBlock^[j] b) (chacha20.innerBlock^[j] c)
      (chacha20.innerBlock^[j] d) ∧ Rows s .v4 .v9 .v14 .v19 (chacha20.innerBlock^[j] e) ∧
      s.vg.v .v26 = rot8Tbl)
    (fun j s s' hv h => by simpa only [Vert, Rows, hv] using h)
    (fun j s ⟨h1, h2, h26⟩ _ => by
      obtain ⟨s', x', h1', h2', hm, f⟩ := round5_ok s _ _ _ _ _ (by rw [iterate_length, hal])
        (by rw [iterate_length, hbl]) (by rw [iterate_length, hcl]) (by rw [iterate_length, hdl])
        (by rw [iterate_length, hel]) h1 h2 h26
      simp only [← Function.iterate_succ_apply' chacha20.innerBlock] at h1' h2'
      exact ⟨s', x', ⟨h1', h2', by rw [f.v _ (by decide), h26]⟩, hm, f⟩)
    s ⟨hv, he, h26⟩ h6
  exact ⟨t, s', x', h1, h2, h6', hm, f⟩

end rind.aarch64.chacha20poly1305asm

/-- info: 'rind.aarch64.chacha20poly1305asm.rounds1_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms rind.aarch64.chacha20poly1305asm.rounds1_ok

/-- info: 'rind.aarch64.chacha20poly1305asm.rounds3_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms rind.aarch64.chacha20poly1305asm.rounds3_ok

/-- info: 'rind.aarch64.chacha20poly1305asm.rounds5_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms rind.aarch64.chacha20poly1305asm.rounds5_ok
