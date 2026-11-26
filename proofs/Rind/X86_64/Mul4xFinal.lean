import Rind.X86_64.Mul4xTailAsm
import Rind.X86_64.Mul4xLoop
import Rind.X86_64.Mul4xSub

/-! # bn_mul4x_mont's final subtraction and copy

`final`, the loop of `sub`, and `subTail` leave `t - n` in `rp` and the masks; the loop of `copy` then
leaves `select`'s words there. -/

open VG VG.X86_64 Rind.X86_64.Mul4x rind.x86_64.asm

set_option linter.unusedSimpArgs false

namespace rind.x86_64.mul4x

/-! ## Memory -/

theorem readW_wa_ne {M : Mem} {b : Addr} {i j L : Nat} (v : BitVec 64) (hb : b.toNat + 8 * L ≤ 2 ^ 64)
    (hi : i < L) (hj : j < L) (hne : i ≠ j) : (M.writeW (wa b j) v).readW (wa b i) 64 = M.readW (wa b i) 64 :=
  readW_writeW_sep _ _ _ _ (by unfold Apart; simp only [wa]; constructor <;> bv_omega)

/-- A word apart from `b`'s first `L` words keeps its value. -/
theorem Agree.apart {M₀ M : Mem} {b x : Addr} {j L : Nat} (h : Agree M₀ M b j) (hj : j ≤ L)
    (hb : b.toNat + 8 * L ≤ 2 ^ 64) (hx : x.toNat + 8 ≤ 2 ^ 64)
    (sep : x.toNat + 8 ≤ b.toNat ∨ b.toNat + 8 * L ≤ x.toNat) : M.readW x 64 = M₀.readW x 64 :=
  readW_agree h fun c hc => by bv_omega

/-- A word of `b` at or past `j` keeps its value. -/
theorem Agree.self {M₀ M : Mem} {b : Addr} {j i L : Nat} (h : Agree M₀ M b j) (hji : j ≤ i) (hi : i < L)
    (hb : b.toNat + 8 * L ≤ 2 ^ 64) : M.readW (wa b i) 64 = M₀.readW (wa b i) 64 :=
  readW_agree h fun c hc => by simp only [wa]; bv_omega

