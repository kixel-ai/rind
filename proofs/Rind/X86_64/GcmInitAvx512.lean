import Rind.X86_64.GcmInitAvx2
import RindIsa.X86_64.GcmInitAvx512

open VG VG.X86_64 rind.x86_64.asm rind.vale Polynomial rind.x86_64.gcm_init_avx2

set_option linter.unusedSimpArgs false

namespace rind.x86_64.gcm_init_avx512

local notation "P" => Polynomial (ZMod 2)

/-! ## The lane arithmetic -/

theorem ternlog_96 (a b c : BitVec 128) : ternlog a b c 0x96 = a ^^^ b ^^^ c := by
  apply BitVec.eq_of_getLsbD_eq; intro i hi
  rw [ternlog, show List.range 8 = [0, 1, 2, 3, 4, 5, 6, 7] from rfl]
  simp (config := { decide := true }) only [List.foldl_cons, List.foldl_nil, ite_true, ite_false,
    BitVec.getLsbD_or, BitVec.getLsbD_and, BitVec.getLsbD_xor, BitVec.getLsbD_not, BitVec.getLsbD_zero, hi,
    decide_true, Bool.true_and]
  cases a.getLsbD i <;> cases b.getLsbD i <;> cases c.getLsbD i <;> simp

theorem ternlog_78 (a b c : BitVec 128) : ternlog a b c 0x78 = a ^^^ (b &&& c) := by
  apply BitVec.eq_of_getLsbD_eq; intro i hi
  rw [ternlog, show List.range 8 = [0, 1, 2, 3, 4, 5, 6, 7] from rfl]
  simp (config := { decide := true }) only [List.foldl_cons, List.foldl_nil, ite_true, ite_false,
    BitVec.getLsbD_or, BitVec.getLsbD_and, BitVec.getLsbD_xor, BitVec.getLsbD_not, BitVec.getLsbD_zero, hi,
    decide_true, Bool.true_and]
  cases a.getLsbD i <;> cases b.getLsbD i <;> cases c.getLsbD i <;> simp

/-- H^1, the key times `x`. -/
def p1 (h : BitVec 128) : BitVec 128 := skBV h

/-- H^2, H^1 squared. -/
def p2 (h : BitVec 128) : BitVec 128 := mulModel (p1 h) (p1 h)

/-- H^4, H^2 squared. -/
def p4 (h : BitVec 128) : BitVec 128 := mulModel (p2 h) (p2 h)

/-- The routine's powers of the key `h`: H^1 and H^2; H^3 and H^4, H^1 and H^2 times H^2; and from H^5 each the one
four below times H^4. -/
def pz (h : BitVec 128) : Nat → BitVec 128
  | 0 => 0
  | 1 => p1 h
  | 2 => p2 h
  | 3 => mulModel (p1 h) (p2 h)
  | 4 => p4 h
  | n + 5 => mulModel (pz h (n + 1)) (p4 h)

theorem spec_mul {H : P} (hH : Small H) {a b : BitVec 128} {m n : Nat} (hm : 1 ≤ m) (hn : 1 ≤ n)
    (ha : toPoly a = shiftKey1 128 gf128ModulusLowTerms (gPower H m))
    (hb : toPoly b = shiftKey1 128 gf128ModulusLowTerms (gPower H n)) :
    toPoly (mulModel a b) = shiftKey1 128 gf128ModulusLowTerms (gPower H (m + n)) := by
  rw [mul_shiftKey1 _ _ (small_gPower H hH m) (small_gPower H hH n) _ _ ha hb, gPower_add _ _ hn _ hm]

theorem p1_spec (h : BitVec 128) : toPoly (p1 h) = shiftKey1 128 gf128ModulusLowTerms (gPower (toPoly h) 1) := by
  rw [p1, toPoly_skBV, gPower_one]

theorem p2_spec (h : BitVec 128) : toPoly (p2 h) = shiftKey1 128 gf128ModulusLowTerms (gPower (toPoly h) 2) :=
  spec_mul (small_toPoly h) (m := 1) (n := 1) le_rfl le_rfl (p1_spec h) (p1_spec h)

theorem p4_spec (h : BitVec 128) : toPoly (p4 h) = shiftKey1 128 gf128ModulusLowTerms (gPower (toPoly h) 4) :=
  spec_mul (small_toPoly h) (m := 2) (n := 2) (by norm_num) (by norm_num) (p2_spec h) (p2_spec h)

theorem pz_spec (h : BitVec 128) : ∀ n, 1 ≤ n →
    toPoly (pz h n) = shiftKey1 128 gf128ModulusLowTerms (gPower (toPoly h) n)
  | 0, hn => absurd hn (by omega)
  | 1, _ => p1_spec h
  | 2, _ => p2_spec h
  | 3, _ => spec_mul (small_toPoly h) (m := 1) (n := 2) le_rfl (by norm_num) (p1_spec h) (p2_spec h)
  | 4, _ => p4_spec h
  | n + 5, _ => spec_mul (small_toPoly h) (m := n + 1) (n := 4) (by omega) (by norm_num)
      (pz_spec h (n + 1) (by omega)) (p4_spec h)

