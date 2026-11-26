import Rind.X86_64.Mul4xAsm

/-! # bn_mul4x_mont's last blocks

`final`, which starts subtracting `n` from `t`, the four words of the subtraction `sub`, and `subTail`,
which ends it and makes the masks. -/

open VG VG.X86_64 Rind.X86_64.Mul4x rind.x86_64.asm

set_option linter.unusedSimpArgs false

namespace rind.x86_64.mul4x

theorem ofNat_shr (x n : Nat) (h : x < 2 ^ 64) : BitVec.ofNat 64 x >>> n = BitVec.ofNat 64 (x / 2 ^ n) := by
  apply BitVec.eq_of_toNat_eq
  simp only [BitVec.toNat_ushiftRight, BitVec.toNat_ofNat, Nat.shiftRight_eq_div_pow]
  rw [Nat.mod_eq_of_lt h, Nat.mod_eq_of_lt (lt_of_le_of_lt (Nat.div_le_self _ _) h)]

set_option hygiene false in
/-- `mul4x_disch`, and `rp`'s region `rP`. -/
macro "tail_disch" : tactic => `(tactic| no_recover first
  | decide
  | (try simp only [rd_setReg, wr_setReg, rd_execMul, wr_execMul, rd_execImul, wr_execImul, rd_arithFlags,
        wr_arithFlags, rd_setFlags, wr_setFlags, rd_setMem, wr_setMem]) <;>
     first
      | (refine inR (List.mem_append_right _ rT) ?_; simp only; bv_omega)
      | (refine inR (List.mem_append_right _ rP) ?_; simp only; bv_omega)
      | (refine inR rT ?_; simp only; bv_omega)
      | (refine inR rP ?_; simp only; bv_omega)
      | (refine inR rN ?_; simp only; bv_omega)
      | (unfold Apart; constructor <;> bv_omega)
      | omega)

/-- `mul4x_run` with `tail_disch`. -/
syntax "tail_run " "[" Lean.Parser.Tactic.simpLemma,* "]" : tactic
macro_rules
  | `(tactic| tail_run [$xs,*]) => `(tactic|
    simp (config := { maxSteps := 4000000 }) (disch := tail_disch) only [$xs,*, execAcc_cons, execAcc_nil,
      load64_of, store64_of, Rind.X86_64.exec, Rind.X86_64.addrs, VG.X86_64.addrs, srcAddrs,
      VG.X86_64.exec, execAlu, readSrc, Option.map_some, Option.bind_some, decide_carry,
      State.ea, m, mx, ofInt_lit, Int.reduceNeg, Int.reduceMod, Int.reduceToNat, Int.reducePow, ea_pos, ea_neg, disp_pos, ea_comb,
      ofNat_add_pos, ofNat_sub_ofNat, BitVec.xor_self, BitVec.zero_add, Nat.reduceAdd, Nat.reduceSub, Nat.reduceDiv, Nat.reducePow, Nat.add_zero,
      ofNat_zero, BitVec.add_zero, add_zero', zero_add', signExtend_zero, signExtend_zero', decide_carry', readW_writeW_eq, readW_writeW_sep,
      gpr_setReg, mem_setReg, rd_setReg, wr_setReg, cf_setReg, gpr_arithFlags, mem_arithFlags, rd_arithFlags,
      wr_arithFlags, cf_arithFlags, gpr_setFlags, mem_setFlags, rd_setFlags, wr_setFlags, gpr_setMem, mem_setMem,
      rd_setMem, wr_setMem, cf_setMem, reduceCtorEq, ↓reduceIte, List.map_nil, List.map_cons, List.append_nil, List.nil_append,
      List.cons_append])

/-- `mul4x_block` with `tail_run`. -/
syntax "tail_block " "[" Lean.Parser.Tactic.simpLemma,* "]" : tactic
macro_rules
  | `(tactic| tail_block [$xs,*]) => `(tactic| (
    apply ex_of_eq
    · rw [execBlock_acc]
      tail_run [$xs,*]
      rfl
    · rfl
    · repeat' apply And.intro
      all_goals try refine Frame.mk (fun r hr => ?_) ?_ ?_ ?_ rfl
      all_goals try simp only [List.mem_cons, List.not_mem_nil, or_false, not_or] at hr
      all_goals try simp (config := { maxSteps := 4000000 }) only [gpr_setReg, mem_setReg, wr_setReg, xmm_setReg,
        others_setReg, gpr_arithFlags, mem_arithFlags, wr_arithFlags, xmm_arithFlags, others_arithFlags, gpr_setFlags,
        mem_setFlags, wr_setFlags, xmm_setFlags, others_setFlags, gpr_setMem, mem_setMem, wr_setMem, xmm_setMem,
        others_setMem, cf_arithFlags, zf_arithFlags, zf_setReg, cf_setReg, reduceCtorEq, ↓reduceIte, *]
      all_goals first
        | rfl
        | (simp only [Option.some.injEq, decide_eq_decide, BitVec.toNat_ofNat]; omega)
        | skip))

def finalTrace (np tp : Addr) (k : Nat) : List Leak :=
  [.addr (wa tp (k + 2)), .addr tp, .addr (wa tp 1), .addr np, .addr (wa tp 2), .addr (wa tp 3), .addr (wa np 1)]

set_option maxHeartbeats 4000000 in
theorem final_ok (s : S) (k : Nat) (ap bp np n0p tp rp : BitVec 64) (t n : Nat → BitVec 64)
    (hk8 : 8 ≤ k) (ar : Arrays s k ap bp np n0p tp)
    (hrcx : s.vg.gpr .rcx = np) (hrsp : s.vg.gpr .rsp = tp) (hr9 : s.vg.gpr .r9 = BitVec.ofNat 64 k)
    (hN : ∀ i < k, s.vg.mem.readW (wa np i) 64 = n i) (hN0 : s.vg.mem.readW np 64 = n 0)
    (hT : ∀ i ≤ k, s.vg.mem.readW (wa tp i) 64 = t i) (hT0 : s.vg.mem.readW tp 64 = t 0)
    (hrp : s.vg.mem.readW (wa tp (k + 2)) 64 = rp) :
    ∃ s', execBlock I final s = some (s', finalTrace np tp k) ∧
      s'.vg.gpr .rdi = rp ∧ s'.vg.gpr .r15 = BitVec.ofNat 64 ((k - 4) / 4) ∧ s'.vg.gpr .rsi = tp ∧
      s'.vg.gpr .r14 = 0 ∧ s'.vg.gpr .rax = t 0 - n 0 ∧
      s'.vg.gpr .rdx = t 1 - n 1 - (BitVec.ofBool (decide ((t 0).toNat < (n 0).toNat))).setWidth 64 ∧
      s'.vg.cf = some (decide ((t 1).toNat < (n 1).toNat + (decide ((t 0).toNat < (n 0).toNat)).toNat)) ∧
      s'.vg.gpr .rbx = t 2 ∧ s'.vg.gpr .rbp = t 3 ∧ s'.vg.mem = s.vg.mem ∧
      Frame s s' [.rax, .rdx, .rdi, .rsi, .rbx, .rbp, .r14, .r15] := by
  obtain ⟨hk, hap, hbp, hnp, hn0p, htp, sepA, sepB, sepN, sepN0, rA, rB, rN, rN0, rT⟩ := ar
  tail_block [final, hrcx, hrsp, hr9, hN, hN0, hT, hT0, hrp, ofNat_add_neg, ofNat_shr, execShift, Nat.reduceLeDiff,
    and_self]

/-- Where `rp` lies: `k` words, which the routine may write, apart from `t` and `n`. -/
structure Out (s : S) (k : Nat) (np tp rp : Addr) : Prop where
  hrp : rp.toNat + 8 * k ≤ 2 ^ 64
  sepT : rp.toNat + 8 * k ≤ tp.toNat ∨ tp.toNat + 8 * (k + 3) ≤ rp.toNat
  sepN : rp.toNat + 8 * k ≤ np.toNat ∨ np.toNat + 8 * k ≤ rp.toNat
  rP : ⟨rp, 8 * k⟩ ∈ s.vg.wr

def subTrace (np tp rp : Addr) (j : Nat) : List Leak :=
  [.addr (wa rp j), .addr (wa rp (j + 1)), .addr (wa np (j + 2)), .addr (wa tp (j + 4)), .addr (wa tp (j + 5)),
   .addr (wa np (j + 3)), .addr (wa rp (j + 2)), .addr (wa rp (j + 3)), .addr (wa np (j + 4)), .addr (wa tp (j + 6)),
   .addr (wa tp (j + 7)), .addr (wa np (j + 5))]

set_option maxHeartbeats 8000000 in
theorem sub_ok (s : S) (j k c : Nat) (ap bp np n0p tp rp x0 x1 x2 x3 : BitVec 64) (b : Bool) (t n : Nat → BitVec 64)
    (hjk : j + 8 ≤ k) (ar : Arrays s k ap bp np n0p tp) (out : Out s k np tp rp)
    (hrdi : s.vg.gpr .rdi = rp) (hrsi : s.vg.gpr .rsi = tp) (hrcx : s.vg.gpr .rcx = np)
    (hr14 : s.vg.gpr .r14 = BitVec.ofNat 64 j) (hr15 : s.vg.gpr .r15 = BitVec.ofNat 64 c)
    (hrax : s.vg.gpr .rax = x0) (hrdx : s.vg.gpr .rdx = x1) (hrbx : s.vg.gpr .rbx = x2)
    (hrbp : s.vg.gpr .rbp = x3) (hcf : s.vg.cf = some b)
    (hN : ∀ i < k, s.vg.mem.readW (wa np i) 64 = n i) (hT : ∀ i ≤ k, s.vg.mem.readW (wa tp i) 64 = t i) :
    let y2 := x2 - n (j + 2) - (BitVec.ofBool b).setWidth 64
    let b3 := decide (x2.toNat < (n (j + 2)).toNat + b.toNat)
    let y3 := x3 - n (j + 3) - (BitVec.ofBool b3).setWidth 64
    let b4 := decide (x3.toNat < (n (j + 3)).toNat + b3.toNat)
    let y4 := t (j + 4) - n (j + 4) - (BitVec.ofBool b4).setWidth 64
    let b5 := decide ((t (j + 4)).toNat < (n (j + 4)).toNat + b4.toNat)
    let y5 := t (j + 5) - n (j + 5) - (BitVec.ofBool b5).setWidth 64
    let b6 := decide ((t (j + 5)).toNat < (n (j + 5)).toNat + b5.toNat)
    ∃ s', execBlock I sub s = some (s', subTrace np tp rp j) ∧
      s'.vg.gpr .rax = y4 ∧ s'.vg.gpr .rdx = y5 ∧ s'.vg.gpr .rbx = t (j + 6) ∧ s'.vg.gpr .rbp = t (j + 7) ∧
      s'.vg.cf = some b6 ∧ s'.vg.gpr .r14 = BitVec.ofNat 64 (j + 4) ∧
      s'.vg.gpr .r15 = BitVec.ofNat 64 c - 1 ∧ s'.vg.zf = some (BitVec.ofNat 64 c - 1 == 0) ∧
      s'.vg.mem = (((s.vg.mem.writeW (wa rp j) x0).writeW (wa rp (j + 1)) x1).writeW (wa rp (j + 2)) y2).writeW
        (wa rp (j + 3)) y3 ∧
      Frame s s' [.rax, .rdx, .rbx, .rbp, .r14, .r15] := by
  obtain ⟨hk, hap, hbp, hnp, hn0p, htp, sepA, sepB, sepN, sepN0, rA, rB, rN, rN0, rT⟩ := ar
  obtain ⟨hrp, sepPT, sepPN, rP⟩ := out
  intro y2 b3 y3 b4 y4 b5 y5 b6
  tail_block [sub, hrdi, hrsi, hrcx, hr14, hr15, hrax, hrdx, hrbx, hrbp, hcf, hN, hT]

end rind.x86_64.mul4x
