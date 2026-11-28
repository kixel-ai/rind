import Rind.Aarch64.ChaCha20Poly1305Rounds

open VG VG.AArch64 rind.aarch64.asm Rind.AArch64.ChaCha20Poly1305 rind.spec

set_option linter.unusedSimpArgs false

/-!
# ChaCha20's block function in rind's copy of aws-lc's aarch64 ChaCha20-Poly1305

RFC 8439's block function (`chacha20.block`, `Rind/Spec.lean`) runs ten
double rounds on a state and adds the state back (`keyBlock`). The programs
keep the state's rows in `v24` (the constants), `v28` and `v29` (the key),
and `v30` (the counter and the nonce), and derive each block's state from
them by adding to the counter (`bump`). `setup128_ok` and `final128_ok`
prove the short paths' blocks before and after their rounds
(`rounds3_ok`): the key stream of the next two counters, and Poly1305's
key from the counter itself. `finalInit_ok` proves seal's first five
blocks after theirs (`rounds5_ok`): it turns the four vertical blocks'
key streams to rows (`zip1s_W` to `zip2d_W`), and takes Poly1305's key
from the fifth; `finalMain_ok` proves seal's main loop's five blocks after
theirs, the fifth's counter one past the vertical blocks' (`counter5`),
and moves the counters in `v25` on five.
-/

namespace rind.aarch64.chacha20poly1305asm

local notation "W" => ofVWords

/-! ## Lanes -/

theorem and_W (a0 a1 a2 a3 b0 b1 b2 b3 : BitVec 32) :
    W a0 a1 a2 a3 &&& W b0 b1 b2 b3 = W (a0 &&& b0) (a1 &&& b1) (a2 &&& b2) (a3 &&& b3) := by
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp only [BitVec.getLsbD_and, getLsbD_W]
  split_ifs <;> rfl

theorem zero_W : (0 : BitVec 128) = W 0 0 0 0 := by
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp only [getLsbD_W]
  split_ifs <;> simp

theorem zero_W' : 0#128 = W 0 0 0 0 := zero_W

theorem add_zero32 (x : BitVec 32) : x + (0 : BitVec 32) = x := BitVec.add_zero x
theorem one32 : (1 : BitVec 32) = 1#32 := rfl

/-- `movz` of a small immediate, as a lane's word. -/
theorem movz_w (n : Nat) (h : n < 2 ^ 16) :
    BitVec.setWidth 32 (BitVec.setWidth 64 (BitVec.ofNat 16 n) <<< 0) = BitVec.ofNat 32 n := by
  apply BitVec.eq_of_toNat_eq
  simp only [BitVec.shiftLeft_zero, BitVec.toNat_setWidth, BitVec.toNat_ofNat]
  omega

/-- The general registers, vector registers, and memory a block leaves, read
through its folded updates. -/
macro "a64_read" : tactic => `(tactic| simp only [gpr_write, gpr_write_w, v_write, mem_write, gpr_addWithCarry,
  v_addWithCarry, mem_addWithCarry, gpr_flagsAdd, v_flagsAdd, mem_flagsAdd, v_setV, gpr_setV, mem_setV,
  gpr_setMem, v_setMem, mem_setMem, reduceCtorEq, ↓reduceIte])

/-- `a64_out`, closing each goal with `exact rfl` rather than `rfl`, which
can take long to fail on a register's value. -/
macro "a64_out'" : tactic => `(tactic| (
    repeat' apply And.intro
    all_goals try (apply Frame.mk <;> try intro r hr)
    all_goals try simp only [List.mem_cons, List.not_mem_nil, or_false, not_or] at hr
    all_goals try simp (config := { maxSteps := 4000000 }) only [gpr_write, gpr_write_w, v_write, mem_write,
      sp_write, others_write, gpr_addWithCarry, v_addWithCarry, mem_addWithCarry, sp_addWithCarry,
      others_addWithCarry, gpr_flagsAdd, v_flagsAdd, mem_flagsAdd, sp_flagsAdd, others_flagsAdd, v_setV,
      gpr_setV, mem_setV, sp_setV, others_setV, gpr_setMem, v_setMem, mem_setMem, sp_setMem, others_setMem,
      c_addWithCarry, c_flagsAdd, c_write, c_setV, c_setMem, reduceCtorEq, ↓reduceIte, *]
    all_goals try exact rfl))

