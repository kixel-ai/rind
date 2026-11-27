import Rind.X86_64.Ed25519
import Rind.X86_64.Naf
open Aeneas Aeneas.Std Result rind.spec rind.edwards
open rind.x86_64.Naf (nafVal nafDigit nafVal_drop naf_spec)

/-!
# Ed25519 verification's multi-scalar multiplication on x86_64

`msm_spec` proves that `low::x86_64::adx_mux::edwards25519_msm` writes
`[base]B + [s₀]P₀ + [s₁]P₁` in projective coordinates, wherever it runs
`low::generic::edwards25519_msm` over s2n-bignum's point routines: on CPUs
with BMI2 and ADX, and on those without AVX2. The rest run its AVX2 port,
which `quest/m4/verified/ed25519-avx2-verify.md` proves.

The multiplication is Straus's method over `low::generic::naf::public_naf`'s
non-adjacent forms, which `Rind.X86_64.Naf` proves: width-8 forms of `base`'s
two 128-bit halves, read against the static tables of `B`'s and `[2^128]B`'s
odd multiples, which the kernel checks here, and width-5 forms of `s₀` and
`s₁`, read against tables of `P₀`'s and `P₁`'s odd multiples that the
multiplication builds. Each step doubles the sum and adds each digit's
multiple, so after the digits from `i` up, the sum is each point times its
form's digits from `i` up, read as a number.
-/

namespace rind.x86_64

namespace Msm

private theorem getElem_eq_getElem! {α : Type _} [Inhabited α] (l : List α) (i : Nat) (h : i < l.length) :
    l[i] = l[i]! := by
  rw [getElem!_pos l i h]

/-! ## Points of the group in s2n-bignum's coordinates -/

/-- `l` holds the point `g` in extended coordinates. -/
def Rep (g : EdG) (l : List U64) : Prop := ExProjective g.1 l

/-- `l` holds the point `g` in projective coordinates. -/
def PRep (g : EdG) (l : List U64) : Prop := Projective g.1 l

theorem Rep.prep {g : EdG} {l : List U64} (h : Rep g l) : PRep g l := h.1

/-- Only the first twelve words name a point in projective coordinates. -/
theorem prep_take (g : EdG) (l : List U64) : PRep g (l.take 12) ↔ PRep g l := by
  simp only [PRep, Projective, List.take_take, List.drop_take]
  norm_num

theorem pow_val' (g : EdG) (n : Nat) : (g ^ n).1 = edPow g.1 n := EdG.pow_val g n

