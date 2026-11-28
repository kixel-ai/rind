import Rind.X86_64.GcmInitAvx2
import RindIsa.X86_64.GcmInitAvx512

open VG VG.X86_64 rind.x86_64.asm rind.vale Polynomial rind.x86_64.gcm_init_avx2

set_option linter.unusedSimpArgs false

/-!
# BoringSSL's `gcm_init_vpclmulqdq_avx512`, proven

`gcm_init_vpclmulqdq_avx512_correct`: the routine
`RindIsa/X86_64/GcmInitAvx512.lean` gives as `prog`, which `admin/prove lean`
checks is the machine code and relocations of rind's naked function
`low::x86_64::aes_gcm_vaes::gcm_init_vpclmulqdq_avx512` as rind's Linux
release build emits it, with the two statics it reads, run in rind's
extension of VG's x86_64 model from a state `Pre` holds of, terminates in one
that `Post` relates it to: for the key `H` in the two words at `rsi`, high
first, the table's sixteen blocks are H^16 down to H^1, each shifted as
Vale's `shift_key_1` does (the form `Rind/X86_64/GhashAvx512.lean`'s
`Avx512Powers` states of `VaesKernel::powers`); no other memory changes; and
the general registers but `rax` and `r8`, and those the System V ABI makes the
callee save, are as they were. Its trace is a function of its two pointers
alone (`ConstantTime`, with `Pub`), and some state meets `Pre`.

The proof runs the routine's blocks symbolically, as
`Rind/X86_64/GcmInitAvx2.lean` does, whose lane arithmetic it reuses: each
`_ghash_mul` lane, of 128, 256, or 512 bits, is `mulModel` (`lane_mul`,
`square_eq`), so the lanes hold `pz`'s powers, which `pz_spec` shows are
`gPower`'s shifted; the loop runs three times, each set the one before times
H^4 (`pz_step`); and the table is read back from the four 512-bit stores
(`table_pow`). Every theorem rests only on Lean's three axioms.
-/

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

theorem zlane_setReg (d : Reg) (v : BitVec 64) (r : XReg) (i : Nat) : (g.setReg d v).zlane r i = g.zlane r i := by
  cases g; rfl