theorem setLane0_W (a b c d x : BitVec 32) : setLane (W a b c d) 32 0 x = W x b c d := by
  simp only [setLane, Nat.mul_zero, BitVec.shiftLeft_zero]
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp only [BitVec.getLsbD_or, BitVec.getLsbD_and, BitVec.getLsbD_not, BitVec.getLsbD_setWidth,
    BitVec.getLsbD_allOnes, getLsbD_W, hk, decide_true, Bool.true_and]
  by_cases h : k < 32
  · simp [h]
  · simp [h, BitVec.getLsbD_of_ge x k (by omega)]

theorem getLsbD_ofVDwords (d0 d1 : BitVec 64) (k : Nat) :
    (ofVDwords d0 d1).getLsbD k = if k < 64 then d0.getLsbD k else d1.getLsbD (k - 64) := by
  simp only [ofVDwords, BitVec.getLsbD_append]
theorem zip1d_W (a b c d e f g h : BitVec 32) : VPermOp.eval .zip1 .d2 (W a b c d) (W e f g h) = W a b e f := by
  simp only [VPermOp.eval, VArr.lanes, VArr.ofLanes, List.range_succ, List.range_zero, vdword, List.length_cons, List.length_nil, List.flatMap_cons, List.flatMap_nil, List.nil_append, List.cons_append, List.getD_cons_zero, List.getD_cons_succ, Nat.reduceAdd, Nat.reduceDiv, Nat.reduceMul, List.append_nil]
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp only [getLsbD_ofVDwords, BitVec.getLsbD_setWidth, BitVec.getLsbD_extractLsb', getLsbD_W]
  interval_cases k <;> simp only [Nat.reduceLT, Nat.reduceSub, Nat.reduceAdd, ↓reduceIte, decide_true, decide_false, Bool.true_and, Bool.false_and]
theorem zip2d_W (a b c d e f g h : BitVec 32) : VPermOp.eval .zip2 .d2 (W a b c d) (W e f g h) = W c d g h := by
  simp only [VPermOp.eval, VArr.lanes, VArr.ofLanes, List.range_succ, List.range_zero, vdword, List.length_cons, List.length_nil, List.flatMap_cons, List.flatMap_nil, List.nil_append, List.cons_append, List.getD_cons_zero, List.getD_cons_succ, Nat.reduceAdd, Nat.reduceDiv, Nat.reduceMul, List.append_nil]
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp only [getLsbD_ofVDwords, BitVec.getLsbD_setWidth, BitVec.getLsbD_extractLsb', getLsbD_W]
  interval_cases k <;> simp only [Nat.reduceLT, Nat.reduceSub, Nat.reduceAdd, ↓reduceIte, decide_true, decide_false, Bool.true_and, Bool.false_and]
theorem zip1s_W (a b c d e f g h : BitVec 32) : VPermOp.eval .zip1 .s4 (W a b c d) (W e f g h) = W a e b f := by
  simp [VPermOp.eval, VArr.lanes, VArr.ofLanes, List.range_succ]
theorem zip2s_W (a b c d e f g h : BitVec 32) : VPermOp.eval .zip2 .s4 (W a b c d) (W e f g h) = W c g d h := by
  simp [VPermOp.eval, VArr.lanes, VArr.ofLanes, List.range_succ]
/-! ## The block function -/

/-- The state with `j` added to its counter, word 12. -/
def bump (x : List chacha20.Word) (j : Nat) : List chacha20.Word := x.set 12 (x[12]! + BitVec.ofNat 32 j)

/-- RFC 8439's block function's words: ten double rounds, with the state added back. -/
def keyBlock (x : List chacha20.Word) : List chacha20.Word :=
  List.zipWith (· + ·) (chacha20.innerBlock^[10] x) x

/-- RFC 8439's block function, as `keyBlock` of its state. -/
theorem block_eq (key nonce : List (BitVec 8)) (c : chacha20.Word) :
    chacha20.block key c nonce = (keyBlock ([0x61707865, 0x3320646e, 0x79622d32, 0x6b206574] ++
      chacha20.words key ++ [c] ++ chacha20.words nonce)).flatMap BitVec.toLEBytes := rfl

theorem bump_length (x : List chacha20.Word) (j : Nat) : (bump x j).length = x.length := by
  simp [bump]

theorem bump_get (x : List chacha20.Word) (hx : x.length = 16) (j i : Nat) :
    (bump x j)[i]! = if i = 12 then x[12]! + BitVec.ofNat 32 j else x[i]! := by
  simp only [bump, List.getElem!_eq_getElem?_getD, List.getElem?_set]
  by_cases h : i = 12
  · subst h; simp [hx]
  · simp [h, Ne.symm h]

theorem keyBlock_get (x : List chacha20.Word) (hx : x.length = 16) (i : Nat) (hi : i < 16) :
    (keyBlock x)[i]! = (chacha20.innerBlock^[10] x)[i]! + x[i]! := by
  have h1 : (chacha20.innerBlock^[10] x).length = 16 := by rw [iterate_length, hx]
  simp only [keyBlock, List.getElem!_eq_getElem?_getD, List.getElem?_zipWith,
    List.getElem?_eq_getElem (show i < (chacha20.innerBlock^[10] x).length by omega),
    List.getElem?_eq_getElem (show i < x.length by omega), Option.map_some, Option.getD_some]

/-- The rows of `x`, with `j` added to the counter. -/
theorem rows_bump (x : List chacha20.Word) (hx : x.length = 16) (j : Nat) :
    row (bump x j) 0 = row x 0 ∧ row (bump x j) 1 = row x 1 ∧ row (bump x j) 2 = row x 2 ∧
      row (bump x j) 3 = W (x[12]! + BitVec.ofNat 32 j) x[13]! x[14]! x[15]! := by
  simp [row, bump_get x hx]

/-- Row `k` of a block: its rounds' row plus the state's. -/
theorem row_keyBlock (x : List chacha20.Word) (hx : x.length = 16) (k : Nat) (hk : k < 4) :
    row (keyBlock x) k = VArr.s4.map2 (fun _ a b => a + b) (row (chacha20.innerBlock^[10] x) k) (row x k) := by
  simp only [row]
  rw [keyBlock_get x hx _ (by omega), keyBlock_get x hx (4 * k + 1) (by omega),
    keyBlock_get x hx (4 * k + 2) (by omega), keyBlock_get x hx (4 * k + 3) (by omega), add_W]

/-! ## The short paths' blocks -/

/-- Poly1305's clamp of `r`, as `consts`' words 12 to 15 hold it. -/
def clampW : BitVec 128 := W 0x0fffffff 0x0ffffffc 0x0ffffffc 0x0ffffffc

theorem setup128_ok (s : S) (x : List chacha20.Word) (hx : x.length = 16) (h : Rows s .v24 .v28 .v29 .v30 x) :
    ∃ s', execBlock I setup128 s = some (s', []) ∧ Rows s' .v0 .v5 .v10 .v15 (bump x 1) ∧
      Rows s' .v1 .v6 .v11 .v16 (bump x 2) ∧ Rows s' .v2 .v7 .v12 .v17 x ∧ s'.vg.v .v25 = W 1 0 0 0 ∧
      s'.vg.gpr .x6 = 10#64 ∧ s'.vg.mem = s.vg.mem ∧
      Frame s s' [.v0, .v1, .v2, .v5, .v6, .v7, .v10, .v11, .v12, .v15, .v16, .v17, .v25] [.x6, .x11] := by
  obtain ⟨h0, h1, h2, h3⟩ := h
  obtain ⟨b0, b1, b2, b3⟩ := rows_bump x hx 1
  obtain ⟨c0, c1, c2, c3⟩ := rows_bump x hx 2
  simp only [Rows, b0, b1, b2, b3, c0, c1, c2, c3]
  simp only [row, Nat.reduceMul, Nat.reduceAdd] at h0 h1 h2 h3 ⊢
  apply ex_of_eq
  · rw [execBlock_acc]
    simp only [setup128]
    a64_run [vop, h0, h1, h2, h3, BitVec.xor_self, zero_W', setLane0_W, add_W, BitVec.reduceSetWidth,
      BitVec.reduceHShiftLeft]
    apply congrArg some; exact Prod.ext rfl rfl
  · exact rfl
  · refine ⟨⟨?_, ?_, ?_, ?_⟩, ⟨?_, ?_, ?_, ?_⟩, ⟨?_, ?_, ?_, ?_⟩, ?_, ?_, ?_, ?_⟩
    all_goals try a64_read
    all_goals try (simp only [add_zero, BitVec.add_assoc, BitVec.reduceAdd]; done)
    all_goals a64_out'

theorem final128_ok (s : S) (x : List chacha20.Word) (hx : x.length = 16) (h : Rows s .v24 .v28 .v29 .v30 x)
    (h25 : s.vg.v .v25 = W 1 0 0 0) (h27 : s.vg.v .v27 = clampW)
    (hA : Rows s .v0 .v5 .v10 .v15 (chacha20.innerBlock^[10] (bump x 1)))
    (hB : Rows s .v1 .v6 .v11 .v16 (chacha20.innerBlock^[10] (bump x 2)))
    (hC : Rows s .v2 .v7 .v12 .v17 (chacha20.innerBlock^[10] x)) (h4 : (s.vg.gpr .x4).toNat < 2 ^ 63) :
    ∃ s', execBlock I final128 s = some (s', []) ∧ Rows s' .v0 .v5 .v10 .v15 (keyBlock (bump x 1)) ∧
      Rows s' .v1 .v6 .v11 .v16 (keyBlock (bump x 2)) ∧
      s'.vg.gpr .x16 = (row (keyBlock x) 0 &&& clampW).extractLsb' 0 64 ∧
      s'.vg.gpr .x17 = (row (keyBlock x) 0 &&& clampW).extractLsb' 64 64 ∧
      s'.vg.v .v27 = row (keyBlock x) 1 ∧ SubFlags s'.vg (s.vg.gpr .x4) 16 ∧ s'.vg.mem = s.vg.mem ∧
      Frame s s' [.v0, .v1, .v2, .v5, .v6, .v7, .v10, .v11, .v15, .v16, .v27, .v30] [.x16, .x17] := by
  have h1 : (bump x 1).length = 16 := by rw [bump_length, hx]
  have h2 : (bump x 2).length = 16 := by rw [bump_length, hx]
  obtain ⟨h0, h1', h2', h3⟩ := h
  obtain ⟨a0, a1, a2, a3⟩ := hA
  obtain ⟨b0, b1, b2, b3⟩ := hB
  obtain ⟨c0, c1, -, -⟩ := hC
  simp only [row, Nat.reduceMul, Nat.reduceAdd] at h0 h1' h2' h3 a0 a1 a2 a3 b0 b1 b2 b3 c0 c1
  simp only [Rows]
  simp (disch := decide) only [row, Nat.reduceMul, Nat.reduceAdd, keyBlock_get _ h1, keyBlock_get _ h2,
    keyBlock_get _ hx, bump_get x hx, Nat.reduceEqDiff, ↓reduceIte]
  apply ex_of_eq
  · rw [execBlock_acc]
    simp only [final128]
    a64_run [vop, h0, h1', h2', h3, a0, a1, a2, a3, b0, b1, b2, b3, c0, c1, h25, h27, clampW, add_W, and_W]
    apply congrArg some; exact Prod.ext rfl rfl
  · exact rfl
  · refine ⟨⟨?_, ?_, ?_, ?_⟩, ⟨?_, ?_, ?_, ?_⟩, ?_, ?_, ?_, ?_, ?_, ?_⟩
    all_goals try a64_read
    all_goals try (simp only [add_zero32, one32, BitVec.add_assoc, BitVec.reduceAdd, clampW, and_W]; done)
    case hp.refine_12 => exact subFlags_flagsAdd _ _ _ (by norm_num) h4
    all_goals a64_out'