@[step]
theorem epadd_spec (h : Runs) (p3 p1 p2 : Std.Array U64 16#usize) (g1 g2 : EdG) (h1 : Rep g1 p1.val)
    (h2 : Rep g2 p2.val) :
    low.x86_64.adx_mux.edwards25519_epadd p3 p1 p2 ⦃ r => Rep (g1 * g2) r.val ⦄ := by
  apply WP.spec_mono (edwards25519_epadd_mux_spec h p3 p1 p2)
  intro r hr
  exact hr g1.1 g2.1 g1.2 g2.2 h1 h2

@[step]
theorem epdouble_spec (h : Runs) (p3 : Std.Array U64 16#usize) (p1 : Std.Array U64 12#usize) (g : EdG)
    (h1 : PRep g p1.val) :
    low.x86_64.adx_mux.edwards25519_epdouble p3 p1 ⦃ r => Rep (g * g) r.val ⦄ := by
  apply WP.spec_mono (edwards25519_epdouble_mux_spec h p3 p1)
  intro r hr
  exact hr g.1 g.2 h1

@[step]
theorem pdouble_spec (h : Runs) (p3 p1 : Std.Array U64 12#usize) (g : EdG) (h1 : PRep g p1.val) :
    low.x86_64.adx_mux.edwards25519_pdouble p3 p1 ⦃ r => PRep (g * g) r.val ⦄ := by
  apply WP.spec_mono (edwards25519_pdouble_mux_spec h p3 p1)
  intro r hr
  exact hr g.1 g.2 h1

@[step]
theorem projective_spec (point : Std.Array U64 16#usize) :
    low.generic.edwards25519_msm.projective point ⦃ r => r.val = point.val.take 12 ⦄ := by
  unfold low.generic.edwards25519_msm.projective
  step*
  simp_all [List.slice]

/-! ## Writing part of a point -/

/-- `&mut a[..n]`: the first `n` words, which write back over `a`'s. -/
theorem index_mut_to_spec {N : Usize} (a : Std.Array U64 N) (n : Usize) (hn : n.val ≤ N.val) :
    core.array.Array.index_mut (core.ops.index.IndexMutSlice (core.slice.index.SliceIndexRangeToUsizeSlice U64)) a
      { «end» := n } ⦃ s back =>
      s.length = n.val ∧ ∀ t : Slice U64, t.length = n.val → (back t).val = t.val ++ a.val.drop n.val ⦄ := by
  have hl : a.val.length = N.val := a.property
  unfold core.array.Array.index_mut
  simp only [core.ops.index.IndexMutSlice, core.slice.index.Slice.index_mut,
    core.slice.index.SliceIndexRangeToUsizeSlice, core.slice.index.SliceIndexRangeToUsizeSlice.index_mut]
  rw [ite_eq_left (by simp [Slice.length]; omega)]
  simp only [Std.bind_tc_ok, WP.spec_ok]
  refine ⟨by simp [Slice.length, List.slice]; omega, fun t ht => ?_⟩
  have ht' : t.val.length = n.val := ht
  rw [Array.from_slice_val _ _ (by simp [List.length_setSlice!])]
  simp only [Array.val_to_slice, Slice.from_val, List.setSlice!]
  simp [ht', hl, Nat.min_eq_left (show n.val ≤ N.val by omega)]

/-- `&mut a[n..]`: the words from `n` on, which write back over `a`'s. -/
theorem index_mut_from_spec {N : Usize} (a : Std.Array U64 N) (n : Usize) (hn : n.val ≤ N.val) :
    core.array.Array.index_mut (core.ops.index.IndexMutSlice (core.slice.index.SliceIndexRangeFromUsizeSlice U64)) a
      { start := n } ⦃ s back =>
      s.length = N.val - n.val ∧
        ∀ t : Slice U64, t.length = N.val - n.val → (back t).val = a.val.take n.val ++ t.val ⦄ := by
  have hl : a.val.length = N.val := a.property
  unfold core.array.Array.index_mut
  simp only [core.ops.index.IndexMutSlice, core.slice.index.Slice.index_mut,
    core.slice.index.SliceIndexRangeFromUsizeSlice, core.slice.index.SliceIndexRangeFromUsizeSlice.index_mut]
  rw [ite_eq_left (by simp [Slice.length]; omega)]
  simp only [Std.bind_tc_ok, WP.spec_ok]
  refine ⟨by simp [Slice.length, Slice.drop], fun t ht => ?_⟩
  have ht' : t.val.length = N.val - n.val := ht
  rw [Array.from_slice_val _ _ (by simp [List.length_setSlice!])]
  simp only [Array.val_to_slice, Slice.from_val, List.setSlice!]
  simp [ht', hl, show n.val + (N.val - n.val) = N.val by omega]

/-! ## Negation -/

/-- The four 4-word coordinates of 16 words. -/
theorem layout (a b c d : List U64) (ha : a.length = 4) (hb : b.length = 4) (hc : c.length = 4)
    (hd : d.length = 4) :
    (a ++ (b ++ (c ++ d))).take 4 = a ∧ ((a ++ (b ++ (c ++ d))).drop 4).take 4 = b ∧
      ((a ++ (b ++ (c ++ d))).drop 8).take 4 = c ∧ ((a ++ (b ++ (c ++ d))).drop 12).take 4 = d := by
  refine ⟨?_, ?_, ?_, ?_⟩ <;>
    simp [List.drop_append, ha, hb, hc, hd, List.take_of_length_le, List.drop_of_length_le]

/-- `-(x, y) = (-x, y)`: `X` and `T` negated mod p. -/
theorem neg_spec (point : Std.Array U64 16#usize) (g : EdG) (hg : Rep g point.val) :
    low.generic.edwards25519_msm.neg point ⦃ r => Rep g⁻¹ r.val ⦄ := by
  unfold low.generic.edwards25519_msm.neg
  have hl : point.val.length = 16 := point.property
  obtain ⟨⟨hX, hY, hZ, hZ0, hXc, hYc⟩, hT, hTc⟩ := hg
  step as ⟨s, hs, hsl⟩
  step as ⟨r, a0, hr, ha0⟩
  step as ⟨x0, hx0⟩
  rw [hr] at hx0
  injection hx0 with hx0
  subst hx0
  step as ⟨x1, x1_post⟩
  step as ⟨s1, hs1, hs1l⟩
  step as ⟨r1, a1, hr1, ha1⟩
  step as ⟨y0, hy0⟩
  rw [hr1] at hy0
  injection hy0 with hy0
  subst hy0
  step as ⟨t1, t1_post⟩
  step with index_mut_to_spec point 4#usize (by scalar_tac) as ⟨s2, back, hs2, hback⟩
  simp only [lift, bind_ok]
  step as ⟨s4, hs4⟩
  step with index_mut_from_spec (back s4) 12#usize (by scalar_tac) as ⟨s5, back1, hs5, hback1⟩
  step as ⟨s7, hs7⟩
  rw [ha0, hs] at x1_post
  rw [ha1, hs1] at t1_post
  simp only [Array.val_to_slice, List.slice, List.drop_zero, Nat.sub_zero] at x1_post t1_post
  have hT4 : List.take 4 (List.drop 12 point.val) = List.drop 12 point.val :=
    List.take_of_length_le (by simp [hl])
  rw [hT4] at hT hTc
  have hx1 := x1_post (le_of_lt hX)
  have ht1 := t1_post (le_of_lt hT)
  have hx1l : x1.val.length = 4 := x1.property
  have ht1l : t1.val.length = 4 := t1.property
  have hL : (back1 s7).val =
      x1.val ++ (List.take 4 (List.drop 4 point.val) ++ (List.take 4 (List.drop 8 point.val) ++ t1.val)) := by
    rw [hback1 _ (by simp [hs7, Slice.length, ht1l]), hback _ (by simp [hs4, Slice.length, hx1l]), hs7, hs4]
    simp only [Array.val_to_slice]
    rw [List.take_append, hx1l, List.take_of_length_le (by omega), show 12 - 4 = 4 + 4 by rfl, List.take_add,
      List.drop_drop]
    simp
  rw [hL]
  have hneg : ∀ {a : ℕ}, a < p25519 → (((p25519 - a) % p25519 : ℕ) : ℤ) ≡ -(a : ℤ) [ZMOD p25519] := by
    intro a ha
    push_cast [Nat.cast_sub (le_of_lt ha)]
    exact (Int.mod_modEq _ _).trans (Int.modEq_iff_dvd.mpr ⟨-1, by ring⟩)
  have hx := Int.mod_modEq (-(g.1.1)) p25519
  simp only [Rep, ExProjective, Projective, EdG.inv_val, edNeg]
  obtain ⟨e1, e2, e3, e4⟩ := layout x1.val (List.take 4 (List.drop 4 point.val))
    (List.take 4 (List.drop 8 point.val)) t1.val hx1l (by simp [hl]) (by simp [hl]) ht1l
  simp only [e1, e2, e3, e4]
  have hxn : (wordsNat x1.val : ℤ) ≡ -(wordsNat (List.take 4 point.val) : ℤ) [ZMOD p25519] := by
    rw [hx1]; exact hneg hX
  have htn : (wordsNat t1.val : ℤ) ≡ -(wordsNat (List.drop 12 point.val) : ℤ) [ZMOD p25519] := by
    rw [ht1]; exact hneg hT
  refine ⟨⟨by rw [hx1]; exact Nat.mod_lt _ (by decide), hY, hZ, hZ0, ?_, hYc⟩,
    by rw [ht1]; exact Nat.mod_lt _ (by decide), ?_⟩
  · refine hxn.trans ((hXc.neg).trans ?_)
    rw [← neg_mul]
    exact (hx.mul_right _).symm
  · refine ((htn.mul_right _).trans ?_).trans (hxn.mul_right _).symm
    rw [neg_mul, neg_mul]
    exact hTc.neg

/-! ## Adding a digit's multiple -/

/-- `add_digit` adds `[digit]p`, for `table` the odd multiples of `p` and a
digit of a form whose digits stay below twice the table's length. -/
@[step]
theorem add_digit_spec (h : Runs) (acc : Std.Array U64 16#usize) (table : Slice (Std.Array U64 16#usize))
    (digit : I8) (a p : EdG) (ha : Rep a acc.val)
    (ht : ∀ i < table.length, Rep (p ^ (2 * i + 1)) (table.val[i]!).val)
    (hd : nafDigit (2 * table.length) digit.val) :
    low.generic.edwards25519_msm.add_digit acc table digit ⦃ r => Rep (a * p ^ digit.val) r.val ⦄ := by
  unfold low.generic.edwards25519_msm.add_digit
  split
  · rename_i hne
    have hv : digit.val ≠ 0 := by
      intro h0
      have : digit = 0#i8 := (IScalar.eq_equiv _ _).mpr (by rw [h0]; rfl)
      simp [this] at hne
    have hodd : digit.val.natAbs % 2 = 1 ∧ digit.val.natAbs < 2 * table.length := by
      rcases hd with h0 | ⟨h1, h2, h3⟩
      · exact absurd h0 hv
      · omega
    step as ⟨i, hi⟩
    step as ⟨i1, hi1⟩
    simp only [lift, bind_ok]
    generalize hi2 : core.convert.num.FromUsizeU8.from i1 = i2
    have hi2v : i2.val = digit.val.natAbs / 2 := by
      rw [← hi2, core.convert.num.FromUsizeU8.from_val_eq, hi1, hi]
    step as ⟨entry, hentry⟩
    have hrep : Rep (p ^ digit.val.natAbs) entry.val := by
      have := ht i2.val (by omega)
      rw [show 2 * i2.val + 1 = digit.val.natAbs by omega] at this
      rw [hentry, getElem_eq_getElem! _ _ (by
        rw [hi2v]; have : table.length = table.val.length := rfl; omega)]
      exact this
    split
    · step with epadd_spec h acc acc entry a _ ha hrep as ⟨r, hr⟩
      rename_i hpos
      have hpos' : 0 < digit.val := by simpa using (IScalar.lt_equiv _ _).mp hpos
      rwa [← zpow_natCast, show ((digit.val.natAbs : ℕ) : ℤ) = digit.val by omega] at hr
    · rename_i hpos
      have hneg' : digit.val < 0 := by
        have : ¬ 0 < digit.val := fun h' => hpos ((IScalar.lt_equiv _ _).mpr (by simpa using h'))
        omega
      step with neg_spec entry _ hrep as ⟨e', he'⟩
      step with epadd_spec h acc acc e' a _ ha he' as ⟨r, hr⟩
      rwa [← zpow_natCast, ← zpow_neg, show -((digit.val.natAbs : ℕ) : ℤ) = digit.val by omega] at hr
  · rename_i he
    simp only [WP.spec_ok]
    have : digit.val = 0 := by simpa using he
    rw [this, zpow_zero, mul_one]
    exact ha

/-! ## Tables of odd multiples -/

/-- `odd_multiples` writes `[P, 3P, ..., 15P]`. -/
@[step]
theorem odd_multiples_spec (h : Runs) (point : Std.Array U64 16#usize) (g : EdG) (hg : Rep g point.val) :
    low.generic.edwards25519_msm.odd_multiples point ⦃ t =>
      ∀ i < 8, Rep (g ^ (2 * i + 1)) (t.val[i]!).val ⦄ := by
  unfold low.generic.edwards25519_msm.odd_multiples low.generic.edwards25519_msm.odd_multiples_loop
  step as ⟨a, ha⟩
  step with epdouble_spec h _ a g (by rw [ha, prep_take]; exact hg.prep) as ⟨d, hd⟩
  apply loop.spec_decr_nat (fun x => 8 - x.1.start.val)
    (fun x => 1 ≤ x.1.start.val ∧ x.1.start.val ≤ 8 ∧ x.1.end.val = 8 ∧
      ∀ i < x.1.start.val, Rep (g ^ (2 * i + 1)) (x.2.val[i]!).val)
  · rintro ⟨it, t⟩ ⟨hs1, hs, he, ht⟩
    simp only at hs1 hs he ht ⊢
    unfold low.generic.edwards25519_msm.odd_multiples_loop.body
    have htl : t.val.length = 8 := t.property
    step as ⟨o, it1, ho, he1⟩
    split_ifs at ho with hlt
    · obtain ⟨rfl, hst⟩ := ho
      simp only
      step as ⟨j, hj⟩
      step as ⟨prev, hprev⟩
      step as ⟨cur, back, hcur, hback⟩
      have hp : Rep (g ^ (2 * j.val + 1)) prev.val := by
        rw [hprev, getElem_eq_getElem! _ _ (by omega)]; exact ht _ (by omega)
      step with epadd_spec h cur prev d _ _ hp hd as ⟨n, hn⟩
      refine ⟨by omega, by omega, by rw [he1, he], ?_, by omega⟩
      intro i hi
      rw [hback]
      by_cases hie : i = it.start.val
      · subst hie
        rw [Std.Array.set_val_eq, List.getElem!_eq_getElem?_getD, List.getElem?_set_self (by omega)]
        simp only [Option.getD_some]
        rw [show 2 * it.start.val + 1 = (2 * j.val + 1) + 2 by omega, pow_add, pow_two]
        exact hn
      · rw [Std.Array.set_val_eq, List.getElem!_eq_getElem?_getD, List.getElem?_set_ne (by omega),
          ← List.getElem!_eq_getElem?_getD]
        exact ht i (by omega)
    · obtain ⟨rfl, hst⟩ := ho
      simp only [WP.spec_ok]
      intro i hi
      exact ht i (by omega)
  · refine ⟨by simp, by simp, by simp, ?_⟩
    intro i hi
    have : i = 0 := by simp at hi; omega
    subst this
    simpa using hg

/-! ## The static tables of `B`'s and `[2^128]B`'s odd multiples -/

/-- Whether `e` holds the point `Q` in extended coordinates with `Z = 1`. -/
def entryOk (e : List U64) (Q : ℕ × ℕ) : Bool :=
  wordsNat (e.take 4) == Q.1 && wordsNat ((e.drop 4).take 4) == Q.2 &&
    wordsNat ((e.drop 8).take 4) == 1 && wordsNat ((e.drop 12).take 4) == Q.1 * Q.2 % p25519

/-- Whether `es` holds `Q`, `Q + D`, `Q + 2D`, ..., each sum checked by
`edAddOk`. -/
def tableOk (D : ℕ × ℕ) : List (List U64) → ℕ × ℕ → Bool
  | [], _ => true
  | e :: es, Q => entryOk e Q &&
    (let S := edAddC Q D
     edAddOk Q D S && force S.1 fun a => force S.2 fun b => tableOk D es (a, b))

/-- Whether `es` holds the odd multiples of `[k]P`. -/
def oddTableOk (P : ℕ × ℕ) (k : ℕ) (es : List (List U64)) : Bool :=
  match edMulCheck P 256 k with
  | some Q => edAddOk Q Q (edAddC Q Q) && tableOk (edAddC Q Q) es Q
  | none => false

theorem tableOk_spec (X : Point dF) {D : ℕ × ℕ} (hD : coords (X + X) = D) :
    ∀ (es : List (List U64)) (j : ℕ), tableOk D es (coords ((2 * j + 1) • X)) = true →
      ∀ i (hi : i < es.length), entryOk es[i] (coords ((2 * (j + i) + 1) • X)) = true
  | [], _, _, i, hi => absurd hi (by simp)
  | e :: es, j, h, i, hi => by
    simp only [tableOk, Bool.and_eq_true, force_eq] at h
    obtain ⟨he, hS, ht⟩ := h
    rcases i with _ | i
    · simpa using he
    · rw [← hD] at hS
      have hS' := edAddOk_spec hS
      rw [hD] at hS'
      simp only [Prod.mk.eta] at ht
      rw [← hS', show (2 * j + 1) • X + (X + X) = (2 * (j + 1) + 1) • X by
        rw [← two_nsmul, ← add_nsmul]; ring_nf] at ht
      have := tableOk_spec X hD es (j + 1) ht i (by simpa using hi)
      simpa [show j + 1 + i = j + (i + 1) by omega] using this

theorem rep_of_entryOk (g : EdG) (Q : Point dF) (hg : g.1 = ofPoint Q) (e : List U64)
    (h : entryOk e (coords Q) = true) : Rep g e := by
  simp only [entryOk, coords, Bool.and_eq_true, beq_iff_eq] at h
  obtain ⟨⟨⟨hx, hy⟩, hz⟩, ht⟩ := h
  have hxp := ZMod.val_lt Q.1.1
  have hyp := ZMod.val_lt Q.1.2
  simp only [Rep, ExProjective, Projective, hg, ofPoint, hx, hy, hz, ht]
  refine ⟨⟨hxp, hyp, by decide, by decide, by simp [Int.ModEq], by simp [Int.ModEq]⟩,
    Nat.mod_lt _ (by decide), ?_⟩
  simp only [Int.ModEq]
  push_cast [Int.natCast_mod]
  simp

/-- `B` in the group. -/
def gB : EdG := ⟨edB, edOnCurve_B⟩

@[simp] theorem gB_val : gB.1 = edB := rfl

/-- The `i`-th sixteen words of `T`. -/
def chunk (T : List U64) (i : ℕ) : List U64 := (T.drop (16 * i)).take 16

theorem odd_table (k : ℕ) (T : Std.Array U64 1024#usize)
    (h : oddTableOk (edB.1.toNat, edB.2.toNat) k ((List.range 64).map (chunk T.val)) = true) :
    ∀ i < 64, Rep ((gB ^ k) ^ (2 * i + 1)) (chunk T.val i) := by
  intro i hi
  set X := toPoint edB edOnCurve_B
  have hX : coords X = (edB.1.toNat, edB.2.toNat) := coords_toPoint edB edOnCurve_B
  unfold oddTableOk at h
  rw [← hX] at h
  split at h
  · rename_i Q hQ
    simp only [Bool.and_eq_true] at h
    obtain ⟨hD, ht⟩ := h
    have hk := edMulCheck_spec X 256 k Q hQ
    rw [← hk] at hD ht
    have hD' := edAddOk_spec hD
    have he := tableOk_spec (k • X) hD' _ 0 (by simpa using ht) i (by simp; omega)
    rw [List.getElem_map, List.getElem_range] at he
    refine rep_of_entryOk _ _ ?_ _ (by simpa using he)
    rw [← pow_mul, pow_val', show gB.1 = ofPoint X from (ofPoint_toPoint edB edOnCurve_B).symm, edPow_ofPoint,
      mul_comm, mul_nsmul, smul_smul, smul_smul, mul_comm]
  · simp at h

theorem base_table_ok :
    oddTableOk (edB.1.toNat, edB.2.toNat) 1
      ((List.range 64).map (chunk low.generic.edwards25519_msm.BASE_ODD_MULTIPLES.val)) = true := by
  decide +kernel

theorem base128_table_ok :
    oddTableOk (edB.1.toNat, edB.2.toNat) (2 ^ 128)
      ((List.range 64).map (chunk low.generic.edwards25519_msm.BASE128_ODD_MULTIPLES.val)) = true := by
  decide +kernel

theorem base_table :
    ∀ i < 64, Rep (gB ^ (2 * i + 1)) (chunk low.generic.edwards25519_msm.BASE_ODD_MULTIPLES.val i) := by
  have := odd_table 1 low.generic.edwards25519_msm.BASE_ODD_MULTIPLES base_table_ok
  simpa only [pow_one] using this

theorem base128_table :
    ∀ i < 64, Rep ((gB ^ 2 ^ 128) ^ (2 * i + 1)) (chunk low.generic.edwards25519_msm.BASE128_ODD_MULTIPLES.val i) :=
  odd_table (2 ^ 128) low.generic.edwards25519_msm.BASE128_ODD_MULTIPLES base128_table_ok

/-- `as_chunks`'s chunk `i` is the `i`-th run of `N`. -/
theorem as_chunks_spec {T : Type} [Inhabited T] (N : Usize) (s : Slice T) (hN : 0 < N.val) :
    core.slice.Slice.as_chunks N s ⦃ c _ =>
      c.val.length = s.length / N.val ∧
      ∀ i, i < c.val.length → (c.val[i]!).val = (s.val.drop (i * N.val)).take N.val ⦄ := by
  simp only [core.slice.Slice.as_chunks, show ¬(N.val = 0) by omega, ↓reduceIte, WP.spec_ok]
  refine ⟨by simp, ?_⟩
  intro i hi
  simp only [Slice.from_val, List.length_ofFn] at hi
  rw [getElem!_pos _ i (by simpa using hi)]
  simp

/-! ## The highest nonzero digit -/

theorem top_loop_spec (nafs : Std.Array (Std.Array I8 257#usize) 4#usize)
    (iter : core.iter.adapters.rev.Rev (core.ops.range.Range Usize)) (hs : iter.iter.start.val = 0)
    (he : iter.iter.end.val ≤ 257)
    (hz : ∀ k < 4, ∀ j, iter.iter.end.val ≤ j → j < 257 → (nafs.val[k]!.val[j]!).val = 0) :
    low.generic.edwards25519_msm.top_loop iter nafs ⦃ t =>
      t.val ≤ 257 ∧ ∀ k < 4, ∀ j, t.val ≤ j → j < 257 → (nafs.val[k]!.val[j]!).val = 0 ⦄ := by
  unfold low.generic.edwards25519_msm.top_loop
  apply loop.spec_decr_nat (fun x => x.iter.end.val)
    (fun x => x.iter.start.val = 0 ∧ x.iter.end.val ≤ 257 ∧
      ∀ k < 4, ∀ j, x.iter.end.val ≤ j → j < 257 → (nafs.val[k]!.val[j]!).val = 0)
  · rintro it ⟨hs, he, hz⟩
    unfold low.generic.edwards25519_msm.top_loop.body
    have hnl : nafs.val.length = 4 := nafs.property
    step as ⟨o, it1, hst, ho⟩
    split_ifs at ho with hlt
    · obtain ⟨rfl, he1⟩ := ho
      simp only
      have hi : it1.iter.end.val < 257 := by omega
      have hz1 : ∀ k < 4, ∀ j, it1.iter.end.val + 1 ≤ j → j < 257 → (nafs.val[k]!.val[j]!).val = 0 :=
        fun k hk j hj hj' => hz k hk j (by omega) hj'
      have hget : ∀ k < 4, ∀ (r : Std.Array I8 257#usize) (hk : k < nafs.val.length), r = nafs.val[k] →
          ∀ (d : I8) (hj : it1.iter.end.val < r.val.length), d = r.val[it1.iter.end.val] →
            d = (nafs.val[k]! : Std.Array I8 257#usize).val[it1.iter.end.val]! := by
        intro k _ r hk hr d hj hd
        subst hd hr
        rw [getElem_eq_getElem! _ _ hj, getElem!_pos nafs.val k hk]
      have hzero : ∀ d : I8, ¬(d != 0#i8) = true → d.val = 0 := by
        intro d hd
        simpa using hd
      step as ⟨a, ha⟩
      step as ⟨i1, hi1⟩
      split
      · step as ⟨i2, hi2⟩
        exact ⟨by omega, by rw [hi2]; exact hz1⟩
      rename_i hn0
      step as ⟨a1, ha1⟩
      step as ⟨i2, hi2⟩
      split
      · step as ⟨i3, hi3⟩
        exact ⟨by omega, by rw [hi3]; exact hz1⟩
      rename_i hn1
      step as ⟨a2, ha2⟩
      step as ⟨i3, hi3⟩
      split
      · step as ⟨i4, hi4⟩
        exact ⟨by omega, by rw [hi4]; exact hz1⟩
      rename_i hn2
      step as ⟨a3, ha3⟩
      step as ⟨i4, hi4⟩
      split
      · step as ⟨i5, hi5⟩
        exact ⟨by omega, by rw [hi5]; exact hz1⟩
      rename_i hn3
      simp only [WP.spec_ok]
      refine ⟨by rw [hst]; exact hs, by omega, ?_, by omega⟩
      have e0 := hget 0 (by omega) a _ ha i1 _ hi1
      have e1 := hget 1 (by omega) a1 _ ha1 i2 _ hi2
      have e2 := hget 2 (by omega) a2 _ ha2 i3 _ hi3
      have e3 := hget 3 (by omega) a3 _ ha3 i4 _ hi4
      intro k hk j hj hj'
      rcases Nat.lt_or_ge it1.iter.end.val j with hlt' | hle'
      · exact hz1 k hk j (by omega) hj'
      · obtain rfl : j = it1.iter.end.val := by omega
        interval_cases k
        · rw [← e0]; exact hzero _ hn0
        · rw [← e1]; exact hzero _ hn1
        · rw [← e2]; exact hzero _ hn2
        · rw [← e3]; exact hzero _ hn3
    · obtain rfl := ho
      simp only [WP.spec_ok]
      refine ⟨by simp, ?_⟩
      intro k hk j _ hj
      exact hz k hk j (by omega) hj
  · exact ⟨hs, he, hz⟩

/-- `top` is one past the highest nonzero digit of any form, or 0. -/
@[step]
theorem top_spec (nafs : Std.Array (Std.Array I8 257#usize) 4#usize) :
    low.generic.edwards25519_msm.top nafs ⦃ t =>
      t.val ≤ 257 ∧ ∀ k < 4, ∀ j, t.val ≤ j → j < 257 → (nafs.val[k]!.val[j]!).val = 0 ⦄ := by
  unfold low.generic.edwards25519_msm.top
  step as ⟨iter, iter_post⟩
  exact top_loop_spec nafs iter (by simp [iter_post]) (by simp [iter_post])
    (fun k _ j hj hj' => absurd hj' (by simp [iter_post] at hj; omega))

/-- `non_adjacent_forms` writes the width-8 forms of `base`'s halves and the
width-5 forms of the scalars. -/
@[step]
theorem non_adjacent_forms_spec (base : Std.Array U64 4#usize) (scalars : Std.Array (Std.Array U64 4#usize) 2#usize) :
    low.generic.edwards25519_msm.non_adjacent_forms base scalars ⦃ nafs =>
      (∀ k < 4, ∀ j < 257, nafDigit (if k < 2 then 128 else 16) (nafs.val[k]!.val[j]!).val) ∧
      nafVal (nafs.val[0]! : Std.Array I8 257#usize).val = wordsNat (base.val.take 2) ∧
      nafVal (nafs.val[1]! : Std.Array I8 257#usize).val = wordsNat (base.val.drop 2) ∧
      nafVal (nafs.val[2]! : Std.Array I8 257#usize).val = wordsNat (scalars.val[0]!).val ∧
      nafVal (nafs.val[3]! : Std.Array I8 257#usize).val = wordsNat (scalars.val[1]!).val ⦄ := by
  unfold low.generic.edwards25519_msm.non_adjacent_forms
  have hrep : ∀ (a : Std.Array I8 257#usize), a.val.length = 257 := fun a => a.property
  step as ⟨i0, hi0⟩
  step as ⟨i1, hi1⟩
  simp only [lift, bind_ok]
  step as ⟨a1, back1, ha1, hback1⟩
  simp only [Array.to_slice_mut]
  step with naf_spec 8#u32 (by simp) (Std.Array.make 4#usize [i0, i1, 0#u64, 0#u64]).to_slice 256
    (by simp [Slice.length]) (by decide) (by simp [Slice.length]) a1.to_slice (by simp [Slice.length, hrep])
    as ⟨s2, hs2l, hs2v, hs2d⟩
  step as ⟨i2, hi2⟩
  step as ⟨i3, hi3⟩
  step as ⟨a3, back2, ha3, hback2⟩
  step with naf_spec 8#u32 (by simp) (Std.Array.make 4#usize [i2, i3, 0#u64, 0#u64]).to_slice 256
    (by simp [Slice.length]) (by decide) (by simp [Slice.length]) a3.to_slice (by simp [Slice.length, hrep])
    as ⟨s5, hs5l, hs5v, hs5d⟩
  step as ⟨a4, ha4⟩
  step as ⟨a6, back3, ha6, hback3⟩
  step with naf_spec 5#u32 (by simp) a4.to_slice 256
    (by simp [Slice.length]) (by decide) (by simp [Slice.length]) a6.to_slice (by simp [Slice.length, hrep])
    as ⟨s8, hs8l, hs8v, hs8d⟩
  step as ⟨a7, ha7⟩
  step as ⟨a9, back4, ha9, hback4⟩
  step with naf_spec 5#u32 (by simp) a7.to_slice 256
    (by simp [Slice.length]) (by decide) (by simp [Slice.length]) a9.to_slice (by simp [Slice.length, hrep])
    as ⟨s11, hs11l, hs11v, hs11d⟩
  have hfs : ∀ (a : Std.Array I8 257#usize) (t : Slice I8), t.length = 256 + 1 → (a.from_slice t).val = t.val :=
    fun a t ht => Array.from_slice_val _ _ ht
  have hF : (back4 (a9.from_slice s11)).val = [a1.from_slice s2, a3.from_slice s5, a6.from_slice s8,
      a9.from_slice s11] := by
    subst hback4 hback3 hback2 hback1
    generalize Std.Array.repeat 257#usize 0#i8 = z
    simp [Std.Array.set_val_eq, Std.Array.repeat, List.replicate]
  have hbl : base.val.length = 4 := base.property
  have hb2 : List.take 2 base.val = [i0, i1] := by
    rw [hi0, hi1]
    apply List.ext_getElem (by simp [hbl])
    intro n h1 h2
    simp at h1 h2
    interval_cases n <;> simp
  have hd2 : List.drop 2 base.val = [i2, i3] := by
    rw [hi2, hi3]
    apply List.ext_getElem (by simp [hbl])
    intro n h1 h2
    simp [hbl] at h1 h2
    interval_cases n <;> simp
  have hpad : ∀ a b : U64, wordsNat [a, b, 0#u64, 0#u64] = wordsNat [a, b] := by
    intro a b; simp [wordsNat, Nat.ofDigits]
  have hsl : ∀ (k : Std.Array U64 4#usize) (hk : 0 < scalars.val.length), k = scalars.val[0] →
      k.to_slice.val = (scalars.val[0]!).val := by
    intro k hk h; rw [h, Array.val_to_slice, getElem!_pos scalars.val 0 hk]
  have hsl1 : ∀ (k : Std.Array U64 4#usize) (hk : 1 < scalars.val.length), k = scalars.val[1] →
      k.to_slice.val = (scalars.val[1]!).val := by
    intro k hk h; rw [h, Array.val_to_slice, getElem!_pos scalars.val 1 hk]
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · intro k hk j hj
    rw [hF]
    interval_cases k
    · simpa [hfs _ _ hs2l] using hs2d j hj
    · simpa [hfs _ _ hs5l] using hs5d j hj
    · simpa [hfs _ _ hs8l] using hs8d j hj
    · simpa [hfs _ _ hs11l] using hs11d j hj
  · rw [hF]; simp only [List.getElem!_cons_zero]
    rw [hfs _ _ hs2l, hs2v, hb2, Array.val_to_slice, Std.Array.make_val, hpad]
  · rw [hF]; simp only [List.getElem!_cons_succ, List.getElem!_cons_zero]
    rw [hfs _ _ hs5l, hs5v, hd2, Array.val_to_slice, Std.Array.make_val, hpad]
  · rw [hF]; simp only [List.getElem!_cons_succ, List.getElem!_cons_zero]
    rw [hfs _ _ hs8l, hs8v, hsl a4 _ ha4]
  · rw [hF]; simp only [List.getElem!_cons_succ, List.getElem!_cons_zero]
    rw [hfs _ _ hs11l, hs11v, hsl1 a7 _ ha7]

/-! ## The loop -/

/-- The sum each point's form's digits from `i` up name. -/
noncomputable def acc (nafs : Std.Array (Std.Array I8 257#usize) 4#usize) (B0 B1 P0 P1 : EdG) (i : ℕ) : EdG :=
  B0 ^ nafVal ((nafs.val[0]!).val.drop i) * B1 ^ nafVal ((nafs.val[1]!).val.drop i) *
    P0 ^ nafVal ((nafs.val[2]!).val.drop i) * P1 ^ nafVal ((nafs.val[3]!).val.drop i)

theorem acc_step (nafs : Std.Array (Std.Array I8 257#usize) 4#usize) (B0 B1 P0 P1 : EdG) (i : ℕ) (hi : i < 257) :
    acc nafs B0 B1 P0 P1 i = acc nafs B0 B1 P0 P1 (i + 1) * acc nafs B0 B1 P0 P1 (i + 1) *
      B0 ^ (nafs.val[0]!.val[i]!).val * B1 ^ (nafs.val[1]!.val[i]!).val *
      P0 ^ (nafs.val[2]!.val[i]!).val * P1 ^ (nafs.val[3]!.val[i]!).val := by
  have hl : ∀ k : ℕ, (nafs.val[k]! : Std.Array I8 257#usize).val.length = 257 :=
    fun k => (nafs.val[k]! : Std.Array I8 257#usize).property
  have hd : ∀ (X : EdG) (d v : ℤ), X ^ (d + 2 * v) = X ^ v * X ^ v * X ^ d := by
    intro X d v; rw [zpow_add, two_mul, zpow_add, mul_comm]
  simp only [acc]
  rw [nafVal_drop (nafs.val[0]! : Std.Array I8 257#usize).val i (by rw [hl]; exact hi),
    nafVal_drop (nafs.val[1]! : Std.Array I8 257#usize).val i (by rw [hl]; exact hi),
    nafVal_drop (nafs.val[2]! : Std.Array I8 257#usize).val i (by rw [hl]; exact hi),
    nafVal_drop (nafs.val[3]! : Std.Array I8 257#usize).val i (by rw [hl]; exact hi), hd, hd, hd, hd]
  ac_rfl

/-- Whether all four digits are zero. -/
@[step]
theorem digits_eq_spec (a b c d : I8) :
    core.array.equality.PartialEqArray.eq core.cmp.PartialEqI8 (Std.Array.make 4#usize [a, b, c, d])
      (Std.Array.repeat 4#usize 0#i8) ⦃ r => r = true ↔ (a.val = 0 ∧ b.val = 0 ∧ c.val = 0 ∧ d.val = 0) ⦄ := by
  simp [core.array.equality.PartialEqArray.eq, Std.Array.make, Std.Array.repeat]
  by_cases ha : a.val = 0 <;> by_cases hb : b.val = 0 <;> by_cases hc : c.val = 0 <;>
    by_cases hd : d.val = 0 <;> simp [ha, hb, hc, hd, WP.spec_ok, pure]

theorem loop_spec (h : Runs) (nafs : Std.Array (Std.Array I8 257#usize) 4#usize)
    (table0 table1 : Std.Array (Std.Array U64 16#usize) 8#usize) (P0 P1 : EdG)
    (hd : ∀ k < 4, ∀ j < 257, nafDigit (if k < 2 then 128 else 16) (nafs.val[k]!.val[j]!).val)
    (ht0 : ∀ i < 8, Rep (P0 ^ (2 * i + 1)) (table0.val[i]!).val)
    (ht1 : ∀ i < 8, Rep (P1 ^ (2 * i + 1)) (table1.val[i]!).val)
    (a : Std.Array U64 16#usize) (i : Usize) (hi : i.val ≤ 257)
    (ha : PRep (acc nafs gB (gB ^ 2 ^ 128) P0 P1 i.val) a.val) :
    low.generic.edwards25519_msm.edwards25519_msm_loop nafs table0 table1 a i ⦃ r =>
      PRep (acc nafs gB (gB ^ 2 ^ 128) P0 P1 0) r.val ⦄ := by
  unfold low.generic.edwards25519_msm.edwards25519_msm_loop
  have hB0 := base_table
  have hB1 := base128_table
  apply loop.spec_decr_nat (fun x => x.2.val)
    (fun x => x.2.val ≤ 257 ∧ PRep (acc nafs gB (gB ^ 2 ^ 128) P0 P1 x.2.val) x.1.val)
  · rintro ⟨a, i⟩ ⟨hi, ha⟩
    simp only at hi ha ⊢
    unfold low.generic.edwards25519_msm.edwards25519_msm_loop.body
    have hnl : nafs.val.length = 4 := nafs.property
    have hrow : ∀ k : ℕ, (nafs.val[k]! : Std.Array I8 257#usize).val.length = 257 :=
    fun k => (nafs.val[k]! : Std.Array I8 257#usize).property
    split
    · rename_i hpos
      have hpos' : 0 < i.val := by scalar_tac
      step as ⟨i1, hi1⟩
      step as ⟨r0, hr0⟩
      step as ⟨d0, hd0⟩
      step as ⟨r1, hr1⟩
      step as ⟨d1, hd1⟩
      step as ⟨r2, hr2⟩
      step as ⟨d2, hd2⟩
      step as ⟨r3, hr3⟩
      step as ⟨d3, hd3⟩
      have hget : ∀ k < 4, ∀ (r : Std.Array I8 257#usize) (hk : k < nafs.val.length), r = nafs.val[k] →
          ∀ (d : I8) (hj : i1.val < r.val.length), d = r.val[i1.val] →
            d = (nafs.val[k]! : Std.Array I8 257#usize).val[i1.val]! := by
        intro k _ r hk hr d hj hd
        subst hd hr
        rw [getElem_eq_getElem! _ _ hj, getElem!_pos nafs.val k hk]
      have e0 := hget 0 (by omega) r0 _ hr0 d0 _ hd0
      have e1 := hget 1 (by omega) r1 _ hr1 d1 _ hd1
      have e2 := hget 2 (by omega) r2 _ hr2 d2 _ hd2
      have e3 := hget 3 (by omega) r3 _ hr3 d3 _ hd3
      have hS := acc_step nafs gB (gB ^ 2 ^ 128) P0 P1 i1.val (by omega)
      rw [show i1.val + 1 = i.val by omega, ← e0, ← e1, ← e2, ← e3] at hS
      step as ⟨b, hb⟩
      split
      · rename_i hbt
        obtain ⟨z0, z1, z2, z3⟩ := hb.mp hbt
        rw [z0, z1, z2, z3] at hS
        simp only [zpow_zero, mul_one] at hS
        step as ⟨p, hp⟩
        step with pdouble_spec h _ p _ (by rw [hp, prep_take]; exact ha) as ⟨dbl, hdbl⟩
        step with index_mut_to_spec a 12#usize (by scalar_tac) as ⟨sl, back, hsl, hback⟩
        simp only [lift, bind_ok]
        have hdl : dbl.val.length = 12 := dbl.property
        step with core.slice.Slice.copy_from_slice.step_spec _ sl dbl.to_slice
          (by simp [hsl, Slice.length, hdl]) as ⟨s2, hs2⟩
        refine ⟨by omega, ?_, by omega⟩
        rw [← prep_take, hback _ (by simp [hs2, Slice.length, hdl]), hs2, hS]
        simpa [List.take_append_of_le_length, hdl] using hdbl
      · step as ⟨p, hp⟩
        step with epdouble_spec h a p _ (by rw [hp, prep_take]; exact ha) as ⟨e, he⟩
        have hchunks : ∀ (T : Std.Array U64 1024#usize) (c : Slice (Std.Array U64 16#usize)) (g : EdG),
            (∀ i < 64, Rep (g ^ (2 * i + 1)) (chunk T.val i)) → c.val.length = T.to_slice.length / 16 →
            (∀ i < c.val.length, (c.val[i]!).val = (T.to_slice.val.drop (i * 16)).take 16) →
            c.length = 64 ∧ ∀ i < c.length, Rep (g ^ (2 * i + 1)) (c.val[i]!).val := by
          intro T c g hT hcl hc
          have hTl : T.val.length = 1024 := T.property
          have hcl' : c.val.length = 64 := by rw [hcl]; simp [Slice.length, hTl]
          refine ⟨hcl', fun i hi => ?_⟩
          have hi' : i < c.val.length := hi
          rw [hc i hi', Array.val_to_slice, Nat.mul_comm i 16]
          exact hT i (by omega)
        have htab : ∀ (T : Std.Array (Std.Array U64 16#usize) 8#usize) (g : EdG),
            (∀ i < 8, Rep (g ^ (2 * i + 1)) (T.val[i]!).val) →
            T.to_slice.length = 8 ∧ ∀ i < T.to_slice.length, Rep (g ^ (2 * i + 1)) (T.to_slice.val[i]!).val := by
          intro T g hT
          have hTl : T.val.length = 8 := T.property
          refine ⟨by simp [Slice.length, hTl], fun i hi => ?_⟩
          rw [Array.val_to_slice]
          exact hT i (by simpa [Slice.length, hTl] using hi)
        simp only [lift, bind_ok]
        step with as_chunks_spec 16#usize low.generic.edwards25519_msm.BASE_ODD_MULTIPLES.to_slice (by simp)
          as ⟨c0, _, hc0l, hc0⟩
        obtain ⟨hc0l', hc0'⟩ := hchunks _ c0 gB hB0 hc0l hc0
        have hdig0 := hd 0 (by omega) i1.val (by omega)
        have hdig1 := hd 1 (by omega) i1.val (by omega)
        have hdig2 := hd 2 (by omega) i1.val (by omega)
        have hdig3 := hd 3 (by omega) i1.val (by omega)
        rw [← e0] at hdig0
        rw [← e1] at hdig1
        rw [← e2] at hdig2
        rw [← e3] at hdig3
        simp only [show (0 : ℕ) < 2 from by decide, show (1 : ℕ) < 2 from by decide,
          show ¬ (2 : ℕ) < 2 from by decide, show ¬ (3 : ℕ) < 2 from by decide, ↓reduceIte] at hdig0 hdig1 hdig2 hdig3
        step as ⟨i6, hi6⟩
        simp only [Std.Array.make_val, List.getElem_cons_zero] at hi6
        subst i6
        step with add_digit_spec h e c0 d0 _ gB he hc0' (by rw [hc0l']; exact hdig0) as ⟨acc2, hacc2⟩
        step with as_chunks_spec 16#usize low.generic.edwards25519_msm.BASE128_ODD_MULTIPLES.to_slice (by simp)
          as ⟨c1, _, hc1l, hc1⟩
        obtain ⟨hc1l', hc1'⟩ := hchunks _ c1 _ hB1 hc1l hc1
        step as ⟨i7, hi7⟩
        simp only [Std.Array.make_val, List.getElem_cons_succ, List.getElem_cons_zero] at hi7
        subst i7
        step with add_digit_spec h acc2 c1 d1 _ _ hacc2 hc1' (by rw [hc1l']; exact hdig1) as ⟨acc3, hacc3⟩
        obtain ⟨ht0l, ht0'⟩ := htab table0 P0 ht0
        obtain ⟨ht1l, ht1'⟩ := htab table1 P1 ht1
        step as ⟨i8, hi8⟩
        simp only [Std.Array.make_val, List.getElem_cons_succ, List.getElem_cons_zero] at hi8
        subst i8
        step with add_digit_spec h acc3 table0.to_slice d2 _ _ hacc3 ht0' (by rw [ht0l]; exact hdig2)
          as ⟨acc4, hacc4⟩
        step as ⟨i9, hi9⟩
        simp only [Std.Array.make_val, List.getElem_cons_succ, List.getElem_cons_zero] at hi9
        subst i9
        step with add_digit_spec h acc4 table1.to_slice d3 _ _ hacc4 ht1' (by rw [ht1l]; exact hdig3)
          as ⟨acc5, hacc5⟩
        refine ⟨by omega, ?_, by omega⟩
        rw [hS]
        exact hacc5.prep
    · rename_i hz
      have : i.val = 0 := by scalar_tac
      simp only [WP.spec_ok]
      rwa [this] at ha
  · exact ⟨hi, ha⟩

/-! ## The multiplication -/

theorem nafVal_eq_zero (l : List I8) (h : ∀ x ∈ l, x.val = 0) : nafVal l = 0 := by
  induction l with
  | nil => rfl
  | cons d ds ih =>
    simp only [nafVal]
    rw [h d (by simp), ih (fun x hx => h x (by simp [hx]))]
    simp

/-- `B` and the two points' sum by `base` and the two scalars, as words. -/
@[step]
theorem msm_generic_spec (h : Runs) (res : Std.Array U64 12#usize) (base : Std.Array U64 4#usize)
    (scalars : Std.Array (Std.Array U64 4#usize) 2#usize) (points : Std.Array (Std.Array U64 16#usize) 2#usize)
    (P0 P1 : EdG) (h0 : Rep P0 (points.val[0]!).val) (h1 : Rep P1 (points.val[1]!).val) :
    low.generic.edwards25519_msm.edwards25519_msm res base scalars points ⦃ r =>
      PRep (gB ^ wordsNat base.val * P0 ^ wordsNat (scalars.val[0]!).val * P1 ^ wordsNat (scalars.val[1]!).val)
        r.val ⦄ := by
  unfold low.generic.edwards25519_msm.edwards25519_msm
  have hpl : points.val.length = 2 := points.property
  step as ⟨nafs, hd, h0v, h1v, h2v, h3v⟩
  step as ⟨a, ha⟩
  step with odd_multiples_spec h a P0 (by rw [ha, getElem_eq_getElem! _ _ (by omega)]; exact h0) as ⟨t0, ht0⟩
  step as ⟨a1, ha1⟩
  step with odd_multiples_spec h a1 P1 (by rw [ha1, getElem_eq_getElem! _ _ (by omega)]; exact h1) as ⟨t1, ht1⟩
  step as ⟨i, hi, hz⟩
  have hrow : ∀ k : ℕ, (nafs.val[k]! : Std.Array I8 257#usize).val.length = 257 :=
    fun k => (nafs.val[k]! : Std.Array I8 257#usize).property
  have hzero : ∀ k : ℕ, k < 4 → nafVal ((nafs.val[k]!).val.drop i.val) = 0 := by
    intro k hk
    apply nafVal_eq_zero
    intro x hx
    obtain ⟨m, hm, rfl⟩ := List.mem_iff_getElem.mp hx
    simp only [List.length_drop, hrow] at hm
    rw [List.getElem_drop, getElem_eq_getElem! _ _ (by first | omega | (rw [hrow]; omega))]
    exact hz k hk _ (by omega) (by omega)
  have hid : PRep (acc nafs gB (gB ^ 2 ^ 128) P0 P1 i.val) low.generic.edwards25519_msm.IDENTITY.val := by
    rw [show acc nafs gB (gB ^ 2 ^ 128) P0 P1 i.val = 1 by
      simp only [acc, hzero 0 (by omega), hzero 1 (by omega), hzero 2 (by omega), hzero 3 (by omega), zpow_zero,
        mul_one]]
    simp only [low.generic.edwards25519_msm.IDENTITY]
    simp [PRep, Projective, wordsNat, Nat.ofDigits, edId, Int.ModEq, p25519]
  step with loop_spec h nafs t0 t1 P0 P1 hd ht0 ht1 _ i hi hid as ⟨r, hr⟩
  simp only [lift, bind_ok, Array.to_slice_mut]
  step as ⟨q, hq⟩
  have hql : q.val.length = 12 := q.property
  have hresl : res.val.length = 12 := res.property
  step with core.slice.Slice.copy_from_slice.step_spec _ res.to_slice q.to_slice
    (by simp [Slice.length, hql, hresl]) as ⟨s2, hs2⟩
  rw [hs2, Array.from_slice_val _ _ (by simp [hql]), Array.val_to_slice, hq, prep_take]
  have hacc : acc nafs gB (gB ^ 2 ^ 128) P0 P1 0 =
      gB ^ wordsNat base.val * P0 ^ wordsNat (scalars.val[0]!).val * P1 ^ wordsNat (scalars.val[1]!).val := by
    have hb : wordsNat base.val = wordsNat (base.val.take 2) + 2 ^ 128 * wordsNat (base.val.drop 2) := by
      conv_lhs => rw [← List.take_append_drop 2 base.val]
      rw [rind.spec.rsa.wordsNat_append, List.length_take, show min 2 base.val.length = 2 by
        have : base.val.length = 4 := base.property
        omega]
    simp only [acc, List.drop_zero, h0v, h1v, h2v, h3v, zpow_natCast, hb, pow_add, pow_mul]
  rw [hacc] at hr
  exact hr

/-- Ed25519 verification's multi-scalar multiplication runs rind's Straus loop
over s2n-bignum's point routines: the CPU has BMI2 and ADX, or lacks AVX2.
The rest run its AVX2 port, which `quest/m4/verified/ed25519-avx2-verify.md`
proves. Neither check reads an input. -/
def MsmS2n : Prop :=
  ∃ o o1, low.x86_64.cpu.HaveBmi2Adx.check = ok o ∧ low.x86_64.cpu.HaveAvx2.check = ok o1 ∧
    (o.isSome ∨ o1 = none)

/-- `low::x86_64::adx_mux::edwards25519_msm` writes `[base]B + [s₀]P₀ + [s₁]P₁`
in projective coordinates, for two points of the group in extended ones. -/
theorem msm_spec (h : Runs) (hm : MsmS2n) (res : Std.Array U64 12#usize) (base : Std.Array U64 4#usize)
    (scalars : Std.Array (Std.Array U64 4#usize) 2#usize) (points : Std.Array (Std.Array U64 16#usize) 2#usize)
    (P₀ P₁ : EdPoint) (hP₀ : edOnCurve P₀) (hP₁ : edOnCurve P₁)
    (h₀ : ExProjective P₀ (points.val[0]!).val) (h₁ : ExProjective P₁ (points.val[1]!).val) :
    low.x86_64.adx_mux.edwards25519_msm res base scalars points ⦃ r =>
      Projective (edMul (edMul (edPow edB (wordsNat base.val)) (edPow P₀ (wordsNat (scalars.val[0]!).val)))
        (edPow P₁ (wordsNat (scalars.val[1]!).val))) r.val ⦄ := by
  have hg := msm_generic_spec h res base scalars points ⟨P₀, hP₀⟩ ⟨P₁, hP₁⟩ h₀ h₁
  simp only [PRep, EdG.mul_val, pow_val'] at hg
  obtain ⟨o, o1, ho, ho1, hc⟩ := hm
  unfold low.x86_64.adx_mux.edwards25519_msm
  rw [ho, ho1]
  simp only [bind_ok]
  rcases o with _ | t
  · simp only [Option.isSome_none, Bool.false_eq_true, false_or] at hc
    subst hc
    exact hg
  · exact hg

end Msm

end rind.x86_64
