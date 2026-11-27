import Rind.X86_64.Sqrx8xMontTail
import Rind.X86_64.Mulx4xFinal

/-! # bn_sqrx8x_mont's subtraction and selection

The loop of `sub`, which subtracts `n` from `t`'s upper half into `rp`, and the loop of `copy`, which selects
`t`'s upper half or the difference by the mask `subTail` makes, zeroing `t`. -/

open VG VG.X86_64 rind.x86_64.asm rind.x86_64.mul4x rind.x86_64.mulx4x

set_option linter.unusedSimpArgs false

namespace rind.x86_64.sqrx8xmont

/-- A word of `p` apart from `rp`'s first `j ≤ k` words keeps its value. -/
theorem apartW {M₀ M : Mem} {rp p : Addr} {j k L i : Nat} (h : Agree M₀ M rp j) (hj : j ≤ k)
    (hrp : rp.toNat + 8 * k ≤ 2 ^ 64) (hp : p.toNat + 8 * L ≤ 2 ^ 64)
    (sep : p.toNat + 8 * L ≤ rp.toNat ∨ rp.toNat + 8 * k ≤ p.toNat) (hi : i < L) :
    M.readW (wa p i) 64 = M₀.readW (wa p i) 64 :=
  h.apart hj hrp (by rw [wa_toNat hp hi]; omega) (by rw [wa_toNat hp hi]; omega)

/-! ## The subtraction -/

/-- The subtraction's loop from word `j`: `t - n`'s words below `j` in `rp`, the borrow into word `j`, and the
counter `-(k - j) / 4`. -/
structure SubInv (s₁ s : S) (k : Nat) (np rp wsp : Addr) (t n : Nat → BitVec 64) (j : Nat) : Prop where
  j4 : j % 4 = 0
  frame : Frame s₁ s [.rbx, .rbp, .rdi, .rcx, .r12, .r13, .r14, .r15]
  rbx : s.vg.gpr .rbx = wa wsp (k + 6 + j)
  rbp : s.vg.gpr .rbp = wa np j
  rdi : s.vg.gpr .rdi = wa rp j
  rcx : s.vg.gpr .rcx = BitVec.ofNat 64 (2 ^ 64 - (k - j) / 4)
  cf : s.vg.cf = some (borrow t n j)
  agree : Agree s₁.vg.mem s.vg.mem rp j
  words : ∀ i < j, s.vg.mem.readW (wa rp i) 64 = diff t n i