/-! ## Seal's first five blocks -/

theorem dup4 : BitVec.setWidth 32 (BitVec.setWidth 64 (4 : BitVec 16) <<< 0) = 4#32 := by decide

theorem final_init_counter (y c n : chacha20.Word) : y + n + c = y + (c + n) := by
  rw [BitVec.add_assoc, BitVec.add_comm n]

theorem lit32 : (1 : BitVec 32) = 1#32 ∧ (2 : BitVec 32) = 2#32 ∧ (3 : BitVec 32) = 3#32 ∧
    (4 : BitVec 32) = 4#32 := ⟨rfl, rfl, rfl, rfl⟩

set_option maxRecDepth 8000 in
theorem finalInit_ok (s : S) (x : List chacha20.Word) (hx : x.length = 16) (h : Rows s .v24 .v28 .v29 .v30 x)
    (h25 : s.vg.v .v25 = W 1 2 3 4) (h27 : s.vg.v .v27 = clampW)
    (hv : Vert s (chacha20.innerBlock^[10] (bump x 1)) (chacha20.innerBlock^[10] (bump x 2))
      (chacha20.innerBlock^[10] (bump x 3)) (chacha20.innerBlock^[10] (bump x 4)))
    (he : Rows s .v4 .v9 .v14 .v19 (chacha20.innerBlock^[10] x)) (h4 : (s.vg.gpr .x4).toNat < 2 ^ 63) :
    ∃ s', execBlock I finalInit s = some (s', []) ∧ Rows s' .v0 .v5 .v10 .v15 (keyBlock (bump x 1)) ∧
      Rows s' .v1 .v6 .v11 .v16 (keyBlock (bump x 2)) ∧ Rows s' .v2 .v7 .v12 .v17 (keyBlock (bump x 3)) ∧
      Rows s' .v3 .v8 .v13 .v18 (keyBlock (bump x 4)) ∧ s'.vg.v .v25 = W 5 6 7 8 ∧
      s'.vg.gpr .x16 = (row (keyBlock x) 0 &&& clampW).extractLsb' 0 64 ∧
      s'.vg.gpr .x17 = (row (keyBlock x) 0 &&& clampW).extractLsb' 64 64 ∧
      s'.vg.v .v27 = row (keyBlock x) 1 ∧ SubFlags s'.vg (s.vg.gpr .x4) 16 ∧ s'.vg.mem = s.vg.mem ∧
      Frame s s' [.v0, .v1, .v2, .v3, .v4, .v5, .v6, .v7, .v8, .v9, .v10, .v11, .v12, .v13, .v15, .v16, .v17,
        .v18, .v20, .v21, .v22, .v23, .v25, .v27] [.x11, .x16, .x17] := by
  have l1 : (bump x 1).length = 16 := by rw [bump_length, hx]
  have l2 : (bump x 2).length = 16 := by rw [bump_length, hx]
  have l3 : (bump x 3).length = 16 := by rw [bump_length, hx]
  have l4 : (bump x 4).length = 16 := by rw [bump_length, hx]
  obtain ⟨h0, h1, h2, h3⟩ := h
  obtain ⟨v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15⟩ := hv
  obtain ⟨e0, e1, -, -⟩ := he
  simp only [row, lanes, Nat.reduceMul, Nat.reduceAdd] at h0 h1 h2 h3 e0 e1
  simp only [lanes] at v0 v1 v2 v3 v4 v5 v6 v7 v8 v9 v10 v11 v12 v13 v14 v15
  simp only [Rows]
  simp (disch := decide) only [row, Nat.reduceMul, Nat.reduceAdd, keyBlock_get _ l1, keyBlock_get _ l2,
    keyBlock_get _ l3, keyBlock_get _ l4, keyBlock_get _ hx, bump_get x hx, Nat.reduceEqDiff, ↓reduceIte]
  apply ex_of_eq
  · rw [execBlock_acc]
    simp only [finalInit]
    a64_run [vop, h0, h1, h2, h3, v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, e0, e1,
      h25, h27, clampW, add_W, and_W, zip1s_W, zip2s_W, zip1d_W, zip2d_W, dup4]
    apply congrArg some; exact Prod.ext rfl rfl
  · exact rfl
  · refine ⟨⟨?_, ?_, ?_, ?_⟩, ⟨?_, ?_, ?_, ?_⟩, ⟨?_, ?_, ?_, ?_⟩, ⟨?_, ?_, ?_, ?_⟩, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
    all_goals try a64_read
    all_goals try (simp only [final_init_counter, lit32, clampW, and_W]; done)
    case hp.refine_17 => exact rfl
    case hp.refine_21 => exact subFlags_flagsAdd _ _ _ (by norm_num) h4
    all_goals a64_out'