theorem pz_step (h : BitVec 128) (n : Nat) (hn : 1 ≤ n) : mulModel (pz h n) (p4 h) = pz h (n + 4) := by
  obtain ⟨m, rfl⟩ : ∃ m, n = m + 1 := ⟨n - 1, by omega⟩
  rfl

/-! ## The 512-bit registers -/

section
variable (g : G)

@[simp] theorem setZ_gpr (r : XReg) (a b c d : BitVec 128) : (g.setZ r a b c d).gpr = g.gpr := by cases g; rfl
@[simp] theorem setZ_mem (r : XReg) (a b c d : BitVec 128) : (g.setZ r a b c d).mem = g.mem := by cases g; rfl
@[simp] theorem setZ_rd (r : XReg) (a b c d : BitVec 128) : (g.setZ r a b c d).rd = g.rd := by cases g; rfl
@[simp] theorem setZ_wr (r : XReg) (a b c d : BitVec 128) : (g.setZ r a b c d).wr = g.wr := by cases g; rfl
@[simp] theorem setZ_mxcsr (r : XReg) (a b c d : BitVec 128) : (g.setZ r a b c d).mxcsr = g.mxcsr := by
  cases g; rfl
@[simp] theorem setZ_ea (r : XReg) (a b c d : BitVec 128) (m : MemOp) : (g.setZ r a b c d).ea m = g.ea m := by
  cases g; rfl

@[simp] theorem zexec_gpr (o : ZOp) : (o.exec g).gpr = g.gpr := by
  cases o <;> simp only [ZOp.exec, setZ_gpr]
@[simp] theorem zexec_mem (o : ZOp) : (o.exec g).mem = g.mem := by
  cases o <;> simp only [ZOp.exec, setZ_mem]
@[simp] theorem zexec_rd (o : ZOp) : (o.exec g).rd = g.rd := by
  cases o <;> simp only [ZOp.exec, setZ_rd]
@[simp] theorem zexec_wr (o : ZOp) : (o.exec g).wr = g.wr := by
  cases o <;> simp only [ZOp.exec, setZ_wr]
@[simp] theorem zexec_mxcsr (o : ZOp) : (o.exec g).mxcsr = g.mxcsr := by
  cases o <;> simp only [ZOp.exec, setZ_mxcsr]
@[simp] theorem zexec_ea (o : ZOp) (m : MemOp) : (o.exec g).ea m = g.ea m := by
  simp only [State.ea, zexec_gpr]

theorem zlane_0 (r : XReg) : g.zlane r 0 = g.lane r 0 := rfl
theorem zlane_1 (r : XReg) : g.zlane r 1 = g.lane r 1 := rfl

@[simp] theorem zlane_setZ_0 (r : XReg) (a b c d : BitVec 128) : (g.setZ r a b c d).zlane r 0 = a := by
  simp [State.zlane, State.setZ, State.lane]
@[simp] theorem zlane_setZ_1 (r : XReg) (a b c d : BitVec 128) : (g.setZ r a b c d).zlane r 1 = b := by
  simp [State.zlane, State.setZ, State.lane]
@[simp] theorem zlane_setZ_2 (r : XReg) (a b c d : BitVec 128) : (g.setZ r a b c d).zlane r 2 = c := by
  simp only [State.zlane, State.setZ, ite_true, show ¬ (2 < 2) by omega, ite_false, Nat.sub_self, Nat.mul_zero]
  exact ext_lo128 _ _
@[simp] theorem zlane_setZ_3 (r : XReg) (a b c d : BitVec 128) : (g.setZ r a b c d).zlane r 3 = d := by
  simp only [State.zlane, State.setZ, ite_true, show ¬ (3 < 2) by omega, ite_false]
  exact ext_hi128 _ _

theorem zlane_setZ_ne {r r' : XReg} (a b c d : BitVec 128) (i : Nat) (h : r' ≠ r) :
    (g.setZ r a b c d).zlane r' i = g.zlane r' i := by
  simp [State.zlane, State.setZ, State.lane, h]

@[simp] theorem lane_setZ_0 (r : XReg) (a b c d : BitVec 128) : (g.setZ r a b c d).lane r 0 = a := by
  simp [State.setZ, State.lane]
@[simp] theorem lane_setZ_1 (r : XReg) (a b c d : BitVec 128) : (g.setZ r a b c d).lane r 1 = b := by
  simp [State.setZ, State.lane]

theorem lane_setZ_ne {r r' : XReg} (a b c d : BitVec 128) (i : Nat) (h : r' ≠ r) :
    (g.setZ r a b c d).lane r' i = g.lane r' i := by
  simp [State.setZ, State.lane, h]

theorem zlane_setV_ne (len : VLen) {r r' : XReg} (x y : BitVec 128) (i : Nat) (h : r' ≠ r) :
    (g.setV len r x y).zlane r' i = g.zlane r' i := by
  simp [State.zlane, State.setV, State.lane, h]

