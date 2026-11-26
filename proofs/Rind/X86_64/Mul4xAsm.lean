import RindIsa.X86_64.Mul4x
import Rind.X86_64.Asm

open VG VG.X86_64 Rind.X86_64.Mul4x rind.x86_64.asm

set_option linter.unusedSimpArgs false

namespace rind.x86_64.mul4x

/-! ## The word-serial step -/

/-- A word of a pass with no `t` to add (the first): with `c = (cA, cN)`,
`a·b + cA` and `n·q + cN` plus the former's low word; the latter's low word,
and the two high words, the next word's `c`. -/
def step0 (a n b q : BitVec 64) (c : BitVec 64 × BitVec 64) : BitVec 64 × (BitVec 64 × BitVec 64) :=
  let A := mac a b c.1
  let N := acc (mac n q c.2) A.1
  (N.1, (A.2, N.2))

/-- What a block leaves unchanged: the general registers but `gs`, and the rest of the state but memory and
the flags. -/
structure Frame (s s' : S) (gs : List Reg) : Prop where
  gpr : ∀ r, r ∉ gs → s'.vg.gpr r = s.vg.gpr r
  others : others s'.vg = others s.vg
  wr : s'.vg.wr = s.vg.wr
  xmm : s'.vg.xmm = s.vg.xmm
  lo : s'.lo = s.lo

/-- The address of word `i` of the array at `p`. -/
abbrev wa (p : Addr) (i : Nat) : Addr := p + BitVec.ofNat 64 i * 8#64

def firstTrace (ap np tp : Addr) (j : Nat) : List Leak :=
  [.addr (wa np (j + 1)), .addr (wa ap (j + 2)), .addr (wa tp j),
   .addr (wa np (j + 2)), .addr (wa ap (j + 3)), .addr (wa tp (j + 1)),
   .addr (wa np (j + 3)), .addr (wa ap (j + 4)), .addr (wa tp (j + 2)),
   .addr (wa np (j + 4)), .addr (wa ap (j + 5)), .addr (wa tp (j + 3))]

set_option hygiene false in
/-- Discharges the side conditions of a block's run. -/
macro "mul4x_disch" : tactic => `(tactic| no_recover first
  | decide
  | (simp only [hrsi, hrcx, hrsp, hr15, gpr_setReg, rd_setReg, wr_setReg, gpr_execMul, rd_execMul, wr_execMul,
        gpr_arithFlags, rd_arithFlags, wr_arithFlags, gpr_setFlags, rd_setFlags, wr_setFlags, gpr_setMem, rd_setMem,
        wr_setMem, reduceCtorEq, ite_true, ite_false, ↓reduceIte]
     first
      | (refine inR (List.mem_append_right _ rT) ?_; simp only; bv_omega)
      | (refine inR rT ?_; simp only; bv_omega)
      | (refine inR rA ?_; simp only; bv_omega)
      | (refine inR rN ?_; simp only; bv_omega)
      | (unfold Apart; constructor <;> bv_omega)
      | bv_omega)
  | (unfold Apart; constructor <;> bv_omega)
  | omega)

/-- The lemmas that run a block of this routine. -/
syntax "mul4x_run " "[" Lean.Parser.Tactic.simpLemma,* "]" : tactic
macro_rules
  | `(tactic| mul4x_run [$xs,*]) => `(tactic|
    simp (disch := mul4x_disch) only [$xs,*, execAcc_cons, execAcc_nil,
      load64_of, store64_of, Rind.X86_64.exec, Rind.X86_64.addrs, VG.X86_64.addrs, srcAddrs,
      VG.X86_64.exec, execAlu, readSrc, Option.map_some, Option.bind_some, decide_carry,
      State.ea, m, mx, ofInt_lit, Int.reduceNeg, Int.reduceMod, Int.reduceToNat, Int.reducePow, ea_pos, ea_neg,
      ofNat_add_ofNat, ofNat_sub_ofNat, Nat.reduceAdd, Nat.reduceSub, Nat.reduceDiv, Nat.reducePow, Nat.add_zero,
      ofNat_zero, BitVec.add_zero, add_zero', signExtend_zero, signExtend_zero', decide_carry', readW_writeW_eq, readW_writeW_sep,
      gpr_setReg, mem_setReg, rd_setReg, wr_setReg, cf_setReg, gpr_arithFlags, mem_arithFlags, rd_arithFlags,
      wr_arithFlags, cf_arithFlags, gpr_setFlags, mem_setFlags, rd_setFlags, wr_setFlags, gpr_setMem, mem_setMem,
      rd_setMem, wr_setMem, cf_setMem, gpr_execMul, mem_execMul, rd_execMul, wr_execMul,
      reduceCtorEq, ↓reduceIte, List.map_nil, List.map_cons, List.append_nil, List.nil_append,
      List.cons_append])

set_option maxHeartbeats 1000000 in
theorem first_ok (s : S) (j k : Nat) (ap np tp b q cA cN : BitVec 64) (a n : Nat → BitVec 64)
    (hj : 1 ≤ j) (hjk : j + 7 ≤ k) (hk : k < 2 ^ 32)
    (hrsi : s.vg.gpr .rsi = ap) (hrcx : s.vg.gpr .rcx = np) (hrsp : s.vg.gpr .rsp = tp)
    (hr15 : s.vg.gpr .r15 = BitVec.ofNat 64 (j + 3)) (hrbx : s.vg.gpr .rbx = b) (hrbp : s.vg.gpr .rbp = q)
    (hr10 : s.vg.gpr .r10 = cA) (hr13 : s.vg.gpr .r13 = cN) (hrax : s.vg.gpr .rax = a (j + 1))
    (hr9 : s.vg.gpr .r9 = BitVec.ofNat 64 k)
    (hA : ∀ i < k, s.vg.mem.readW (wa ap i) 64 = a i) (hN : ∀ i < k, s.vg.mem.readW (wa np i) 64 = n i)
    (hap : ap.toNat + 8 * k ≤ 2 ^ 64) (hnp : np.toNat + 8 * k ≤ 2 ^ 64) (htp : tp.toNat + 8 * (k + 3) ≤ 2 ^ 64)
    (sepA : ap.toNat + 8 * k ≤ tp.toNat ∨ tp.toNat + 8 * (k + 3) ≤ ap.toNat)
    (sepN : np.toNat + 8 * k ≤ tp.toNat ∨ tp.toNat + 8 * (k + 3) ≤ np.toNat)
    (rA : ⟨ap, 8 * k⟩ ∈ s.vg.rd ++ s.vg.wr) (rN : ⟨np, 8 * k⟩ ∈ s.vg.rd ++ s.vg.wr)
    (rT : ⟨tp, 8 * (k + 3)⟩ ∈ s.vg.wr) :
    let w0 := step0 (a (j + 1)) (n (j + 1)) b q (cA, cN)
    let w1 := step0 (a (j + 2)) (n (j + 2)) b q w0.2
    let w2 := step0 (a (j + 3)) (n (j + 3)) b q w1.2
    let w3 := step0 (a (j + 4)) (n (j + 4)) b q w2.2
    ∃ s', execBlock I first s = some (s', firstTrace ap np tp j) ∧
      s'.vg.gpr .r10 = w3.2.1 ∧ s'.vg.gpr .r13 = w3.2.2 ∧ s'.vg.gpr .rax = a (j + 5) ∧
      s'.vg.gpr .r15 = BitVec.ofNat 64 (j + 7) ∧ s'.vg.cf = some (decide (j + 7 < k)) ∧
      s'.vg.mem = (((s.vg.mem.writeW (wa tp j) w0.1).writeW (wa tp (j + 1)) w1.1).writeW (wa tp (j + 2)) w2.1).writeW
        (wa tp (j + 3)) w3.1 ∧
      Frame s s' [.rax, .rdx, .rdi, .r10, .r11, .r13, .r15] := by
  intro w0 w1 w2 w3
  apply ex_of_eq
  · rw [execBlock_acc]
    mul4x_run [first, hrsi, hrcx, hrsp, hr15, hrbx, hrbp, hr10, hr13, hrax, hr9, hA, hN]
    rfl
  · rfl
  · refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ⟨fun r hr => ?_, ?_, ?_, ?_, rfl⟩⟩
    all_goals try simp only [List.mem_cons, List.not_mem_nil, or_false, not_or] at hr
    all_goals try obtain ⟨h1, h2, h3, h4, h5, h6, h7⟩ := hr
    all_goals simp only [gpr_setReg, mem_setReg, wr_setReg, xmm_setReg, others_setReg, gpr_arithFlags,
      mem_arithFlags, wr_arithFlags, xmm_arithFlags, others_arithFlags, gpr_setFlags, mem_setFlags, wr_setFlags,
      xmm_setFlags, others_setFlags, gpr_setMem, mem_setMem, wr_setMem, xmm_setMem, others_setMem, gpr_execMul,
      mem_execMul, wr_execMul, xmm_execMul, others_execMul, cf_arithFlags, reduceCtorEq, ↓reduceIte, *]
    all_goals first
      | rfl
      | (simp only [Option.some.injEq, decide_eq_decide, BitVec.toNat_ofNat]; omega)

end rind.x86_64.mul4x