/-! ## Seal's main loop's five blocks -/

theorem not_W (a b c d : BitVec 32) : ~~~(W a b c d) = W (~~~a) (~~~b) (~~~c) (~~~d) := by
  apply BitVec.eq_of_getLsbD_eq; intro k hk
  simp only [BitVec.getLsbD_not, getLsbD_W]
  interval_cases k <;> simp

theorem sub_W (a0 a1 a2 a3 b0 b1 b2 b3 : BitVec 32) :
    VArr.s4.map2 (fun _ x y => x - y) (W a0 a1 a2 a3) (W b0 b1 b2 b3) =
      W (a0 - b0) (a1 - b1) (a2 - b2) (a3 - b3) := by
  simp only [VArr.map2, vword_W0, vword_W1, vword_W2, vword_W3]

/-- `ext vd, vn, vm, #12` of two registers: `vn`'s top lane, then `vm`'s three below. -/
theorem ext12g_W (a b c d e f g h : BitVec 32) :
    ((W e f g h ++ W a b c d) >>> 96).extractLsb' 0 128 = W d e f g := by
  lane_bits

theorem dup5 : BitVec.setWidth 32 (BitVec.setWidth 64 (5 : BitVec 16) <<< 0) = 5#32 := by decide

/-- The fifth block's counter, `v25`'s top lane plus one, as `not`, `sub`, and `ext` make it. -/
theorem counter5 (n : Nat) : BitVec.ofNat 32 (n + 3) - ~~~0 = BitVec.ofNat 32 (n + 4) := by
  rw [show (~~~0 : BitVec 32) = BitVec.ofNat 32 (2 ^ 32 - 1) by decide]
  apply BitVec.eq_of_toNat_eq
  simp only [BitVec.toNat_sub, BitVec.toNat_ofNat]
  omega