theorem zlane_setFlags (a b c d : Option Bool) (r : XReg) (i : Nat) : (g.setFlags a b c d).zlane r i = g.zlane r i := by
  cases g; rfl

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
    @BitVec.extractLsb' 512 (128 * j) 128 (d ++ c ++ (b ++ a)) = [a, b, c, d][j]! := by
  apply BitVec.eq_of_getLsbD_eq; intro i hi
  simp only [BitVec.getLsbD_extractLsb', BitVec.getLsbD_append, hi, decide_true, Bool.true_and]
  interval_cases j <;> simp only [List.getElem!_cons_zero, List.getElem!_cons_succ] <;>
    split_ifs <;> first | omega | exact getLsbD_congr (by omega)

theorem ext512_0 (a b c d : BitVec 128) : @BitVec.extractLsb' 512 0 128 (d ++ c ++ (b ++ a)) = a := ext512 a b c d 0 (by omega)
theorem ext512_1 (a b c d : BitVec 128) : @BitVec.extractLsb' 512 128 128 (d ++ c ++ (b ++ a)) = b :=
  ext512 a b c d 1 (by omega)
theorem ext512_2 (a b c d : BitVec 128) : @BitVec.extractLsb' 512 256 128 (d ++ c ++ (b ++ a)) = c :=
  ext512 a b c d 2 (by omega)
theorem ext512_3 (a b c d : BitVec 128) : @BitVec.extractLsb' 512 384 128 (d ++ c ++ (b ++ a)) = d :=
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
      s'.vg.zlane .xmm3 0 = s.vg.lane .xmm4 0 ∧ s'.vg.zlane .xmm3 1 = s.vg.lane .xmm4 1 ∧
      s'.vg.zlane .xmm3 2 = s.vg.lane .xmm3 0 ∧ s'.vg.zlane .xmm3 3 = s.vg.lane .xmm3 1 ∧
      (∀ i < 4, s'.vg.zlane .xmm4 i = s.vg.lane .xmm4 0) ∧
      ∀ r, r ≠ .xmm3 → r ≠ .xmm4 → ∀ i, s'.vg.zlane r i = s.vg.zlane r i := by
  refine ⟨?_, ?_, ?_⟩
  pick_goal 2
  · run5
    rfl
  · refine ⟨by zkeeps, by simp only [E5Op.exec, State.setVz, zexec_mem, setZ_mem], ?_, ?_, ?_, ?_, ?_, ?_⟩
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

/-- One set of four powers: `zmm3`'s lanes times `zmm4`'s, stored 64 bytes below `r8`, and the count of sets
left one fewer. -/
theorem body_run (s : S) (g : ∀ i < 4, s.vg.zlane .xmm5 i = gfv) (h : InRegions s.vg.wr (s.vg.gpr .r8 - 64) 64) :
    ∃ s', execBlock I Rind.X86_64.GcmInitAvx512.body s = some (s', [.addr (s.vg.gpr .r8 - 64)]) ∧ Same s s' ∧
      s'.vg.gpr .r8 = s.vg.gpr .r8 - 64 ∧
      s'.vg.gpr .rax = ((s.vg.gpr .rax).setWidth 32 - 1).setWidth 64 ∧
      s'.vg.zf = some ((s.vg.gpr .rax).setWidth 32 - 1 == 0) ∧
      s'.vg.mem = s.vg.mem.writeW (s.vg.gpr .r8 - 64)
        (mulModel (s.vg.zlane .xmm3 3) (s.vg.zlane .xmm4 3) ++ mulModel (s.vg.zlane .xmm3 2) (s.vg.zlane .xmm4 2) ++
          (mulModel (s.vg.zlane .xmm3 1) (s.vg.zlane .xmm4 1) ++ mulModel (s.vg.zlane .xmm3 0) (s.vg.zlane .xmm4 0))) ∧
      (∀ i < 4, s'.vg.zlane .xmm3 i = mulModel (s.vg.zlane .xmm3 i) (s.vg.zlane .xmm4 i)) ∧
      (∀ i, s'.vg.zlane .xmm4 i = s.vg.zlane .xmm4 i) ∧ ∀ i, s'.vg.zlane .xmm5 i = s.vg.zlane .xmm5 i := by
  obtain ⟨s₁, x₁, k₁, r₁, a₁, m₁, z₁⟩ := sub_run s
  obtain ⟨s₂, x₂, k₂, m₂, l₂, o₂⟩ := mul512_run s₁ (fun i hi => (z₁ _ _).trans (g i hi))
  have hr8 : s₂.vg.gpr .r8 = s.vg.gpr .r8 - 64 := by rw [k₂.gpr, r₁]
  have hw : InRegions s₂.vg.wr (s₂.vg.gpr .r8) 64 := by rw [hr8, k₂.wr, k₁.wr]; exact h
  obtain ⟨s₃, x₃, k₃, m₃, z₃⟩ := store_run s₂ hw
  obtain ⟨s₄, x₄, k₄, r₄, f₄, e₄, m₄, z₄⟩ := dec_run s₃
  have L : ∀ i < 4, s₂.vg.zlane .xmm3 i = mulModel (s.vg.zlane .xmm3 i) (s.vg.zlane .xmm4 i) := fun i hi => by
    rw [l₂ i hi, z₁, z₁]
  refine ⟨s₄, ?_, k₁.trans ((Keeps.same (k₂.trans k₃)).trans k₄), by rw [e₄, k₃.gpr, hr8],
    by rw [r₄, k₃.gpr, k₂.gpr, a₁], by rw [f₄, k₃.gpr, k₂.gpr, a₁], ?_, fun i hi => by rw [z₄, z₃, L i hi],
    fun i => ?_, fun i => ?_⟩
  · have e := execBlock_app (execBlock_app (execBlock_app x₁ x₂) x₃) x₄
    simp only [hr8, List.append_nil, List.nil_append] at e
    rw [show Rind.X86_64.GcmInitAvx512.body = [.vg (.alu .sub .r8 (.imm 64))] ++ Rind.X86_64.GcmInitAvx512.mul512 ++
      [.vmovdqu8Store { base := .r8 } .xmm3] ++ [.dec32 .rax] by
        simp only [Rind.X86_64.GcmInitAvx512.body, List.append_assoc, List.cons_append, List.nil_append]]
    exact e
  · rw [m₄, m₃, zmm_lanes, hr8, m₂, m₁, L 0 (by omega), L 1 (by omega), L 2 (by omega), L 3 (by omega)]
  · rw [z₄, z₃, o₂ .xmm4 (by decide) (by decide) (by decide) (by decide), z₁]
  · rw [z₄, z₃, o₂ .xmm5 (by decide) (by decide) (by decide) (by decide), z₁]

/-! ## The routine -/

/-- The theorem's hypotheses, `Htable = rdi` and `H = rsi`: the routine may read the key's 16 bytes and write the
table's 256, and the return address lies outside the table. -/
structure Pre (s : S) : Prop where
  rd : ⟨s.vg.gpr .rsi, 16⟩ ∈ s.vg.rd
  wr : ⟨s.vg.gpr .rdi, 256⟩ ∈ s.vg.wr
  ret : ∀ c < 8, 256 ≤ (s.vg.gpr .rsp + BitVec.ofNat 64 c - s.vg.gpr .rdi).toNat

/-- What the routine ensures: the table's block `i` is H^(16-i), shifted, for the key `H` at `rsi`; memory past the
table is unchanged; and so are the general registers but `rax` and `r8`, which the System V ABI lets it change,
what it makes the callee keep, and the regions. -/
structure Post (s s' : S) : Prop where
  pow : ∀ i < 16, toPoly (s'.vg.mem.readW (s.vg.gpr .rdi + BitVec.ofNat 64 (16 * i)) 128) =
    shiftKey1 128 gf128ModulusLowTerms (gPower (toPoly (key s)) (16 - i))
  mem : ∀ y, 256 ≤ (y - s.vg.gpr .rdi).toNat → s'.vg.mem y = s.vg.mem y
  gpr : ∀ r, r ≠ .rax → r ≠ .r8 → s'.vg.gpr r = s.vg.gpr r
  abi : abiPreserved s.vg s'.vg
  rd : s'.vg.rd = s.vg.rd
  wr : s'.vg.wr = s.vg.wr

/-- What is public: the arguments. The key is not. -/
def Pub (s₁ s₂ : S) : Prop := s₁.vg.gpr .rdi = s₂.vg.gpr .rdi ∧ s₁.vg.gpr .rsi = s₂.vg.gpr .rsi

/-- The routine's trace: the key's address, the two statics' offsets, the table's four stores, and the loop's
branches. -/
def trace (s : S) : List Leak :=
  let t (d : Nat) : Leak := .addr (s.vg.gpr .rdi + BitVec.ofNat 64 d)
  [.addr (s.vg.gpr .rsi), .addr 0, .addr 0, t 192, t 128, .branch true, t 64, .branch true, t 0, .branch false]

theorem inR64 (g : G) (n : Nat) (hw : (⟨g.gpr .rdi, 256⟩ : Region) ∈ g.wr) (hn : n + 64 ≤ 256) :
    InRegions g.wr (g.gpr .rdi + BitVec.ofNat 64 n) 64 := by
  refine ⟨_, hw, ?_⟩
  show ((g.gpr .rdi + BitVec.ofNat 64 n) - g.gpr .rdi).toNat + 64 ≤ 256
  rw [add_sub_left, BitVec.toNat_ofNat]
  simp only [Nat.reducePow]
  omega

theorem sub64 (x : BitVec 64) (n : Nat) (h : 64 ≤ n) (h' : n < 2 ^ 63) :
    x + BitVec.ofNat 64 n - 64 = x + BitVec.ofNat 64 (n - 64) := by
  bv_omega

theorem same_wr {s s' : S} (k : Same s s') (hw : (⟨s.vg.gpr .rdi, 256⟩ : Region) ∈ s.vg.wr) :
    (⟨s'.vg.gpr .rdi, 256⟩ : Region) ∈ s'.vg.wr := by
  rw [k.gpr _ (by decide) (by decide), k.wr]; exact hw

/-- The loop's condition after a set, with `n + 1` sets left before it. -/
theorem eval_ne {s : S} {n : BitVec 64} (h : s.vg.zf = some (n.setWidth 32 - 1 == 0)) :
    I.eval (.vg .ne) s = some !(n.setWidth 32 - 1 == 0) := by
  show (s.vg.zf).map (!·) = _
  rw [h]; rfl

set_option maxHeartbeats 2000000 in
/-- The table the four stores leave: block `i` is `f (16 - i)`. -/
theorem table_pow (M : Mem) (x : Addr) (H : P) (f : Nat → BitVec 128)
    (hf : ∀ n, 1 ≤ n → toPoly (f n) = shiftKey1 128 gf128ModulusLowTerms (gPower H n)) :
    ∀ i < 16, toPoly (((((M.writeW (x + BitVec.ofNat 64 192) (f 1 ++ f 2 ++ (f 3 ++ f 4))).writeW
        (x + BitVec.ofNat 64 128) (f 5 ++ f 6 ++ (f 7 ++ f 8))).writeW
        (x + BitVec.ofNat 64 64) (f 9 ++ f 10 ++ (f 11 ++ f 12))).writeW
        (x + BitVec.ofNat 64 0) (f 13 ++ f 14 ++ (f 15 ++ f 16))).readW (x + BitVec.ofNat 64 (16 * i)) 128) =
      shiftKey1 128 gf128ModulusLowTerms (gPower H (16 - i)) := by
  intro i hi
  interval_cases i <;>
    simp (disch := omega) only [Nat.reduceMul, Nat.reduceSub, readW_far, readW_sub512, ext512_0, ext512_1, ext512_2,
      ext512_3] <;>
    exact hf _ (by norm_num)

/-- Memory past the table: what was there. -/
theorem table_other (M : Mem) (x : Addr) (a b c d : BitVec 512) (y : Addr) (hy : 256 ≤ (y - x).toNat) :
    ((((M.writeW (x + BitVec.ofNat 64 192) a).writeW (x + BitVec.ofNat 64 128) b).writeW
      (x + BitVec.ofNat 64 64) c).writeW (x + BitVec.ofNat 64 0) d) y = M y := by
  repeat rw [writeW_other _ _ _ _ (by bv_omega)]

theorem exec_trace {c : Prog I} {s s' : S} {t t' : List Leak} (h : Exec I c s t s') (e : t = t') : Exec I c s t' s' :=
  e ▸ h

set_option maxHeartbeats 4000000 in
theorem correct (s : S) (h : Pre s) : ∃ s', Exec I Rind.X86_64.GcmInitAvx512.prog s (trace s) s' ∧ Post s s' := by
  obtain ⟨hrd, hwr, hret⟩ := h
  have hrsi : InRegions (s.vg.rd ++ s.vg.wr) (s.vg.gpr .rsi) 16 :=
    ⟨_, List.mem_append_left _ hrd, by simp [Region.Contains]⟩
  -- H^1 in `xmm3`, `gfpoly` in `zmm5`, and `r8` at the last set.
  obtain ⟨s₁, x₁, k₁, r₁, a₁, m₁, e₁, g₁⟩ := head_run s hrsi
  -- H^2 in `xmm4`.
  obtain ⟨s₂, x₂, k₂, m₂, e₂, o₂⟩ := square_run s₁ ((zlane_0 _ _).symm.trans (g₁ 0 (by omega)))
  have e₂3 : s₂.vg.lane .xmm3 0 = pz (key s) 1 := by
    rw [← zlane_0, o₂ .xmm3 (by decide) (by decide) (by decide), zlane_0, e₁]; rfl
  have e₂4 : s₂.vg.lane .xmm4 0 = pz (key s) 2 := by rw [e₂, e₁]; rfl
  have g₂ : ∀ i < 4, s₂.vg.zlane .xmm5 i = gfv := fun i hi =>
    (o₂ .xmm5 (by decide) (by decide) (by decide) i).trans (g₁ i hi)
  -- `[H^2, H^1]` in `ymm3` and `[H^2, H^2]` in `ymm4`.
  obtain ⟨s₃, x₃, k₃, m₃, a₃0, a₃1, b₃0, b₃1, o₃⟩ := ins_run s₂
  have g₃ : ∀ i < 4, s₃.vg.zlane .xmm5 i = gfv := fun i hi => (o₃ .xmm5 (by decide) (by decide) i).trans (g₂ i hi)
  -- `[H^4, H^3]` in `ymm4`.
  obtain ⟨s₄, x₄, k₄, m₄, d₄0, d₄1, o₄⟩ := mul256_run s₃ ((zlane_0 _ _).symm.trans (g₃ 0 (by omega)))
    ((zlane_1 _ _).symm.trans (g₃ 1 (by omega)))
  have e₄40 : s₄.vg.lane .xmm4 0 = pz (key s) 4 := by rw [d₄0, a₃0, b₃0, e₂4]; rfl
  have e₄41 : s₄.vg.lane .xmm4 1 = pz (key s) 3 := by rw [d₄1, a₃1, b₃1, e₂3, e₂4]; rfl
  have e₄30 : s₄.vg.lane .xmm3 0 = pz (key s) 2 := by
    rw [← zlane_0, o₄ .xmm3 (by decide) (by decide) (by decide) (by decide), zlane_0, a₃0, e₂4]
  have e₄31 : s₄.vg.lane .xmm3 1 = pz (key s) 1 := by
    rw [← zlane_1, o₄ .xmm3 (by decide) (by decide) (by decide) (by decide), zlane_1, a₃1, e₂3]
  have g₄ : ∀ i < 4, s₄.vg.zlane .xmm5 i = gfv := fun i hi =>
    (o₄ .xmm5 (by decide) (by decide) (by decide) (by decide) i).trans (g₃ i hi)
  -- `[H^4, H^3, H^2, H^1]` in `zmm3`, and H^4 in each lane of `zmm4`.
  obtain ⟨s₅, x₅, k₅, m₅, z₅0, z₅1, z₅2, z₅3, z₅4, o₅⟩ := zins_run s₄
  have Z₅ : ∀ j < 4, s₅.vg.zlane .xmm3 j = pz (key s) (4 - j) := by
    intro j hj
    interval_cases j
    · rw [z₅0, e₄40]
    · rw [z₅1, e₄41]
    · rw [z₅2, e₄30]
    · rw [z₅3, e₄31]
  have F₅ : ∀ j < 4, s₅.vg.zlane .xmm4 j = p4 (key s) := fun j hj => (z₅4 j hj).trans e₄40
  have g₅ : ∀ i < 4, s₅.vg.zlane .xmm5 i = gfv := fun i hi => (o₅ .xmm5 (by decide) (by decide) i).trans (g₄ i hi)
  have K₅ : Same s s₅ := k₁.trans (Keeps.same (k₂.trans (k₃.trans (k₄.trans k₅))))
  have hr₅ : s₅.vg.gpr .r8 = s.vg.gpr .rdi + BitVec.ofNat 64 192 := by
    rw [k₅.gpr, k₄.gpr, k₃.gpr, k₂.gpr, r₁]; rfl
  have hd₅ : s₅.vg.gpr .rdi = s.vg.gpr .rdi := K₅.gpr _ (by decide) (by decide)
  -- The first set stored.
  obtain ⟨s₆, x₆, k₆, m₆, z₆⟩ := store_run s₅ (by rw [hr₅, ← hd₅]; exact inR64 _ 192 (same_wr K₅ hwr) (by norm_num))
  obtain ⟨s₇, x₇, k₇, a₇, r₇, m₇, z₇⟩ := mov_run s₆
  have K₇ : Same s s₇ := (K₅.trans (Keeps.same k₆)).trans k₇
  have hr₇ : s₇.vg.gpr .r8 = s.vg.gpr .rdi + BitVec.ofNat 64 192 := by rw [r₇, k₆.gpr, hr₅]
  -- The loop's three sets.
  have W : ∀ (t : S) (n : Nat), Same s t → 64 ≤ n → n ≤ 256 → t.vg.gpr .r8 = s.vg.gpr .rdi + BitVec.ofNat 64 n →
      InRegions t.vg.wr (t.vg.gpr .r8 - 64) 64 := fun t n k h₁ h₂ e => by
    rw [e, sub64 _ _ h₁ (by omega), ← k.gpr .rdi (by decide) (by decide)]
    exact inR64 _ _ (same_wr k hwr) (by omega)
  obtain ⟨s₈, x₈, k₈, r₈, a₈, f₈, m₈, L₈, F₈, G₈⟩ := body_run s₇ (fun i hi => (z₇ _ _).trans ((z₆ _ _).trans (g₅ i hi)))
    (W s₇ 192 K₇ (by norm_num) (by norm_num) hr₇)
  have K₈ := K₇.trans k₈
  have hr₈ : s₈.vg.gpr .r8 = s.vg.gpr .rdi + BitVec.ofNat 64 128 := by rw [r₈, hr₇, sub64 _ _ (by norm_num) (by norm_num)]
  have Z₈ : ∀ j < 4, s₈.vg.zlane .xmm3 j = pz (key s) (8 - j) := fun j hj => by
    rw [L₈ j hj, z₇, z₆, z₇, z₆, Z₅ j hj, F₅ j hj, pz_step _ _ (by omega)]
    congr 1; omega
  have F₈ : ∀ j < 4, s₈.vg.zlane .xmm4 j = p4 (key s) := fun j hj => by rw [F₈, z₇, z₆, F₅ j hj]
  have g₈ : ∀ i < 4, s₈.vg.zlane .xmm5 i = gfv := fun i hi => by rw [G₈, z₇, z₆, g₅ i hi]
  obtain ⟨s₉, x₉, k₉, r₉, a₉, f₉, m₉, L₉, F₉, G₉⟩ := body_run s₈ g₈ (W s₈ 128 K₈ (by norm_num) (by norm_num) hr₈)
  have K₉ := K₈.trans k₉
  have hr₉ : s₉.vg.gpr .r8 = s.vg.gpr .rdi + BitVec.ofNat 64 64 := by rw [r₉, hr₈, sub64 _ _ (by norm_num) (by norm_num)]
  have Z₉ : ∀ j < 4, s₉.vg.zlane .xmm3 j = pz (key s) (12 - j) := fun j hj => by
    rw [L₉ j hj, Z₈ j hj, F₈ j hj, pz_step _ _ (by omega)]
    congr 1; omega
  have F₉ : ∀ j < 4, s₉.vg.zlane .xmm4 j = p4 (key s) := fun j hj => by rw [F₉, F₈ j hj]
  have g₉ : ∀ i < 4, s₉.vg.zlane .xmm5 i = gfv := fun i hi => by rw [G₉, g₈ i hi]
  obtain ⟨s₁₀, x₁₀, k₁₀, r₁₀, a₁₀, f₁₀, m₁₀, L₁₀, -, -⟩ := body_run s₉ g₉ (W s₉ 64 K₉ (by norm_num) (by norm_num) hr₉)
  have K₁₀ := K₉.trans k₁₀
  have Z₁₀ : ∀ j < 4, mulModel (s₉.vg.zlane .xmm3 j) (s₉.vg.zlane .xmm4 j) = pz (key s) (16 - j) := fun j hj => by
    rw [Z₉ j hj, F₉ j hj, pz_step _ _ (by omega)]
    congr 1; omega
  obtain ⟨s₁₁, x₁₁, k₁₁, m₁₁⟩ := vzu_run s₁₀
  have K := K₁₀.trans (Keeps.same k₁₁)
  -- The counts of sets left, and the loop's conditions.
  have c₈ : s₈.vg.gpr .rax = 2 := by rw [a₈, a₇]; rfl
  have c₉ : s₉.vg.gpr .rax = 1 := by rw [a₉, c₈]; rfl
  have v₈ : I.eval (.vg .ne) s₈ = some true := by rw [eval_ne f₈, a₇]; rfl
  have v₉ : I.eval (.vg .ne) s₉ = some true := by rw [eval_ne f₉, c₈]; rfl
  have v₁₀ : I.eval (.vg .ne) s₁₀ = some false := by rw [eval_ne f₁₀, c₉]; rfl
  -- The table.
  have hM : s₁₁.vg.mem =
      (((s.vg.mem.writeW (s.vg.gpr .rdi + BitVec.ofNat 64 192)
          (pz (key s) 1 ++ pz (key s) 2 ++ (pz (key s) 3 ++ pz (key s) 4))).writeW
        (s.vg.gpr .rdi + BitVec.ofNat 64 128) (pz (key s) 5 ++ pz (key s) 6 ++ (pz (key s) 7 ++ pz (key s) 8))).writeW
        (s.vg.gpr .rdi + BitVec.ofNat 64 64) (pz (key s) 9 ++ pz (key s) 10 ++ (pz (key s) 11 ++ pz (key s) 12))).writeW
        (s.vg.gpr .rdi + BitVec.ofNat 64 0) (pz (key s) 13 ++ pz (key s) 14 ++ (pz (key s) 15 ++ pz (key s) 16)) := by
    rw [m₁₁, m₁₀, hr₉, m₉, hr₈, m₈, hr₇, m₇, m₆, hr₅, zmm_lanes, m₅, m₄, m₃, m₂, m₁,
      sub64 _ 64 (by norm_num) (by norm_num), sub64 _ 128 (by norm_num) (by norm_num),
      sub64 _ 192 (by norm_num) (by norm_num),
      Z₁₀ 0 (by omega), Z₁₀ 1 (by omega), Z₁₀ 2 (by omega), Z₁₀ 3 (by omega),
      Z₈ 0 (by omega), Z₈ 1 (by omega), Z₈ 2 (by omega), Z₈ 3 (by omega), F₈ 0 (by omega), F₈ 1 (by omega),
      F₈ 2 (by omega), F₈ 3 (by omega),
      z₇ .xmm3 0, z₇ .xmm3 1, z₇ .xmm3 2, z₇ .xmm3 3, z₇ .xmm4 0, z₇ .xmm4 1, z₇ .xmm4 2, z₇ .xmm4 3,
      z₆ .xmm3 0, z₆ .xmm3 1, z₆ .xmm3 2, z₆ .xmm3 3, z₆ .xmm4 0, z₆ .xmm4 1, z₆ .xmm4 2, z₆ .xmm4 3,
      Z₅ 0 (by omega), Z₅ 1 (by omega), Z₅ 2 (by omega), Z₅ 3 (by omega), F₅ 0 (by omega), F₅ 1 (by omega),
      F₅ 2 (by omega), F₅ 3 (by omega)]
    simp only [pz_step _ _ (show 1 ≤ 1 by omega), pz_step _ _ (show 1 ≤ 2 by omega), pz_step _ _ (show 1 ≤ 3 by omega),
      pz_step _ _ (show 1 ≤ 4 by omega), pz_step _ _ (show 1 ≤ 5 by omega), pz_step _ _ (show 1 ≤ 6 by omega),
      pz_step _ _ (show 1 ≤ 7 by omega), pz_step _ _ (show 1 ≤ 8 by omega), Nat.reduceSub, Nat.reduceAdd]
  have hmem : ∀ y, 256 ≤ (y - s.vg.gpr .rdi).toNat → s₁₁.vg.mem y = s.vg.mem y := fun y hy => by
    rw [hM]; exact table_other _ _ _ _ _ _ _ hy
  -- The run.
  have hx := execBlock_app (execBlock_app (execBlock_app (execBlock_app (execBlock_app (execBlock_app x₁ x₂) x₃) x₄)
    x₅) x₆) x₇
  rw [show Rind.X86_64.GcmInitAvx512.head ++ Rind.X86_64.GcmInitAvx512.square ++
      [Rind.X86_64.GcmInitAvx512.vop (.vinserti128 .xmm3 .xmm4 .xmm3 1),
        Rind.X86_64.GcmInitAvx512.vop (.vinserti128 .xmm4 .xmm4 .xmm4 1)] ++ Rind.X86_64.GcmInitAvx512.mul256 ++
      [.vg (.e5op (.vinserti64x4 (.lo .xmm3) (.lo .xmm4) (.lo .xmm3) 1)), .vshufi64x2 .xmm4 .xmm4 .xmm4 0] ++
      [.vmovdqu8Store { base := .r8 } .xmm3] ++ [.vg (.mov32 .rax (.imm 3))] =
      Rind.X86_64.GcmInitAvx512.head ++ Rind.X86_64.GcmInitAvx512.square ++ Rind.X86_64.GcmInitAvx512.powers by
    simp only [Rind.X86_64.GcmInitAvx512.powers, List.append_assoc, List.cons_append, List.nil_append]] at hx
  have E := Exec.seq (Exec.block hx) (Exec.seq (Exec.loopNext (Exec.block x₈) v₈ (Exec.loopNext (Exec.block x₉) v₉
      (Exec.loopExit (Exec.block x₁₀) v₁₀))) (Exec.block x₁₁))
  refine ⟨s₁₁, exec_trace E ?_, ?_, hmem, fun r h0 h8 => K.gpr r h0 h8, ⟨fun r hr => ?_, ?_, by rw [K.mxcsr]⟩,
    K.rd, K.wr⟩
  · simp only [trace, hr₅, hr₇, hr₈, hr₉, sub64 _ 64 (by norm_num) (by norm_num), sub64 _ 128 (by norm_num) (by norm_num),
      sub64 _ 192 (by norm_num) (by norm_num), Nat.reduceSub, List.append_nil, List.nil_append, List.cons_append,
      List.singleton_append]
  · rw [hM]
    exact table_pow _ _ _ (pz (key s)) (pz_spec _)
  · simp only [calleeSaved, List.mem_cons, List.not_mem_nil, or_false] at hr
    rcases hr with rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> exact K.gpr _ (by decide) (by decide)
  · simp only [Mem.readW]
    congr 1
    apply read_congr
    intro c hc
    exact hmem _ (le_trans (by norm_num) (hret c (by omega)))

theorem constant_time : ConstantTime I Pre Pub Rind.X86_64.GcmInitAvx512.prog := by
  intro s₁ s₂ t₁ t₂ s₁' s₂' h₁ h₂ ⟨e0, e1⟩ x₁ x₂
  obtain ⟨_, y₁, -⟩ := correct s₁ h₁
  obtain ⟨_, y₂, -⟩ := correct s₂ h₂
  rw [(exec_det x₁ y₁).1, (exec_det x₂ y₂).1]
  simp only [trace, e0, e1]

/-! ## The precondition holds of some state -/

/-- A state the precondition holds of: the table at `0x10000`, the key at `0x20000`, and the stack pointer at
`0x30000`. -/
def witness : S where
  vg := { gpr := fun r => if r = .rdi then 0x10000#64 else if r = .rsi then 0x20000#64
            else if r = .rsp then 0x30000#64 else 0,
          cf := none, zf := none, sf := none, of := none,
          mem := fun _ => 0,
          rd := [⟨0x20000#64, 16⟩],
          wr := [⟨0x10000#64, 256⟩] }
  lo := 0

theorem pre_witness : Pre witness := ⟨by decide, by decide, by decide⟩

/-- The routine writes the key's powers H^16 down to H^1 to the table, changing nothing else the System V ABI or its
caller relies on; its trace depends only on its arguments; and some state meets its precondition. -/
theorem gcm_init_vpclmulqdq_avx512_correct :
    (∀ s, Pre s → ∃ t s', Exec I Rind.X86_64.GcmInitAvx512.prog s t s' ∧ Post s s') ∧
      ConstantTime I Pre Pub Rind.X86_64.GcmInitAvx512.prog ∧ ∃ s, Pre s :=
  ⟨fun s h => let ⟨s', e, p⟩ := correct s h; ⟨_, s', e, p⟩, constant_time, _, pre_witness⟩

end rind.x86_64.gcm_init_avx512

/-- info: 'rind.x86_64.gcm_init_avx512.gcm_init_vpclmulqdq_avx512_correct' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms rind.x86_64.gcm_init_avx512.gcm_init_vpclmulqdq_avx512_correct