theorem inc_ne (c : Nat) (hc : 1 ≤ c) (hc' : c < 2 ^ 64) :
    BitVec.ofNat 64 (2 ^ 64 - c) + 1 = BitVec.ofNat 64 (2 ^ 64 - (c - 1)) ∧
      (!(BitVec.ofNat 64 (2 ^ 64 - c) + 1 == 0)) = decide (1 < c) := by
  have e : BitVec.ofNat 64 (2 ^ 64 - c) + 1 = BitVec.ofNat 64 (2 ^ 64 - (c - 1)) := by
    apply BitVec.eq_of_toNat_eq; simp only [BitVec.toNat_add, BitVec.toNat_ofNat]
    rw [show (1 : BitVec 64).toNat = 1 from rfl]; omega
  refine ⟨e, ?_⟩
  rw [e]
  by_cases h : 1 < c
  · have h0 : (BitVec.ofNat 64 (2 ^ 64 - (c - 1)) == 0) = false := by
      rw [beq_eq_false_iff_ne]; intro h'; have := congrArg BitVec.toNat h'; simp at this; omega
    rw [h0]; simp [h]
  · have h0 : (BitVec.ofNat 64 (2 ^ 64 - (c - 1)) == 0) = true := by
      rw [show c - 1 = 0 by omega]; rfl
    rw [h0]; simp [h]

set_option maxHeartbeats 4000000 in
theorem sub_step (s₁ : S) (k : Nat) (np rp wsp : Addr) (t n : Nat → BitVec 64)
    (hk8 : k % 8 = 0) (ar : TArr s₁ k np rp wsp)
    (hN : ∀ i < k, s₁.vg.mem.readW (wa np i) 64 = n i)
    (hT : ∀ i < k, s₁.vg.mem.readW (wa wsp (k + 6 + i)) 64 = t i)
    (j : Nat) (s : S) (hI : SubInv s₁ s k np rp wsp t n j) (hR : j + 4 ≤ k) :
    ∃ s', Exec I (.block Rind.X86_64.Sqrx8xMont.sub) s (subTrace np rp wsp (k + 6 + j) j) s' ∧
      I.eval (Rind.X86_64.Cond.vg .ne) s' = some (decide (j + 4 < k)) ∧ SubInv s₁ s' k np rp wsp t n (j + 4) := by
  have hF := hI.frame
  have hrp := ar.hrp
  have hw := ar.hw
  have hnp := ar.hnp
  have hk := ar.k29
  have j4 := hI.j4
  have sepP := ar.sepP
  have sepN := ar.sepPN
  obtain ⟨d1, d2⟩ := inc_ne ((k - j) / 4) (by omega) (by omega)
  have e1 : decide (1 < (k - j) / 4) = decide (j + 4 < k) := by simp only [decide_eq_decide]; omega
  have e2 : (k - j) / 4 - 1 = (k - (j + 4)) / 4 := by omega
  obtain ⟨s', hx, obx, obp, odi, ocf, ocx, ozf, omem, oF⟩ :=
    sub_ok s j k (k + 6 + j) np rp wsp _ (borrow t n j) (fun i => t (i - (k + 6))) n hR (by omega) (by omega)
      (ar.frame hF) hI.rbx hI.rbp hI.rdi hI.rcx hI.cf
      (fun i hi => (apartW hI.agree (by omega) hrp hnp (by rcases sepN with h | h <;> omega) hi).trans (hN i hi))
      (fun i h1 h2 => by
        rw [apartW hI.agree (L := 2 * k + 8) (by omega) hrp hw (by rcases sepP with h | h <;> omega) (by omega)]
        have := hT (i - (k + 6)) (by omega); rwa [show k + 6 + (i - (k + 6)) = i by omega] at this)
  simp only [show k + 6 + j - (k + 6) = j by omega, show k + 6 + j + 1 - (k + 6) = j + 1 by omega,
    show k + 6 + j + 2 - (k + 6) = j + 2 by omega, show k + 6 + j + 3 - (k + 6) = j + 3 by omega] at ocf omem
  refine ⟨s', Exec.block hx, by rw [eval_ne ozf, d2, e1], ?_⟩
  have hag' : Agree s.vg.mem s'.vg.mem rp (j + 4) := by
    rw [omem]; exact (((Agree.refl _ rp j).writeW _).writeW _ |>.writeW _).writeW _
  refine ⟨by omega, hF.trans oF, by rw [obx]; congr 1, obp, odi, by rw [ocx, d1, e2], ocf,
    hI.agree.trans hag' (by omega), ?_⟩
  intro i hi
  rw [omem]
  have hw' := hI.words
  rcases (by omega : i < j ∨ i = j ∨ i = j + 1 ∨ i = j + 2 ∨ i = j + 3) with h | rfl | rfl | rfl | rfl
  · rw [readW_wa_ne _ hrp (by omega) (by omega) (by omega), readW_wa_ne _ hrp (by omega) (by omega) (by omega),
      readW_wa_ne _ hrp (by omega) (by omega) (by omega), readW_wa_ne _ hrp (by omega) (by omega) (by omega)]
    exact hw' i h
  · rw [readW_wa_ne _ hrp (by omega) (by omega) (by omega), readW_wa_ne _ hrp (by omega) (by omega) (by omega),
      readW_wa_ne _ hrp (by omega) (by omega) (by omega), readW_writeW_self]; rfl
  · rw [readW_wa_ne _ hrp (by omega) (by omega) (by omega), readW_wa_ne _ hrp (by omega) (by omega) (by omega),
      readW_writeW_self]; rfl
  · rw [readW_wa_ne _ hrp (by omega) (by omega) (by omega), readW_writeW_self]; rfl
  · rw [readW_writeW_self]; rfl

/-- The subtraction's trace. -/
def subLoopTrace (np rp wsp : Addr) (k : Nat) : List Leak :=
  loopTrace (fun j => subTrace np rp wsp (k + 6 + j) j) 4 0 (k / 4 - 1)

/-! ## The selection -/

theorem add32_ne (m : Nat) (h : 4 ≤ m) (h' : 8 * m < 2 ^ 64) :
    BitVec.ofNat 64 (2 ^ 64 - 8 * m) + 32#64 = BitVec.ofNat 64 (2 ^ 64 - 8 * (m - 4)) ∧
      (!(BitVec.ofNat 64 (2 ^ 64 - 8 * m) + 32#64 == 0)) = decide (4 < m) := by
  have e : BitVec.ofNat 64 (2 ^ 64 - 8 * m) + 32#64 = BitVec.ofNat 64 (2 ^ 64 - 8 * (m - 4)) := by
    apply BitVec.eq_of_toNat_eq; simp only [BitVec.toNat_add, BitVec.toNat_ofNat]; omega
  refine ⟨e, ?_⟩
  rw [e]
  by_cases h4 : 4 < m
  · have h0 : (BitVec.ofNat 64 (2 ^ 64 - 8 * (m - 4)) == 0) = false := by
      rw [beq_eq_false_iff_ne]; intro h''; have := congrArg BitVec.toNat h''; simp at this; omega
    rw [h0]; simp [h4]
  · have h0 : (BitVec.ofNat 64 (2 ^ 64 - 8 * (m - 4)) == 0) = true := by rw [show m - 4 = 0 by omega]; rfl
    rw [h0]; simp [h4]

theorem dist (y a : Addr) : (y - a).toNat = (2 ^ 64 - a.toNat + y.toNat) % 2 ^ 64 := by
  rw [BitVec.toNat_sub]

theorem al16_wa (wsp : Addr) (k i : Nat) (hw : wsp.toNat + 8 * (2 * k + 8) ≤ 2 ^ 64) (al : wsp.toNat % 16 = 0)
    (hi : i < 2 * k + 8) (he : i % 2 = 0) : Al16 (wa wsp i) := by
  unfold Al16; rw [wa_toNat hw hi]; omega

/-- The copy's loop from word `j`: `w`'s words below `j` in `rp`, and memory but `rp`'s and `t`'s halves' words
below `j` as it was. -/
structure CopyInv (s₀ s : S) (k : Nat) (rp wsp : Addr) (w : Nat → BitVec 64) (j : Nat) : Prop where
  j4 : j % 4 = 0
  frame : FrameX s₀ s [.rbx, .rdi, .r9]
  x0 : s.vg.xmm .xmm0 = 0
  x1 : s.vg.xmm .xmm1 = s₀.vg.xmm .xmm1
  rbx : s.vg.gpr .rbx = wa wsp (k + 6 + j)
  rdi : s.vg.gpr .rdi = wa rp j
  r9 : s.vg.gpr .r9 = BitVec.ofNat 64 (2 ^ 64 - 8 * (k - j))
  agree : ∀ y, 8 * j ≤ (y - wa wsp 6).toNat → 8 * j ≤ (y - wa wsp (k + 6)).toNat → 8 * j ≤ (y - rp).toNat →
    s.vg.mem y = s₀.vg.mem y
  words : ∀ i < j, s.vg.mem.readW (wa rp i) 64 = w i

set_option maxHeartbeats 8000000 in
theorem copy_step (s₀ : S) (k : Nat) (np rp wsp : Addr) (t n : Nat → BitVec 64)
    (hk8 : k % 8 = 0) (ar : TArr s₀ k np rp wsp) (al : wsp.toNat % 16 = 0)
    (hmask : mask t n k = 0 ∨ mask t n k = -1)
    (h1 : s₀.vg.xmm .xmm1 = shufDwords ((0 : BitVec 64) ++ mask t n k) 0)
    (hT : ∀ i < k, s₀.vg.mem.readW (wa wsp (k + 6 + i)) 64 = t i)
    (hD : ∀ i < k, s₀.vg.mem.readW (wa rp i) 64 = diff t n i)
    (hdx : s₀.vg.gpr .rdx = BitVec.ofNat 64 (2 ^ 64 - 8 * k))
    (j : Nat) (s : S) (hI : CopyInv s₀ s k rp wsp (select t n k) j) (hR : j + 4 ≤ k) :
    ∃ s', Exec I (.block Rind.X86_64.Sqrx8xMont.copy) s (copyTrace rp wsp (k + 6 + j) k j) s' ∧
      I.eval (Rind.X86_64.Cond.vg .ne) s' = some (decide (j + 4 < k)) ∧
      CopyInv s₀ s' k rp wsp (select t n k) (j + 4) := by
  have hF := hI.frame
  have hrp := ar.hrp
  have hw := ar.hw
  have hk := ar.k29
  have sepP := ar.sepP
  have j4 := hI.j4
  obtain ⟨s', hx, o0, o1, obx, odi, o9, ozf, omem, oF⟩ :=
    copy_ok s j k (k + 6 + j) np rp wsp _ hR (by omega) (by omega) (ar.frameX hF)
      (al16_wa wsp k _ hw al (by omega) (by omega)) (al16_wa wsp k _ hw al (by omega) (by omega))
      (al16_wa wsp k _ hw al (by omega) (by omega)) (al16_wa wsp k _ hw al (by omega) (by omega))
      hI.rbx hI.rdi (by rw [hF.gpr .rdx (by decide), hdx]) hI.r9
  obtain ⟨e1, e2⟩ := add32_ne (k - j) (by omega) (by omega)
  refine ⟨s', Exec.block hx, ?_, ?_⟩
  · rw [eval_ne ozf, e2]; congr 1; simp only [decide_eq_decide]; omega
  have W6 : (wa wsp 6).toNat = wsp.toNat + 48 := wa_toNat hw (by omega)
  have Wk : (wa wsp (k + 6)).toNat = wsp.toNat + 8 * (k + 6) := wa_toNat hw (by omega)
  have hrp' := rp.isLt
  have hwsp := wsp.isLt
  -- Words of `t` and `rp` from `j` on read as they were.
  have rdT : ∀ i, j ≤ i → i < k → s.vg.mem.readW (wa wsp (k + 6 + i)) 64 = t i := fun i h1 h2 => by
    rw [← hT i h2]; simp only [Mem.readW]; congr 1; apply read_congr; intro c hc
    apply hI.agree <;>
      (rw [sub_wa_add hw (by omega) (by omega)]; first | rw [W6] | rw [Wk] | skip) <;>
      rcases sepP with h | h <;> omega
  have rdR : ∀ i, j ≤ i → i < k → s.vg.mem.readW (wa rp i) 64 = diff t n i := fun i h1 h2 => by
    rw [← hD i h2]; simp only [Mem.readW]; congr 1; apply read_congr; intro c hc
    apply hI.agree <;>
      (rw [sub_wa_add hrp (by omega) (by omega)]; first | rw [W6] | rw [Wk] | skip) <;>
      rcases sepP with h | h <;> omega
  have sel : ∀ R T : BitVec 128, XBinOp.eval .por
      (XBinOp.eval .pand R (XBinOp.eval .pcmpeqd (s.vg.xmm .xmm0) (s.vg.xmm .xmm1)))
      (XBinOp.eval .pand T (s.vg.xmm .xmm1)) = if mask t n k = 0 then R else T := fun R T => by
    rw [hI.x0, hI.x1, h1]; exact select128x _ hmask _ _
  have selW : ∀ i, j ≤ i → i + 1 < k →
      (if mask t n k = 0 then s.vg.mem.readW (wa rp i) 128 else
        s.vg.mem.readW (wa wsp (k + 6 + i)) 128).setWidth 64 = select t n k i ∧
      (if mask t n k = 0 then s.vg.mem.readW (wa rp i) 128 else
        s.vg.mem.readW (wa wsp (k + 6 + i)) 128).extractLsb' 64 64 = select t n k (i + 1) := by
    intro i h1 h2
    by_cases hm : mask t n k = 0
    · simp only [hm, select, ↓reduceIte, readW128_lo, readW128_hi, ← wa_succ]
      exact ⟨rdR i h1 (by omega), rdR (i + 1) (by omega) h2⟩
    · simp only [hm, select, ↓reduceIte, readW128_lo, readW128_hi, ← wa_succ]
      refine ⟨rdT i h1 (by omega), ?_⟩
      rw [show k + 6 + i + 1 = k + 6 + (i + 1) by omega]; exact rdT (i + 1) (by omega) h2
  have sepRF : ∀ i, i < k → ∀ j', j' + 2 ≤ 2 * k + 8 →
      128 / 8 ≤ (wa rp i - wa wsp j').toNat ∧ 64 / 8 ≤ (wa wsp j' - wa rp i).toNat := fun i hi j' hj' =>
    disj_wa hrp hw hi hj' (by rcases sepP with h | h <;> omega)
  refine ⟨by omega, hF.trans oF, by rw [o0]; exact pxor_self _, by rw [o1, hI.x1], ?_, odi,
    by rw [o9, e1, show k - j - 4 = k - (j + 4) by omega], ?_, ?_⟩
  · rw [obx]; congr 1
  · intro y hy1 hy2 hy3
    rw [omem]
    simp only [Mem.writeW]
    have hy := y.isLt
    simp only [dist, W6, Wk] at hy1 hy2 hy3
    rw [write_other _ _ 16 _ _ (by rw [dist, wa_toNat hrp (by omega)]; rcases sepP with h | h <;> omega),
      write_other _ _ 16 _ _ (by rw [dist, wa_toNat hrp (by omega)]; rcases sepP with h | h <;> omega),
      write_other _ _ 16 _ _ (by rw [dist, wa_toNat hw (by omega)]; rcases sepP with h | h <;> omega),
      write_other _ _ 16 _ _ (by rw [dist, wa_toNat hw (by omega)]; rcases sepP with h | h <;> omega),
      write_other _ _ 16 _ _ (by rw [dist, wa_toNat hw (by omega)]; rcases sepP with h | h <;> omega),
      write_other _ _ 16 _ _ (by rw [dist, wa_toNat hw (by omega)]; rcases sepP with h | h <;> omega)]
    exact hI.agree y (by rw [dist, W6]; omega) (by rw [dist, Wk]; omega) (by rw [dist]; omega)
  · intro i hi
    rw [omem]
    have hw' := hI.words
    obtain ⟨f0, f1⟩ := selW j le_rfl (by omega)
    obtain ⟨f2, f3⟩ := selW (j + 2) (by omega) (by omega)
    rw [show k + 6 + (j + 2) = k + 6 + j + 2 by omega] at f2 f3
    rcases (by omega : i < j ∨ i = j ∨ i = j + 1 ∨ i = j + 2 ∨ i = j + 3) with h | rfl | rfl | rfl | rfl
    · rw [readW_writeW_disj _ _ _ _ _ (disj_wa hrp hrp (by omega) (by omega) (by omega)),
        readW_writeW_disj _ _ _ _ _ (disj_wa hrp hrp (by omega) (by omega) (by omega)),
        readW_writeW_disj _ _ _ _ _ (sepRF i (by omega) _ (by omega)),
        readW_writeW_disj _ _ _ _ _ (sepRF i (by omega) _ (by omega)),
        readW_writeW_disj _ _ _ _ _ (sepRF i (by omega) _ (by omega)),
        readW_writeW_disj _ _ _ _ _ (sepRF i (by omega) _ (by omega))]
      exact hw' i h
    · rw [readW_writeW_disj _ _ _ _ _ (disj_wa hrp hrp (by omega) (by omega) (by omega)), readW_writeW128_lo,
        sel, f0]
    · rw [readW_writeW_disj _ _ _ _ _ (disj_wa hrp hrp (by omega) (by omega) (by omega)), wa_succ rp j,
        readW_writeW128_hi, sel, f1]
    · rw [readW_writeW128_lo, sel, f2]
    · rw [show j + 3 = j + 2 + 1 by rfl, wa_succ rp (j + 2), readW_writeW128_hi, sel, f3]

/-- The copy's trace. -/
def copyLoopTrace (rp wsp : Addr) (k : Nat) : List Leak :=
  loopTrace (fun j => copyTrace rp wsp (k + 6 + j) k j) 4 0 (k / 4 - 1)

end rind.x86_64.sqrx8xmont