theorem add5 (n : Nat) : BitVec.ofNat 32 n + 5#32 = BitVec.ofNat 32 (n + 5) := by
  rw [← BitVec.ofNat_add]

/-- The counters in `v25`, from `n`. -/
def ctrs (n : Nat) : BitVec 128 :=
  W (BitVec.ofNat 32 n) (BitVec.ofNat 32 (n + 1)) (BitVec.ofNat 32 (n + 2)) (BitVec.ofNat 32 (n + 3))

set_option maxRecDepth 8000 in
theorem finalMain_ok (s : S) (x : List chacha20.Word) (hx : x.length = 16) (n : Nat)
    (h : Rows s .v24 .v28 .v29 .v30 x) (h25 : s.vg.v .v25 = ctrs n)
    (hv : Vert s (chacha20.innerBlock^[10] (bump x n)) (chacha20.innerBlock^[10] (bump x (n + 1)))
      (chacha20.innerBlock^[10] (bump x (n + 2))) (chacha20.innerBlock^[10] (bump x (n + 3))))
    (he : Rows s .v4 .v9 .v14 .v19 (chacha20.innerBlock^[10] (bump x (n + 4))))
    (h2 : (s.vg.gpr .x2).toNat < 2 ^ 63) :
    ∃ s', execBlock I finalMain s = some (s', []) ∧ Rows s' .v0 .v5 .v10 .v15 (keyBlock (bump x n)) ∧
      Rows s' .v1 .v6 .v11 .v16 (keyBlock (bump x (n + 1))) ∧
      Rows s' .v2 .v7 .v12 .v17 (keyBlock (bump x (n + 2))) ∧
      Rows s' .v3 .v8 .v13 .v18 (keyBlock (bump x (n + 3))) ∧
      Rows s' .v4 .v9 .v14 .v19 (keyBlock (bump x (n + 4))) ∧ s'.vg.v .v25 = ctrs (n + 5) ∧
      SubFlags s'.vg (s.vg.gpr .x2) 320 ∧ s'.vg.mem = s.vg.mem ∧
      Frame s s' [.v0, .v1, .v2, .v3, .v4, .v5, .v6, .v7, .v8, .v9, .v10, .v11, .v12, .v13, .v14, .v15, .v16,
        .v17, .v18, .v19, .v20, .v21, .v22, .v23, .v25] [.x11] := by
  have l0 : (bump x n).length = 16 := by rw [bump_length, hx]
  have l1 : (bump x (n + 1)).length = 16 := by rw [bump_length, hx]
  have l2 : (bump x (n + 2)).length = 16 := by rw [bump_length, hx]
  have l3 : (bump x (n + 3)).length = 16 := by rw [bump_length, hx]
  have l4 : (bump x (n + 4)).length = 16 := by rw [bump_length, hx]
  obtain ⟨h0, h1, h2', h3⟩ := h
  obtain ⟨v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15⟩ := hv
  obtain ⟨e0, e1, e2, e3⟩ := he
  simp only [row, Nat.reduceMul, Nat.reduceAdd] at h0 h1 h2' h3 e0 e1 e2 e3
  simp only [lanes] at v0 v1 v2 v3 v4 v5 v6 v7 v8 v9 v10 v11 v12 v13 v14 v15
  simp only [ctrs] at h25 ⊢
  simp only [Rows]
  simp (disch := decide) only [row, Nat.reduceMul, Nat.reduceAdd, keyBlock_get _ l0, keyBlock_get _ l1,
    keyBlock_get _ l2, keyBlock_get _ l3, keyBlock_get _ l4, bump_get x hx, Nat.reduceEqDiff, ↓reduceIte]
  apply ex_of_eq
  · rw [execBlock_acc]
    simp only [finalMain]
    a64_run [vop, h0, h1, h2', h3, v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, e0, e1,
      e2, e3, h25, add_W, sub_W, not_W, BitVec.xor_self, zero_W', ext12g_W, zip1s_W, zip2s_W, zip1d_W, zip2d_W,
      dup5]
    apply congrArg some; exact Prod.ext rfl rfl
  · exact rfl
  · refine ⟨⟨?_, ?_, ?_, ?_⟩, ⟨?_, ?_, ?_, ?_⟩, ⟨?_, ?_, ?_, ?_⟩, ⟨?_, ?_, ?_, ?_⟩, ⟨?_, ?_, ?_, ?_⟩, ?_, ?_,
      ?_, ?_⟩
    all_goals try a64_read
    all_goals try (simp only [final_init_counter, counter5, add5, add_zero32]; done)
    case hp.refine_22 => exact subFlags_flagsAdd _ _ _ (by norm_num) h2
    all_goals a64_out'

end rind.aarch64.chacha20poly1305asm

/-- info: 'rind.aarch64.chacha20poly1305asm.setup128_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms rind.aarch64.chacha20poly1305asm.setup128_ok

/-- info: 'rind.aarch64.chacha20poly1305asm.final128_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms rind.aarch64.chacha20poly1305asm.final128_ok

/-- info: 'rind.aarch64.chacha20poly1305asm.finalInit_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms rind.aarch64.chacha20poly1305asm.finalInit_ok

/-- info: 'rind.aarch64.chacha20poly1305asm.finalMain_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms rind.aarch64.chacha20poly1305asm.finalMain_ok