theorem Out.frame {s s' : S} {k : Nat} {np tp rp : Addr} {gs : List Reg} (out : Out s k np tp rp)
    (h : Frame s s' gs) : Out s' k np tp rp :=
  ⟨out.hrp, out.sepT, out.sepN, h.wr ▸ out.rP⟩

theorem FrameX.of {s s' : S} {gs : List Reg} (h : Frame s s' gs) : FrameX s s' gs := ⟨h.gpr, h.others, h.wr, h.lo⟩

theorem FrameX.trans {s₁ s₂ s₃ : S} {gs : List Reg} (h₁ : FrameX s₁ s₂ gs) (h₂ : FrameX s₂ s₃ gs) :
    FrameX s₁ s₃ gs :=
  ⟨fun r hr => (h₂.gpr r hr).trans (h₁.gpr r hr), h₂.others.trans h₁.others, h₂.wr.trans h₁.wr, h₂.lo.trans h₁.lo⟩

theorem FrameX.mono {s s' : S} {gs gs' : List Reg} (h : FrameX s s' gs) (hg : ∀ r ∈ gs, r ∈ gs') :
    FrameX s s' gs' :=
  ⟨fun r hr => h.gpr r fun h' => hr (hg r h'), h.others, h.wr, h.lo⟩

theorem FrameX.rd {s s' : S} {gs : List Reg} (h : FrameX s s' gs) : s'.vg.rd = s.vg.rd :=
  congrArg (fun x => x.2.2.2.2.2.1) h.others

theorem Arrays.frameX {s s' : S} {k : Nat} {ap bp np n0p tp : Addr} {gs : List Reg}
    (ar : Arrays s k ap bp np n0p tp) (h : FrameX s s' gs) : Arrays s' k ap bp np n0p tp := by
  obtain ⟨hk, hap, hbp, hnp, hn0p, htp, sepA, sepB, sepN, sepN0, rA, rB, rN, rN0, LT, hLT, rT⟩ := ar
  rw [← h.rd, ← h.wr] at rA rB rN rN0
  rw [← h.wr] at rT
  exact ⟨hk, hap, hbp, hnp, hn0p, htp, sepA, sepB, sepN, sepN0, rA, rB, rN, rN0, LT, hLT, rT⟩

theorem Out.frameX {s s' : S} {k : Nat} {np tp rp : Addr} {gs : List Reg} (out : Out s k np tp rp)
    (h : FrameX s s' gs) : Out s' k np tp rp :=
  ⟨out.hrp, out.sepT, out.sepN, h.wr ▸ out.rP⟩

/-- `dec` of a count `c ≥ 1`: the count less one, and whether it is still nonzero. -/
theorem dec_ne (c : Nat) (hc : 1 ≤ c) (hc' : c < 2 ^ 64) :
    BitVec.ofNat 64 c - 1 = BitVec.ofNat 64 (c - 1) ∧ (!(BitVec.ofNat 64 c - 1 == 0)) = decide (1 < c) := by
  have e : BitVec.ofNat 64 c - 1 = BitVec.ofNat 64 (c - 1) := by
    apply BitVec.eq_of_toNat_eq; simp; omega
  refine ⟨e, ?_⟩
  rw [e]
  by_cases h : 1 < c
  · have h0 : (BitVec.ofNat 64 (c - 1) == 0) = false := by
      rw [beq_eq_false_iff_ne]; intro h'; have := congrArg BitVec.toNat h'; simp at this; omega
    rw [h0]; simp [h]
  · have h0 : (BitVec.ofNat 64 (c - 1) == 0) = true := by rw [show c - 1 = 0 by omega]; rfl
    rw [h0]; simp [h]

/-! ## The subtraction -/

/-- The subtraction's loop from word `j`: `t - n`'s words below `j` in `rp`, the next two in `rax` and
`rdx`, and `t`'s two after in `rbx` and `rbp`. -/
structure SubInv (s₀ s : S) (k : Nat) (rp : Addr) (t n : Nat → BitVec 64) (j : Nat) : Prop where
  j4 : j % 4 = 0
  frame : Frame s₀ s [.rax, .rdx, .rbx, .rbp, .r14, .r15]
  rax : s.vg.gpr .rax = diff t n j
  rdx : s.vg.gpr .rdx = diff t n (j + 1)
  rbx : s.vg.gpr .rbx = t (j + 2)
  rbp : s.vg.gpr .rbp = t (j + 3)
  cf : s.vg.cf = some (borrow t n (j + 2))
  r14 : s.vg.gpr .r14 = BitVec.ofNat 64 j
  r15 : s.vg.gpr .r15 = BitVec.ofNat 64 ((k - 4 - j) / 4)
  agree : Agree s₀.vg.mem s.vg.mem rp j
  words : ∀ i < j, s.vg.mem.readW (wa rp i) 64 = diff t n i

/-- Reads of `n` and `t` apart from `rp`. -/
theorem out_reads {M₀ M : Mem} {k j : Nat} {np tp rp : Addr} {t n : Nat → BitVec 64} {s : S}
    (ar : Arrays s k ap bp np n0p tp) (out : Out s k np tp rp) (hag : Agree M₀ M rp j) (hj : j ≤ k)
    (hN : ∀ i < k, M₀.readW (wa np i) 64 = n i) (hT : ∀ i ≤ k, M₀.readW (wa tp i) 64 = t i) :
    (∀ i < k, M.readW (wa np i) 64 = n i) ∧ (∀ i ≤ k, M.readW (wa tp i) 64 = t i) := by
  have hrp := out.hrp
  have htp := ar.htp
  have hnp := ar.hnp
  refine ⟨fun i hi => (hag.apart hj hrp ?_ ?_).trans (hN i hi), fun i hi => (hag.apart hj hrp ?_ ?_).trans (hT i hi)⟩
  · rw [wa_toNat ar.hnp hi]; omega
  · rw [wa_toNat ar.hnp hi]; rcases out.sepN with h | h <;> omega
  · rw [wa_toNat (k := k + 3) htp (by omega)]; omega
  · rw [wa_toNat (k := k + 3) htp (by omega)]; rcases out.sepT with h | h <;> omega

set_option maxHeartbeats 2000000 in
theorem sub_step (s₀ : S) (k : Nat) (ap bp np n0p tp rp : Addr) (t n : Nat → BitVec 64)
    (hk4 : k % 4 = 0) (ar : Arrays s₀ k ap bp np n0p tp) (out : Out s₀ k np tp rp)
    (hrdi : s₀.vg.gpr .rdi = rp) (hrsi : s₀.vg.gpr .rsi = tp) (hrcx : s₀.vg.gpr .rcx = np)
    (hN : ∀ i < k, s₀.vg.mem.readW (wa np i) 64 = n i) (hT : ∀ i ≤ k, s₀.vg.mem.readW (wa tp i) 64 = t i)
    (j : Nat) (s : S) (hI : SubInv s₀ s k rp t n j) (hR : j + 8 ≤ k) :
    ∃ s', Exec I (.block sub) s (subTrace np tp rp j) s' ∧
      I.eval (Rind.X86_64.Cond.vg .ne) s' = some (decide (j + 8 < k)) ∧ SubInv s₀ s' k rp t n (j + 4) := by
  have hF := hI.frame
  have hrp := out.hrp
  have hk := ar.k32
  have g : ∀ r, r ∉ [Reg.rax, .rdx, .rbx, .rbp, .r14, .r15] → s.vg.gpr r = s₀.vg.gpr r := hF.gpr
  obtain ⟨hN', hT'⟩ := out_reads ar out hI.agree (by omega) hN hT
  obtain ⟨s', hx, oax, odx, obx, obp, ocf, o14, o15, ozf, omem, oF⟩ :=
    sub_ok s j k ((k - 4 - j) / 4) ap bp np n0p tp rp _ _ _ _ _ t n hR (ar.frame hF) (out.frame hF)
      ((g .rdi (by decide)).trans hrdi) ((g .rsi (by decide)).trans hrsi) ((g .rcx (by decide)).trans hrcx)
      hI.r14 hI.r15 hI.rax hI.rdx hI.rbx hI.rbp hI.cf hN' hT'
  obtain ⟨d1, d2⟩ := dec_ne ((k - 4 - j) / 4) (by omega) (by omega)
  refine ⟨s', Exec.block hx, ?_, ?_⟩
  · simp only [Rind.X86_64.isa, Rind.X86_64.eval, VG.X86_64.eval, ozf, Option.map_some, d2]
    have := hI.j4
    congr 1; simp only [decide_eq_decide]; omega
  have hag' : Agree s.vg.mem s'.vg.mem rp (j + 4) := by
    rw [omem]
    exact (((Agree.refl _ rp j).writeW _).writeW _ |>.writeW _).writeW _
  refine ⟨by have := hI.j4; omega, hF.trans oF, oax, odx, obx, obp, ocf, o14, ?_,
    hI.agree.trans hag' (by omega), ?_⟩
  · rw [o15, d1]; congr 1; omega
  · intro i hi
    rw [omem]
    have hw := hI.words
    rcases (by omega : i < j ∨ i = j ∨ i = j + 1 ∨ i = j + 2 ∨ i = j + 3) with h | rfl | rfl | rfl | rfl
    · rw [readW_wa_ne _ hrp (by omega) (by omega) (by omega), readW_wa_ne _ hrp (by omega) (by omega) (by omega),
        readW_wa_ne _ hrp (by omega) (by omega) (by omega), readW_wa_ne _ hrp (by omega) (by omega) (by omega)]
      exact hw i h
    · rw [readW_wa_ne _ hrp (by omega) (by omega) (by omega), readW_wa_ne _ hrp (by omega) (by omega) (by omega),
        readW_wa_ne _ hrp (by omega) (by omega) (by omega), readW_writeW_self]
    · rw [readW_wa_ne _ hrp (by omega) (by omega) (by omega), readW_wa_ne _ hrp (by omega) (by omega) (by omega),
        readW_writeW_self]
    · rw [readW_wa_ne _ hrp (by omega) (by omega) (by omega), readW_writeW_self]; rfl
    · rw [readW_writeW_self]; rfl

/-- The subtraction's trace. -/
def subLoopTrace (np tp rp : Addr) (k : Nat) : List Leak := loopTrace (subTrace np tp rp) 4 0 ((k - 8) / 4)

set_option maxHeartbeats 2000000 in
/-- `final`, the loop of `sub`, and `subTail`: `t - n` in `rp`, and the masks in `xmm4` and `xmm5`. -/
theorem subPhase_ok (s : S) (k : Nat) (ap bp np n0p tp rp : Addr) (t n : Nat → BitVec 64)
    (hk8 : 8 ≤ k) (hk4 : k % 4 = 0) (ar : Arrays s k ap bp np n0p tp) (out : Out s k np tp rp)
    (hrcx : s.vg.gpr .rcx = np) (hrsp : s.vg.gpr .rsp = tp) (hr9 : s.vg.gpr .r9 = BitVec.ofNat 64 k)
    (hN : ∀ i < k, s.vg.mem.readW (wa np i) 64 = n i) (hT : ∀ i ≤ k, s.vg.mem.readW (wa tp i) 64 = t i)
    (hrp : s.vg.mem.readW (wa tp (k + 2)) 64 = rp) :
    ∃ s₁ s₂ s₃, Exec I (.block final) s (finalTrace np tp k) s₁ ∧
      Exec I (.loop (.block sub) (Rind.X86_64.Cond.vg .ne)) s₁ (subLoopTrace np tp rp k) s₂ ∧
      Exec I (.block subTail) s₂ (subTailTrace np tp rp (k - 4)) s₃ ∧
      s₃.vg.xmm .xmm0 = XBinOp.eval .pxor (s.vg.xmm .xmm0) (s.vg.xmm .xmm0) ∧
      s₃.vg.xmm .xmm4 = shufDwords ((0 : BitVec 64) ++ mask t n k) 0 ∧
      s₃.vg.xmm .xmm5 = XBinOp.eval .pxor (XBinOp.eval .pcmpeqd (s.vg.xmm .xmm5) (s.vg.xmm .xmm5))
        (shufDwords ((0 : BitVec 64) ++ mask t n k) 0) ∧
      s₃.vg.gpr .r15 = BitVec.ofNat 64 (k / 4) ∧ s₃.vg.gpr .rax = 0 ∧ s₃.vg.gpr .rdi = rp ∧
      (∀ i < k, s₃.vg.mem.readW (wa rp i) 64 = diff t n i) ∧ Agree s.vg.mem s₃.vg.mem rp k ∧
      FrameX s s₃ [.rax, .rdx, .rdi, .rsi, .rbx, .rbp, .r14, .r15] := by
  have hrp' := out.hrp
  have hk := ar.k32
  obtain ⟨s₁, hx1, p_di, p15, p_si, p14, p_ax, p_dx, p_cf, p_bx, p_bp, pmem, pF⟩ :=
    final_ok s k ap bp np n0p tp rp t n hk8 ar hrcx hrsp hr9 hN
      (by have := hN 0 (by omega); rwa [wa_zero] at this) hT (by have := hT 0 (by omega); rwa [wa_zero] at this) hrp
  have ar1 := ar.frame pF
  have out1 := out.frame pF
  rw [← pmem] at hN hT
  have hI1 : SubInv s₁ s₁ k rp t n 0 :=
    ⟨rfl, Frame.refl _ _, p_ax.trans (diff_zero t n).symm, p_dx, p_bx, p_bp, p_cf, p14, p15, Agree.refl _ _ _,
      fun i hi => absurd hi (Nat.not_lt_zero _)⟩
  obtain ⟨s₂, hx2, hI2⟩ := loop_ok (body := .block sub) (c := Rind.X86_64.Cond.vg .ne)
    (fun j s' => SubInv s₁ s' k rp t n j) (fun j => j + 8 ≤ k) (fun j => decide (j + 8 < k)) (subTrace np tp rp) 4
    (fun j s' hI hR => sub_step s₁ k ap bp np n0p tp rp t n hk4 ar1 out1 p_di p_si
      ((pF.gpr .rcx (by decide)).trans hrcx) hN hT j s' hI hR)
    ((k - 8) / 4) 0 s₁ hI1 (fun i hi => by omega) (fun i hi => by simp; omega) (by simp; omega)
  rw [show 0 + 4 * ((k - 8) / 4 + 1) = k - 4 by omega] at hI2
  have F2 := hI2.frame
  obtain ⟨hN2, hT2⟩ := out_reads ar1 out1 hI2.agree (by omega) hN hT
  obtain ⟨K, rfl⟩ : ∃ K, k = K + 4 := ⟨k - 4, by omega⟩
  simp only [Nat.add_sub_cancel] at hI2 ⊢
  obtain ⟨s₃, hx3, o0, o4, o5, o15, oax, omem, oF⟩ :=
    subTail_ok s₂ K ap bp np n0p tp rp _ _ _ _ _ t n (ar1.frame F2) (out1.frame F2)
      ((F2.gpr .rdi (by decide)).trans p_di) ((F2.gpr .rsi (by decide)).trans p_si)
      ((F2.gpr .rcx (by decide)).trans ((pF.gpr .rcx (by decide)).trans hrcx)) hI2.r14
      ((F2.gpr .r9 (by decide)).trans ((pF.gpr .r9 (by decide)).trans hr9))
      hI2.rax hI2.rdx hI2.rbx hI2.rbp hI2.cf hN2 hT2
  have hag3 : Agree s₂.vg.mem s₃.vg.mem rp (K + 4) := by
    rw [omem]
    exact (((Agree.refl _ rp K).writeW _).writeW _ |>.writeW _).writeW _
  refine ⟨s₁, s₂, s₃, Exec.block hx1, hx2, Exec.block hx3, ?_, o4, ?_, o15, oax, ?_, ?_, ?_, ?_⟩
  · rw [o0, F2.xmm, pF.xmm]
  · rw [o5, F2.xmm, pF.xmm]; rfl
  · exact (oF.gpr .rdi (by decide)).trans ((F2.gpr .rdi (by decide)).trans p_di)
  · intro i hi
    rw [omem]
    have hw := hI2.words
    rcases (by omega : i < K ∨ i = K ∨ i = K + 1 ∨ i = K + 2 ∨ i = K + 3) with h | rfl | rfl | rfl | rfl
    · rw [readW_wa_ne _ hrp' (by omega) (by omega) (by omega), readW_wa_ne _ hrp' (by omega) (by omega) (by omega),
        readW_wa_ne _ hrp' (by omega) (by omega) (by omega), readW_wa_ne _ hrp' (by omega) (by omega) (by omega)]
      exact hw i h
    · rw [readW_wa_ne _ hrp' (by omega) (by omega) (by omega), readW_wa_ne _ hrp' (by omega) (by omega) (by omega),
        readW_wa_ne _ hrp' (by omega) (by omega) (by omega), readW_writeW_self]
    · rw [readW_wa_ne _ hrp' (by omega) (by omega) (by omega), readW_wa_ne _ hrp' (by omega) (by omega) (by omega),
        readW_writeW_self]
    · rw [readW_wa_ne _ hrp' (by omega) (by omega) (by omega), readW_writeW_self]; rfl
    · rw [readW_writeW_self]; rfl
  · have h2 := hI2.agree; rw [pmem] at h2; exact h2.trans hag3 (by omega)
  · exact (FrameX.of pF).trans ((FrameX.of F2).mono (by decide) |>.trans (oF.mono (by decide)))

end rind.x86_64.mul4x