@[simp] theorem zlane_setV_0 (len : VLen) (r : XReg) (x y : BitVec 128) : (g.setV len r x y).zlane r 0 = x := by
  simp [State.zlane, State.setV, State.lane]
@[simp] theorem zlane_setV_256 (r : XReg) (x y : BitVec 128) : (g.setV .l256 r x y).zlane r 1 = y := by
  simp [State.zlane, State.setV, State.lane]

theorem zlane_setMem (M : Mem) (r : XReg) (i : Nat) : (setMem g M).zlane r i = g.zlane r i := by cases g; rfl
theorem zmm_setMem (M : Mem) (r : XReg) : (setMem g M).zmm r = g.zmm r := by cases g; rfl

theorem zlane_setReg (d : Reg) (v : BitVec 64) (r : XReg) (i : Nat) : (g.setReg d v).zlane r i = g.zlane r i := by
  cases g; rfl
theorem zlane_setFlags (a b c d : Option Bool) (r : XReg) (i : Nat) : (g.setFlags a b c d).zlane r i = g.zlane r i := by
  cases g; rfl

/-- A register's 512 bits are its four lanes. -/
theorem zmm_setZ (r : XReg) (a b c d : BitVec 128) : (g.setZ r a b c d).zmm r = d ++ c ++ (b ++ a) := by
  simp [State.zmm, State.ymm, State.setZ]

theorem zmm_setZ_ne {r r' : XReg} (a b c d : BitVec 128) (h : r' ≠ r) : (g.setZ r a b c d).zmm r' = g.zmm r' := by
  simp [State.zmm, State.ymm, State.setZ, h]

theorem store512_of {a : Addr} {v : BitVec 512} (h : InRegions g.wr a 64) :
    g.store512 a v = some (setMem g (g.mem.writeW a v)) := by
  simp [State.store512, h, setMem]
end

/-! ## Reading the table back -/

