import RindIsa.X86_64.Mul4x
import Rind.X86_64.Mul4xModel

/-! # Running bn_mul4x_mont's blocks

What the proofs of `bn_mul4x_mont`'s blocks and of `bn_mulx4x_mont`'s and `bn_sqrx8x_internal`'s share, apart
from the blocks themselves: word addresses, the tactics that run a block, and the arrays a block reaches. They
live apart from `Mul4xAsm`'s block lemmas so those proofs build in parallel rather than one after another. -/

open VG VG.X86_64 Rind.X86_64.Mul4x rind.x86_64.asm

set_option linter.unusedSimpArgs false

namespace rind.x86_64.mul4x

/-- The address of word `i` of the array at `p`. -/
abbrev wa (p : Addr) (i : Nat) : Addr := p + BitVec.ofNat 64 i * 8#64

set_option hygiene false in
/-- Discharges the side conditions of a block's run. -/
macro "mul4x_disch" : tactic => `(tactic| no_recover first
  | decide
  | (try simp only [rd_setReg, wr_setReg, rd_execMul, wr_execMul, rd_execImul, wr_execImul, rd_arithFlags,
        wr_arithFlags, rd_setFlags, wr_setFlags, rd_setMem, wr_setMem]) <;>
     first
      | (refine inR (List.mem_append_right _ rT) ?_; simp only; bv_omega)
      | (refine inR rT ?_; simp only; bv_omega)
      | (refine inR rA ?_; simp only; bv_omega)
      | (refine inR rN ?_; simp only; bv_omega)
      | (refine inR rB ?_; simp only; bv_omega)
      | (refine inR rN0 ?_; simp only; bv_omega)
      | (unfold Apart; constructor <;> bv_omega)
      | omega)

/-- The lemmas that run a block of this routine. -/
syntax "mul4x_run " "[" Lean.Parser.Tactic.simpLemma,* "]" : tactic
macro_rules
  | `(tactic| mul4x_run [$xs,*]) => `(tactic|
    simp (config := { maxSteps := 4000000 }) (disch := mul4x_disch) only [$xs,*, execAcc_cons, execAcc_nil,
      load64_of, store64_of, Rind.X86_64.exec, Rind.X86_64.addrs, VG.X86_64.addrs, srcAddrs,
      VG.X86_64.exec, execAlu, readSrc, Option.map_some, Option.bind_some, decide_carry,
      State.ea, m, mx, ofInt_lit, Int.reduceNeg, Int.reduceMod, Int.reduceToNat, Int.reducePow, ea_pos, ea_neg, disp_pos, ea_comb,
      ofNat_add_pos, ofNat_sub_ofNat, BitVec.xor_self, BitVec.zero_add, Nat.reduceAdd, Nat.reduceSub, Nat.reduceDiv, Nat.reducePow, Nat.add_zero,
      ofNat_zero, BitVec.add_zero, add_zero', zero_add', signExtend_zero, signExtend_zero', decide_carry', readW_writeW_eq, readW_writeW_sep,
      gpr_setReg, mem_setReg, rd_setReg, wr_setReg, cf_setReg, gpr_arithFlags, mem_arithFlags, rd_arithFlags,
      wr_arithFlags, cf_arithFlags, gpr_setFlags, mem_setFlags, rd_setFlags, wr_setFlags, gpr_setMem, mem_setMem,
      rd_setMem, wr_setMem, cf_setMem, gpr_execMul, mem_execMul, rd_execMul, wr_execMul,
      gpr_execImul, mem_execImul, rd_execImul, wr_execImul, reduceCtorEq, ↓reduceIte, List.map_nil, List.map_cons, List.append_nil, List.nil_append,
      List.cons_append])

/-- Proves a block's lemma: runs it, matches the trace, and reads the
registers, flags, and memory it leaves. -/
syntax "mul4x_block " "[" Lean.Parser.Tactic.simpLemma,* "]" : tactic
macro_rules
  | `(tactic| mul4x_block [$xs,*]) => `(tactic| (
    apply ex_of_eq
    · rw [execBlock_acc]
      mul4x_run [$xs,*]
      rfl
    · rfl
    · repeat' apply And.intro
      all_goals try refine Frame.mk (fun r hr => ?_) ?_ ?_ ?_ rfl
      all_goals try simp only [List.mem_cons, List.not_mem_nil, or_false, not_or] at hr
      all_goals try simp (config := { maxSteps := 4000000 }) only [gpr_setReg, mem_setReg, wr_setReg, xmm_setReg, others_setReg, gpr_arithFlags,
        mem_arithFlags, wr_arithFlags, xmm_arithFlags, others_arithFlags, gpr_setFlags, mem_setFlags, wr_setFlags,
        xmm_setFlags, others_setFlags, gpr_setMem, mem_setMem, wr_setMem, xmm_setMem, others_setMem, gpr_execMul,
        mem_execMul, wr_execMul, xmm_execMul, others_execMul, gpr_execImul, mem_execImul, wr_execImul, xmm_execImul,
        others_execImul, cf_arithFlags, reduceCtorEq, ↓reduceIte, *]
      all_goals first
        | rfl
        | (simp only [Option.some.injEq, decide_eq_decide, BitVec.toNat_ofNat]; omega)
        | skip))

/-- The arrays a block reaches, `k` words of `a` and `n` and `k + 3` of `t`, which the routine may read, and
write in `t`'s case; `t` overlaps neither of the others, and none wraps. -/
structure Arrays (s : S) (k : Nat) (ap bp np n0p tp : Addr) : Prop where
  k32 : k < 2 ^ 32
  hap : ap.toNat + 8 * k ≤ 2 ^ 64
  hbp : bp.toNat + 8 * k ≤ 2 ^ 64
  hnp : np.toNat + 8 * k ≤ 2 ^ 64
  hn0p : n0p.toNat + 8 ≤ 2 ^ 64
  htp : tp.toNat + 8 * (k + 3) ≤ 2 ^ 64
  sepA : ap.toNat + 8 * k ≤ tp.toNat ∨ tp.toNat + 8 * (k + 3) ≤ ap.toNat
  sepB : bp.toNat + 8 * k ≤ tp.toNat ∨ tp.toNat + 8 * (k + 3) ≤ bp.toNat
  sepN : np.toNat + 8 * k ≤ tp.toNat ∨ tp.toNat + 8 * (k + 3) ≤ np.toNat
  sepN0 : n0p.toNat + 8 ≤ tp.toNat ∨ tp.toNat + 8 * (k + 3) ≤ n0p.toNat
  rA : ⟨ap, 8 * k⟩ ∈ s.vg.rd ++ s.vg.wr
  rB : ⟨bp, 8 * k⟩ ∈ s.vg.rd ++ s.vg.wr
  rN : ⟨np, 8 * k⟩ ∈ s.vg.rd ++ s.vg.wr
  rN0 : ⟨n0p, 8⟩ ∈ s.vg.rd ++ s.vg.wr
  rT : ∃ L, 8 * (k + 3) ≤ L ∧ ⟨tp, L⟩ ∈ s.vg.wr

section
variable (s : VG.X86_64.State)
theorem load128_of {a : Addr} (h : InRegions (s.rd ++ s.wr) a 16) : s.load128 a = some (s.mem.readW a 128) := by
  simp [State.load128, h]
theorem store128_of {a : Addr} {v : BitVec 128} (h : InRegions s.wr a 16) :
    s.store128 a v = some (setMem s (s.mem.writeW a v)) := by
  simp [State.store128, h, setMem]
end

/-- `dec`'s flags, folded. -/
theorem exec_dec (d : Reg) (s : S) : Rind.X86_64.exec (.dec d) s =
    some { s with vg := (s.vg.setFlags s.vg.cf (some (subOverflow (s.vg.gpr d) 1 (s.vg.gpr d - 1)))
      (some (s.vg.gpr d - 1 == 0)) (some (s.vg.gpr d - 1).msb)).setReg d (s.vg.gpr d - 1) } := rfl

end rind.x86_64.mul4x