/-- A read inside a 512-bit write, both from `x`, reads the written bits. -/
theorem readW_sub512 (m : Mem) (x : Addr) (c d : Nat) (v : BitVec 512) (w' : Nat) (hw' : w' % 8 = 0)
    (hd : d ≤ c) (h : 8 * (c - d) + w' ≤ 512) (hc : c ≤ 512) :
    (m.writeW (x + BitVec.ofNat 64 d) v).readW (x + BitVec.ofNat 64 c) w' = v.extractLsb' (8 * (c - d)) w' := by
  apply BitVec.eq_of_getLsbD_eq; intro i hi
  simp only [Mem.readW, Mem.writeW, BitVec.getLsbD_setWidth, BitVec.getLsbD_extractLsb', hi, decide_true,
    Bool.true_and]
  rw [getLsbD_read _ _ _ _ (by omega)]
  simp only [Mem.write]
  have e : (x + BitVec.ofNat 64 c + BitVec.ofNat 64 (i / 8) - (x + BitVec.ofNat 64 d)).toNat = c - d + i / 8 := by
    have : i / 8 < 64 := by omega
    bv_omega
  rw [e, ite_eq_left (by omega)]
  simp only [BitVec.getLsbD_extractLsb', BitVec.getLsbD_setWidth]
  rw [show 8 * (c - d + i / 8) + i % 8 = 8 * (c - d) + i by omega]
  simp only [show i % 8 < 8 by omega, show 8 * (c - d) + i < 8 * (512 / 8) by omega, decide_true, Bool.true_and]

theorem getLsbD_congr {x : BitVec 128} {m n : Nat} (h : m = n) : x.getLsbD m = x.getLsbD n := h ▸ rfl

/-- Lane `j` of a register's 512 bits. -/
theorem ext512 (a b c d : BitVec 128) (j : Nat) (hj : j < 4) :
    (d ++ c ++ (b ++ a)).extractLsb' (128 * j) 128 = [a, b, c, d][j]! := by
  apply BitVec.eq_of_getLsbD_eq; intro i hi
  simp only [BitVec.getLsbD_extractLsb', BitVec.getLsbD_append, hi, decide_true, Bool.true_and]
  interval_cases j <;> simp only [List.getElem!_cons_zero, List.getElem!_cons_succ] <;>
    split_ifs <;> first | omega | exact getLsbD_congr (by omega)

theorem ext512_0 (a b c d : BitVec 128) : (d ++ c ++ (b ++ a)).extractLsb' 0 128 = a := ext512 a b c d 0 (by omega)
theorem ext512_1 (a b c d : BitVec 128) : (d ++ c ++ (b ++ a)).extractLsb' 128 128 = b :=
  ext512 a b c d 1 (by omega)
theorem ext512_2 (a b c d : BitVec 128) : (d ++ c ++ (b ++ a)).extractLsb' 256 128 = c :=
  ext512 a b c d 2 (by omega)
theorem ext512_3 (a b c d : BitVec 128) : (d ++ c ++ (b ++ a)).extractLsb' 384 128 = d :=
  ext512 a b c d 3 (by omega)

/-! ## Running the blocks -/

/-- What every block keeps: all but the vector registers, memory, the flags, and `rax` and `r8`. -/
structure Same (s s' : S) : Prop where
  lo : s'.lo = s.lo
  gpr : ∀ r, r ≠ .rax → r ≠ .r8 → s'.vg.gpr r = s.vg.gpr r
  rd : s'.vg.rd = s.vg.rd
  wr : s'.vg.wr = s.vg.wr
  mxcsr : s'.vg.mxcsr = s.vg.mxcsr

theorem Same.trans {s₁ s₂ s₃ : S} (a : Same s₁ s₂) (b : Same s₂ s₃) : Same s₁ s₃ :=
  ⟨b.lo.trans a.lo, fun r h0 h8 => (b.gpr r h0 h8).trans (a.gpr r h0 h8), b.rd.trans a.rd, b.wr.trans a.wr,
    b.mxcsr.trans a.mxcsr⟩

theorem Keeps.same {s s' : S} (k : Keeps s s') : Same s s' :=
  ⟨k.lo, fun r _ _ => by rw [k.gpr], k.rd, k.wr, k.mxcsr⟩

/-- A block of vector instructions keeps all but the vector registers. -/
macro "zkeeps" : tactic => `(tactic| exact ⟨rfl, by simp only [vexec_gpr, setV_gpr, gpr_setMem', zexec_gpr, setZ_gpr,
  E5Op.exec, State.setVz],
  by simp only [vexec_rd, setV_rd, rd_setMem', zexec_rd, setZ_rd, E5Op.exec, State.setVz],
  by simp only [vexec_wr, setV_wr, wr_setMem', zexec_wr, setZ_wr, E5Op.exec, State.setVz],
  by simp only [vexec_mxcsr, setV_mxcsr, mxcsr_setMem', zexec_mxcsr, setZ_mxcsr, E5Op.exec, State.setVz]⟩)

/-- Runs a block one instruction at a time. -/
syntax "run5" ("[" Lean.Parser.Tactic.simpLemma,* "]")? : tactic
macro_rules
  | `(tactic| run5) => `(tactic| simp only [execBlock_acc, execAcc_cons, execAcc_nil, Rind.X86_64.exec,
    Rind.X86_64.addrs, VG.X86_64.exec, VG.X86_64.addrs, Rind.X86_64.GcmInitAvx512.vop,
    Rind.X86_64.GcmInitAvx512.zop, Option.map_some, List.map_nil, List.map_cons, List.append_nil, List.nil_append,
    List.cons_append, reduceCtorEq, ↓reduceIte])
  | `(tactic| run5 [$xs,*]) => `(tactic| simp only [$xs,*, execBlock_acc, execAcc_cons, execAcc_nil,
    Rind.X86_64.exec, Rind.X86_64.addrs, VG.X86_64.exec, VG.X86_64.addrs, Rind.X86_64.GcmInitAvx512.vop,
    Rind.X86_64.GcmInitAvx512.zop, Option.map_some, List.map_nil, List.map_cons, List.append_nil, List.nil_append,
    List.cons_append, reduceCtorEq, ↓reduceIte])

theorem zbin_pxord : ZBinOp.sse .vpxord = .pxor := rfl

/-- Reads a lane of the registers a block leaves. -/
syntax "zlanes" ("[" Lean.Parser.Tactic.simpLemma,* "]")? : tactic
macro_rules
  | `(tactic| zlanes) => `(tactic| simp (disch := reg_ne) only [VOp.exec, ZOp.exec, E5Op.exec,
    VBinOp.sse, zbin_pxord, eval_pxor, eval_pand, pclmul_00, pclmul_01, pclmul_10, pclmul_11, shuf_4e, hi_gfv,
    bit_one, ite_true, xmm_lane, lane_setMem, lane_setV_0, lane_setV_256, lane_setV_128, lane_setV_ne,
    zlane_setZ_0, zlane_setZ_1, zlane_setZ_2, zlane_setZ_3, zlane_setZ_ne, lane_setZ_0, lane_setZ_1, lane_setZ_ne,
    zlane_setV_ne, zlane_setV_0, zlane_setV_256, zlane_setMem, ternlog_96, ternlog_78, State.vz, State.vy,
    State.setVz])
  | `(tactic| zlanes [$xs,*]) => `(tactic| simp (disch := reg_ne) only [$xs,*, VOp.exec, ZOp.exec, E5Op.exec,
    VBinOp.sse, zbin_pxord, eval_pxor, eval_pand, pclmul_00, pclmul_01, pclmul_10, pclmul_11, shuf_4e, hi_gfv,
    bit_one, ite_true, xmm_lane, lane_setMem, lane_setV_0, lane_setV_256, lane_setV_128, lane_setV_ne,
    zlane_setZ_0, zlane_setZ_1, zlane_setZ_2, zlane_setZ_3, zlane_setZ_ne, lane_setZ_0, lane_setZ_1, lane_setZ_ne,
    zlane_setV_ne, zlane_setV_0, zlane_setV_256, zlane_setMem, ternlog_96, ternlog_78, State.vz, State.vy,
    State.setVz])

theorem sel0 (k : Nat) : ((0 : BitVec 8).extractLsb' k 2).toNat = 0 := by simp

/-- Reads a lane of the registers `vinserti64x4` and `vshufi64x2` leave. -/
syntax "zz" ("[" Lean.Parser.Tactic.simpLemma,* "]")? : tactic
macro_rules
  | `(tactic| zz) => `(tactic| simp (disch := reg_ne) only [ZOp.exec, E5Op.exec, State.setVz, insert64x4,
    shuf4Lanes, sel0, bit_one, ite_true, State.vz, State.vy, lane256, ymm_lane, ↓reduceIte, Nat.reduceMul,
    Nat.reduceSub, Nat.reduceLT, ext_lo128, ext_hi128, zlane_0, zlane_1, zlane_setZ_2, zlane_setZ_3, zlane_setZ_ne,
    lane_setZ_0, lane_setZ_1, lane_setZ_ne])
  | `(tactic| zz [$xs,*]) => `(tactic| simp (disch := reg_ne) only [$xs,*, ZOp.exec, E5Op.exec, State.setVz,
    insert64x4, shuf4Lanes, sel0, bit_one, ite_true, State.vz, State.vy, lane256, ymm_lane, ↓reduceIte,
    Nat.reduceMul, Nat.reduceSub, Nat.reduceLT, ext_lo128, ext_hi128, zlane_0, zlane_1, zlane_setZ_2, zlane_setZ_3,
    zlane_setZ_ne, lane_setZ_0, lane_setZ_1, lane_setZ_ne])

theorem ofInt_zero : BitVec.ofInt 64 0 = 0 := rfl

theorem static_carry5 : Rind.X86_64.static128 Rind.X86_64.GcmInitAvx512.carry = some carryV := rfl
theorem static_gfpoly5 : Rind.X86_64.static128 Rind.X86_64.GcmInitAvx512.gfpoly = some gfv := rfl

/-- `lea` points `r8` at the table's last 64 bytes, and `vpshufd` from `[rsi]` loads the key into `xmm3`. -/
theorem start_run (s : S) (h : InRegions (s.vg.rd ++ s.vg.wr) (s.vg.gpr .rsi) 16) :
    ∃ s', execBlock I [.lea .r8 { base := .rdi, disp := 192 }, .vpshufdLoad .xmm3 { base := .rsi } 0x4e] s =
        some (s', [.addr (s.vg.gpr .rsi)]) ∧
      Same s s' ∧ s'.vg.gpr .r8 = s.vg.gpr .rdi + BitVec.ofInt 64 192 ∧ s'.vg.gpr .rax = s.vg.gpr .rax ∧
      s'.vg.mem = s.vg.mem ∧ s'.vg.lane .xmm3 0 = key s := by
  have hl : (s.vg.setReg .r8 (s.vg.gpr .rdi + BitVec.ofInt 64 192)).load128 (s.vg.gpr .rsi) =
      some (s.vg.mem.readW (s.vg.gpr .rsi) 128) := by
    simp [State.load128, State.setReg, h]
  refine ⟨?_, ?_, ?_⟩
  pick_goal 2
  · run5 [State.ea, gpr_setReg, ofInt_zero, add_zero, hl]
    rfl
  · refine ⟨⟨rfl, fun r h0 h8 => ?_, rfl, rfl, rfl⟩, ?_, ?_, rfl, ?_⟩
    · simp [State.setV, State.setReg, h8]
    · simp [State.setV, State.setReg, State.ea]
    · simp [State.setV, State.setReg]
    · simp [State.lane, State.setV, key]
      exact shuf_4e _

/-- The carries added by `vpternlogd`, and `gfpoly` broadcast to `zmm5`. -/
theorem mask_run (s : S) :
    ∃ s', execBlock I [.rip (.vpternlogd .xmm3 .xmm0 0x78) Rind.X86_64.GcmInitAvx512.carryName
          Rind.X86_64.GcmInitAvx512.carry,
        .rip (.vbroadcasti32x4 .xmm5) Rind.X86_64.GcmInitAvx512.gfpolyName Rind.X86_64.GcmInitAvx512.gfpoly] s =
        some (s', [.addr 0, .addr 0]) ∧
      Keeps s s' ∧ s'.vg.mem = s.vg.mem ∧
      s'.vg.lane .xmm3 0 = s.vg.lane .xmm3 0 ^^^ (s.vg.lane .xmm0 0 &&& carryV) ∧
      ∀ i < 4, s'.vg.zlane .xmm5 i = gfv := by
  refine ⟨?_, ?_, ?_⟩
  pick_goal 2
  · run5 [static_carry5, static_gfpoly5]
    rfl
  · refine ⟨by zkeeps, by simp only [setV_mem, setZ_mem], ?_, ?_⟩
    · zlanes
    · intro i hi
      interval_cases i <;> zlanes

/-- `head` points `r8` at the table's last 64 bytes and leaves H^1 in `xmm3` and `gfpoly` in the four lanes of
`zmm5`. -/
theorem head_run (s : S) (h : InRegions (s.vg.rd ++ s.vg.wr) (s.vg.gpr .rsi) 16) :
    ∃ s', execBlock I Rind.X86_64.GcmInitAvx512.head s = some (s', [.addr (s.vg.gpr .rsi), .addr 0, .addr 0]) ∧
      Same s s' ∧ s'.vg.gpr .r8 = s.vg.gpr .rdi + BitVec.ofInt 64 192 ∧ s'.vg.gpr .rax = s.vg.gpr .rax ∧
      s'.vg.mem = s.vg.mem ∧ s'.vg.lane .xmm3 0 = p1 (key s) ∧ ∀ i < 4, s'.vg.zlane .xmm5 i = gfv := by
  obtain ⟨s₁, x₁, k₁, r₁, a₁, m₁, e₁⟩ := start_run s h
  obtain ⟨s₂, x₂, k₂, m₂, a₂, b₂, -⟩ := shift_run s₁
  obtain ⟨s₃, x₃, k₃, m₃, a₃, g₃⟩ := mask_run s₂
  have k := k₂.trans k₃
  refine ⟨s₃, execBlock_app (execBlock_app x₁ x₂) x₃, k₁.trans (Keeps.same k), by rw [k.gpr, r₁], by rw [k.gpr, a₁],
    by rw [m₃, m₂, m₁], ?_, g₃⟩
  rw [a₃, a₂, b₂, e₁]
  exact head_eq _

/-- `square` leaves H^1's square in `xmm4`. -/
theorem square_run (s : S) (g0 : s.vg.lane .xmm5 0 = gfv) :
    ∃ s', execBlock I Rind.X86_64.GcmInitAvx512.square s = some (s', []) ∧ Keeps s s' ∧ s'.vg.mem = s.vg.mem ∧
      s'.vg.lane .xmm4 0 = mulModel (s.vg.lane .xmm3 0) (s.vg.lane .xmm3 0) ∧
      ∀ r, r ≠ .xmm0 → r ≠ .xmm1 → r ≠ .xmm4 → ∀ i, s'.vg.zlane r i = s.vg.zlane r i := by
  refine ⟨?_, ?_, ?_⟩
  pick_goal 2
  · simp only [Rind.X86_64.GcmInitAvx512.square]
    run5
    rfl
  · refine ⟨by zkeeps, by simp only [vexec_mem, setV_mem], ?_, ?_⟩
    · zlanes [g0]
      exact square_eq _
    · intro r h0 h1 h4 i
      zlanes [h0, h1, h4]

/-- The two `vinserti128`s pair H^2 with H^1 in `ymm3` and with itself in `ymm4`. -/
theorem ins_run (s : S) :
    ∃ s', execBlock I [Rind.X86_64.GcmInitAvx512.vop (.vinserti128 .xmm3 .xmm4 .xmm3 1),
        Rind.X86_64.GcmInitAvx512.vop (.vinserti128 .xmm4 .xmm4 .xmm4 1)] s = some (s', []) ∧
      Keeps s s' ∧ s'.vg.mem = s.vg.mem ∧
      s'.vg.lane .xmm3 0 = s.vg.lane .xmm4 0 ∧ s'.vg.lane .xmm3 1 = s.vg.lane .xmm3 0 ∧
      s'.vg.lane .xmm4 0 = s.vg.lane .xmm4 0 ∧ s'.vg.lane .xmm4 1 = s.vg.lane .xmm4 0 ∧
      ∀ r, r ≠ .xmm3 → r ≠ .xmm4 → ∀ i, s'.vg.zlane r i = s.vg.zlane r i := by
  refine ⟨?_, ?_, ?_⟩
  pick_goal 2
  · run5
    rfl
  · refine ⟨by zkeeps, by simp only [vexec_mem, setV_mem], ?_, ?_, ?_, ?_, ?_⟩
    · zlanes
    · zlanes
    · zlanes
    · zlanes
    · intro r h3 h4 i
      zlanes [h3, h4]

/-- `mul256` leaves each lane of `ymm4` the `mulModel` product of those of `ymm3` and `ymm4`. -/
theorem mul256_run (s : S) (g0 : s.vg.lane .xmm5 0 = gfv) (g1 : s.vg.lane .xmm5 1 = gfv) :
    ∃ s', execBlock I Rind.X86_64.GcmInitAvx512.mul256 s = some (s', []) ∧ Keeps s s' ∧ s'.vg.mem = s.vg.mem ∧
      s'.vg.lane .xmm4 0 = mulModel (s.vg.lane .xmm3 0) (s.vg.lane .xmm4 0) ∧
      s'.vg.lane .xmm4 1 = mulModel (s.vg.lane .xmm3 1) (s.vg.lane .xmm4 1) ∧
      ∀ r, r ≠ .xmm0 → r ≠ .xmm1 → r ≠ .xmm2 → r ≠ .xmm4 → ∀ i, s'.vg.zlane r i = s.vg.zlane r i := by
  refine ⟨?_, ?_, ?_⟩
  pick_goal 2
  · simp only [Rind.X86_64.GcmInitAvx512.mul256]
    run5
    rfl
  · refine ⟨by zkeeps, by simp only [vexec_mem, setV_mem], ?_, ?_, ?_⟩
    · zlanes [g0]
      exact lane_mul _ _
    · zlanes [g1]
      exact lane_mul _ _
    · intro r h0 h1 h2 h4 i
      zlanes [h0, h1, h2, h4]

/-- `vinserti64x4` joins `ymm4` and `ymm3` in `zmm3`, and `vshufi64x2` broadcasts `ymm4`'s low lane to `zmm4`. -/
theorem zins_run (s : S) :
    ∃ s', execBlock I [.vg (.e5op (.vinserti64x4 (.lo .xmm3) (.lo .xmm4) (.lo .xmm3) 1)),
        .vshufi64x2 .xmm4 .xmm4 .xmm4 0] s = some (s', []) ∧
      Keeps s s' ∧ s'.vg.mem = s.vg.mem ∧
      s'.vg.zmm .xmm3 = s.vg.lane .xmm3 1 ++ s.vg.lane .xmm3 0 ++ (s.vg.lane .xmm4 1 ++ s.vg.lane .xmm4 0) ∧
      s'.vg.zlane .xmm3 0 = s.vg.lane .xmm4 0 ∧ s'.vg.zlane .xmm3 1 = s.vg.lane .xmm4 1 ∧
      s'.vg.zlane .xmm3 2 = s.vg.lane .xmm3 0 ∧ s'.vg.zlane .xmm3 3 = s.vg.lane .xmm3 1 ∧
      (∀ i < 4, s'.vg.zlane .xmm4 i = s.vg.lane .xmm4 0) ∧
      ∀ r, r ≠ .xmm3 → r ≠ .xmm4 → ∀ i, s'.vg.zlane r i = s.vg.zlane r i := by
  refine ⟨?_, ?_, ?_⟩
  pick_goal 2
  · run5
    rfl
  · refine ⟨by zkeeps, by simp only [E5Op.exec, State.setVz, zexec_mem, setZ_mem], ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
    · simp (disch := reg_ne) only [ZOp.exec, E5Op.exec, State.setVz, zmm_setZ_ne, zmm_setZ, insert64x4, bit_one,
        ite_true, State.vz, State.vy, lane256, ymm_lane, State.zlane, ↓reduceIte, Nat.reduceMul, Nat.reduceSub,
        Nat.reduceLT, ext_lo128, ext_hi128]
    · zz
    · zz
    · zz
    · zz
    · intro i hi
      interval_cases i <;> zz
    · intro r h3 h4 i
      simp (disch := reg_ne) only [ZOp.exec, E5Op.exec, State.setVz, zlane_setZ_ne, h3, h4]

theorem split256 (x : BitVec 256) : x.extractLsb' 128 128 ++ x.extractLsb' 0 128 = x := by
  apply BitVec.eq_of_getLsbD_eq; intro i hi
  simp only [BitVec.getLsbD_append, BitVec.getLsbD_extractLsb']
  split_ifs with h
  · simp [h]
  · simp [show i - 128 < 128 by omega, show 128 + (i - 128) = i by omega]

/-- A register's 512 bits are its four lanes. -/
theorem zmm_lanes (g : G) (r : XReg) : g.zmm r = g.zlane r 3 ++ g.zlane r 2 ++ (g.zlane r 1 ++ g.zlane r 0) := by
  simp only [State.zmm, State.ymm, State.zlane, State.lane, ↓reduceIte, Nat.reduceLT, Nat.reduceSub, Nat.reduceMul,
    Nat.mul_zero, Nat.mul_one, split256, one_ne_zero]

/-- `vmovdqu8` stores `zmm3`'s 64 bytes at `[r8]`. -/
theorem store_run (s : S) (h : InRegions s.vg.wr (s.vg.gpr .r8) 64) :
    ∃ s', execBlock I [.vmovdqu8Store { base := .r8 } .xmm3] s = some (s', [.addr (s.vg.gpr .r8)]) ∧
      Keeps s s' ∧ s'.vg.mem = s.vg.mem.writeW (s.vg.gpr .r8) (s.vg.zmm .xmm3) ∧
      ∀ r i, s'.vg.zlane r i = s.vg.zlane r i := by
  have he : s.vg.ea { base := .r8 } = s.vg.gpr .r8 := by simp [State.ea, ofInt_zero]
  refine ⟨?_, ?_, ?_⟩
  pick_goal 2
  · run5 [he, store512_of _ h]
    rfl
  · exact ⟨⟨rfl, gpr_setMem' _ _, rd_setMem' _ _, wr_setMem' _ _, mxcsr_setMem' _ _⟩, mem_setMem' _ _,
      fun r i => zlane_setMem _ _ _ _⟩

/-- `movl $3, %eax`: three sets of powers to go. -/
theorem mov_run (s : S) :
    ∃ s', execBlock I [.vg (.mov32 .rax (.imm 3))] s = some (s', []) ∧ Same s s' ∧ s'.vg.gpr .rax = 3 ∧
      s'.vg.gpr .r8 = s.vg.gpr .r8 ∧ s'.vg.mem = s.vg.mem ∧ ∀ r i, s'.vg.zlane r i = s.vg.zlane r i := by
  refine ⟨?_, ?_, ?_⟩
  pick_goal 2
  · run5 [readSrc32]
    rfl
  · refine ⟨⟨rfl, fun r h0 _ => ?_, rfl, rfl, rfl⟩, ?_, ?_, rfl, fun r i => zlane_setReg _ _ _ _ _⟩
    · simp [State.setReg32, State.setReg, h0]
    · simp [State.setReg32, State.setReg]
    · simp [State.setReg32, State.setReg]

/-- `subq $64, %r8`: the next set's address. -/
theorem sub_run (s : S) :
    ∃ s', execBlock I [.vg (.alu .sub .r8 (.imm 64))] s = some (s', []) ∧ Same s s' ∧
      s'.vg.gpr .r8 = s.vg.gpr .r8 - 64 ∧ s'.vg.gpr .rax = s.vg.gpr .rax ∧ s'.vg.mem = s.vg.mem ∧
      ∀ r i, s'.vg.zlane r i = s.vg.zlane r i := by
  refine ⟨?_, ?_, ?_⟩
  pick_goal 2
  · run5 [execAlu, readSrc, Option.bind_some]
    rfl
  · refine ⟨⟨rfl, fun r _ h8 => ?_, rfl, rfl, rfl⟩, ?_, ?_, rfl,
      fun r i => (zlane_setReg _ _ _ _ _).trans (zlane_setFlags _ _ _ _ _ _ _)⟩
    · simp [State.setReg, arithFlags, State.setFlags, h8]
    · simp [State.setReg, arithFlags, State.setFlags]
    · simp [State.setReg, arithFlags, State.setFlags]

/-- `decl %eax`: one set fewer to go, and ZF set if none are left. -/
theorem dec_run (s : S) :
    ∃ s', execBlock I [.dec32 .rax] s = some (s', []) ∧ Same s s' ∧
      s'.vg.gpr .rax = ((s.vg.gpr .rax).setWidth 32 - 1).setWidth 64 ∧
      s'.vg.zf = some ((s.vg.gpr .rax).setWidth 32 - 1 == 0) ∧ s'.vg.gpr .r8 = s.vg.gpr .r8 ∧
      s'.vg.mem = s.vg.mem ∧ ∀ r i, s'.vg.zlane r i = s.vg.zlane r i := by
  refine ⟨?_, ?_, ?_⟩
  pick_goal 2
  · run5
    rfl
  · refine ⟨⟨rfl, fun r h0 _ => ?_, rfl, rfl, rfl⟩, ?_, ?_, ?_, rfl, fun r i => ?_⟩
    · simp [State.setReg32, State.setReg, arithFlags, State.setFlags, h0]
    · simp [State.setReg32, State.setReg, arithFlags, State.setFlags]
    · simp [State.setReg32, State.setReg, arithFlags, State.setFlags]
    · simp [State.setReg32, State.setReg, arithFlags, State.setFlags]
    · cases s; rfl

/-- `mul512` leaves each lane of `zmm3` the `mulModel` product of those of `zmm3` and `zmm4`. -/
theorem mul512_run (s : S) (g : ∀ i < 4, s.vg.zlane .xmm5 i = gfv) :
    ∃ s', execBlock I Rind.X86_64.GcmInitAvx512.mul512 s = some (s', []) ∧ Keeps s s' ∧ s'.vg.mem = s.vg.mem ∧
      (∀ i < 4, s'.vg.zlane .xmm3 i = mulModel (s.vg.zlane .xmm3 i) (s.vg.zlane .xmm4 i)) ∧
      ∀ r, r ≠ .xmm0 → r ≠ .xmm1 → r ≠ .xmm2 → r ≠ .xmm3 → ∀ i, s'.vg.zlane r i = s.vg.zlane r i := by
  refine ⟨?_, ?_, ?_⟩
  pick_goal 2
  · simp only [Rind.X86_64.GcmInitAvx512.mul512]
    run5
    rfl
  · refine ⟨by zkeeps, by simp only [zexec_mem], ?_, ?_⟩
    · intro i hi
      interval_cases i <;> zlanes [g 0 (by omega), g 1 (by omega), g 2 (by omega), g 3 (by omega)] <;>
        exact lane_mul _ _
    · intro r h0 h1 h2 h3 i
      zlanes [h0, h1, h2, h3]

/-- `vzeroupper` changes only the vector registers. -/
theorem vzu_run (s : S) :
    ∃ s', execBlock I [Rind.X86_64.GcmInitAvx512.vop .vzeroupper] s = some (s', []) ∧ Keeps s s' ∧
      s'.vg.mem = s.vg.mem := by
  refine ⟨?_, ?_, ?_, ?_⟩
  pick_goal 2
  · run5
    rfl
  · zkeeps
  · simp only [vexec_mem]

end rind.x86_64.gcm_init_avx512
