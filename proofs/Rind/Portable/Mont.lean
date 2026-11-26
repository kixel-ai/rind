import Rind.Portable.Funs
import Rind.RsaLemmas
open Aeneas Aeneas.Std Result rind.spec rind.spec.rsa

/-!
# The portable backend's Montgomery products

`low::generic::mont`'s routines over 64-bit limbs, each against `Nat`
arithmetic on the limbs `wordsNat` reads.
-/

namespace rind.portable

/-! ## Limbs -/

theorem mul_add_limb_bound (a b c d : Nat) (ha : a < 2 ^ 64) (hb : b < 2 ^ 64) (hc : c < 2 ^ 64)
    (hd : d < 2 ^ 64) : a * b + c + d < 2 ^ 128 := by
  have : a * b ≤ (2 ^ 64 - 1) * (2 ^ 64 - 1) := Nat.mul_le_mul (by omega) (by omega)
  omega

theorem from_u128_val (x : U64) : (core.convert.num.FromU128U64.from x).val = x.val := by
  simp only [core.convert.num.FromU128U64.from, UScalar.val, BitVec.toNat_setWidth]
  exact Nat.mod_eq_of_lt (lt_trans x.bv.isLt (by norm_num))

@[step]
theorem from_u128_spec (x : U64) : lift (core.convert.num.FromU128U64.from x) ⦃ r => r.val = x.val ⦄ := by
  simp [lift]

@[step]
theorem mul_add_limb_spec (a b c : U64) (d : U128) (hd : d.val < 2 ^ 64) :
    low.generic.limb64.mont.mul_add_limb a b c d ⦃ r =>
      r.val = a.val * b.val + c.val + d.val ⦄ := by
  unfold low.generic.limb64.mont.mul_add_limb
  have hb := mul_add_limb_bound a.val b.val c.val d.val a.hBounds b.hBounds c.hBounds hd
  have hab : a.val * b.val < 2 ^ 128 := by omega
  simp only [lift, bind_ok, WP.spec_ok, core.num.U128.wrapping_add_val_eq,
    core.num.U128.wrapping_mul_val_eq, from_u128_val, UScalar.size, UScalarTy.numBits]
  rw [Nat.mod_eq_of_lt hab, Nat.mod_eq_of_lt (by omega), Nat.mod_eq_of_lt (by omega)]

/-- A `u128`'s low limb. -/
theorem cast_u64_val (t : U128) : (UScalar.cast .U64 t).val = t.val % 2 ^ 64 := by
  simp [UScalar.cast_val_eq]

theorem shr_bits_lt (t : U128) : t.val >>> 64 < 2 ^ 64 := by
  have := t.hBounds
  rw [Nat.shiftRight_eq_div_pow]
  simp only [UScalarTy.numBits] at this
  omega

theorem u64_lt (x : U64) : x.val < 2 ^ 64 := x.hBounds

theorem u64_le (x : U64) : x.val ≤ 2 ^ 64 - 1 := Nat.le_pred_of_lt x.hBounds

theorem u64_size : U64.size = 2 ^ 64 := by
  simp [U64.size, U64.numBits]

theorem lift_eq {α : Type} (x : α) : lift x = ok x := rfl

/-! ## Lists of limbs -/

theorem wordsNat_take_succ' (l : List U64) (i : Nat) (hi : i < l.length) :
    wordsNat (l.take (i + 1)) = wordsNat (l.take i) + 2 ^ (64 * i) * l[i]!.val := by
  rw [List.take_add_one, List.getElem?_eq_getElem hi, Option.toList_some, wordsNat_append, wordsNat_cons,
    wordsNat_nil, List.length_take, getElem!_pos l i hi, Nat.min_eq_left hi.le]
  ring

theorem take_set_succ' {α : Type} (l : List α) (i : Nat) (v : α) (hi : i < l.length) :
    (l.set i v).take (i + 1) = l.take i ++ [v] := by
  rw [List.take_add_one, List.getElem?_set_self (by simpa using hi), Option.toList_some,
    List.take_set_of_le (by omega)]

theorem drop_set_succ' {α : Type} (l : List α) (i : Nat) (v : α) :
    (l.set i v).drop (i + 1) = l.drop (i + 1) := by
  rw [List.drop_set]; simp

theorem drop_set_lt {α : Type} (l : List α) (i m : Nat) (v : α) (h : i < m) :
    (l.set i v).drop m = l.drop m := by
  apply List.ext_getElem?
  intro k
  simp only [List.getElem?_drop, List.getElem?_set]
  split <;> first | rfl | omega

theorem getElem!_of_drop_eq {α : Type} [Inhabited α] {l l0 : List α} {i : Nat} (h : l.drop i = l0.drop i) :
    l[i]! = l0[i]! := by
  have := congrArg (·[0]!) h
  simp only [List.getElem!_eq_getElem?_getD, List.getElem?_drop, Nat.add_zero] at this
  simpa [List.getElem!_eq_getElem?_getD] using this

/-- One limb of a multiply-accumulate: the low half of `t = u·y + x + c`
lands at limb `i`, and the high half carries. -/
theorem mac_step {X X0 Y c t i xi yi u : Nat} (hinv : X + 2 ^ (64 * i) * c = X0 + u * Y)
    (ht : t = u * yi + xi + c) :
    X + 2 ^ (64 * i) * (t % 2 ^ 64) + 2 ^ (64 * (i + 1)) * (t / 2 ^ 64) =
      X0 + 2 ^ (64 * i) * xi + u * (Y + 2 ^ (64 * i) * yi) := by
  have h := Nat.mod_add_div t (2 ^ 64)
  rw [show 64 * (i + 1) = 64 * i + 64 by ring, pow_add]
  zify at *
  linear_combination (2 ^ (64 * i) : Int) * h + hinv + (2 ^ (64 * i) : Int) * ht

/-! ## `mul_add` -/

theorem mul_add_loop_spec (u : U64) (y x0 : Slice U64) (hy : y.length = x0.length)
    (iter : core.ops.range.Range Usize) (x : Slice U64) (carry : U128)
    (hend : iter.end.val = x0.length) (hi : iter.start.val ≤ x0.length) (hxl : x.length = x0.length)
    (hc : carry.val < 2 ^ 64) (hdrop : x.val.drop iter.start.val = x0.val.drop iter.start.val)
    (hinv : wordsNat (x.val.take iter.start.val) + 2 ^ (64 * iter.start.val) * carry.val =
      wordsNat (x0.val.take iter.start.val) + u.val * wordsNat (y.val.take iter.start.val)) :
    low.generic.limb64.mont.mul_add_loop iter x u y carry ⦃ r =>
      r.2.length = x0.length ∧ r.1.val < 2 ^ 64 ∧
      wordsNat r.2.val + 2 ^ (64 * x0.length) * r.1.val = wordsNat x0.val + u.val * wordsNat y.val ⦄ := by
  unfold low.generic.limb64.mont.mul_add_loop
  apply loop.spec_decr_nat (fun x => x0.length - x.1.start.val)
    (fun x : core.ops.range.Range Usize × Slice U64 × U128 =>
      x.1.end.val = x0.length ∧ x.1.start.val ≤ x0.length ∧ x.2.1.length = x0.length ∧
      x.2.2.val < 2 ^ 64 ∧ x.2.1.val.drop x.1.start.val = x0.val.drop x.1.start.val ∧
      wordsNat (x.2.1.val.take x.1.start.val) + 2 ^ (64 * x.1.start.val) * x.2.2.val =
        wordsNat (x0.val.take x.1.start.val) + u.val * wordsNat (y.val.take x.1.start.val))
  · rintro ⟨it, v, c⟩ ⟨he, hs, hvl, hc, hd, hv⟩
    simp only at he hs hvl hc hd hv
    unfold low.generic.limb64.mont.mul_add_loop.body
    step as ⟨op, iter1, hop, hend1⟩
    cases op with
    | none =>
      have h0 : it.start.val = x0.length := by
        split at hop
        · simp at hop
        · scalar_tac
      simp only [WP.spec_ok]
      rw [h0] at hv
      have hvl' : v.val.length = x0.length := hvl
      have hyl : y.val.length = x0.length := hy
      have hx0l : x0.val.length = x0.length := rfl
      rw [List.take_of_length_le (by omega), List.take_of_length_le (by omega),
        List.take_of_length_le (by omega)] at hv
      exact ⟨hvl, hc, hv⟩
    | some j =>
      have hlt : it.start.val < it.end.val := by
        by_contra hc; simp [hc] at hop
      simp only [hlt, ↓reduceIte, Option.some.injEq] at hop
      obtain ⟨rfl, hst⟩ := hop
      rw [he] at hlt
      have hvL : v.length = v.val.length := rfl
      have hyL : y.length = y.val.length := rfl
      have hx0L : x0.length = x0.val.length := rfl
      step as ⟨yi, hyi⟩
      step as ⟨xi, hxi⟩
      step with mul_add_limb_spec u yi xi c hc as ⟨t, ht⟩
      step as ⟨w, hw⟩
      step as ⟨s, hs⟩
      step as ⟨c1, hc1, _⟩
      have hxi0 : xi = x0.val[it.start.val]! := by
        rw [hxi, ← getElem!_pos]; exact getElem!_of_drop_eq hd
      have hsv : s.val = v.val.set it.start.val (UScalar.cast .U64 t) := by rw [hs, hw]; simp
      have hc1v : c1.val = t.val / 2 ^ 64 := by rw [hc1]; simp [Nat.shiftRight_eq_div_pow]
      have htb : t.val < 2 ^ 128 := by
        rw [ht]; exact mul_add_limb_bound _ _ _ _ u.hBounds yi.hBounds xi.hBounds hc
      refine ⟨by rw [hend1, he], by scalar_tac, by rw [hs]; simp at hvl ⊢; omega,
        by rw [hc1v]; omega, ?_, ?_⟩
      · rw [hst, hsv, drop_set_succ']
        rw [List.drop_eq_getElem_cons (show it.start.val < v.val.length by omega),
          List.drop_eq_getElem_cons (show it.start.val < x0.val.length by omega)] at hd
        exact (List.cons.inj hd).2
      · rw [hst, hsv, take_set_succ' _ _ _ (by omega), wordsNat_append, wordsNat_cons, wordsNat_nil,
          List.length_take, Nat.min_eq_left (by omega), cast_u64_val, hc1v,
          wordsNat_take_succ' _ _ (by omega), wordsNat_take_succ' _ _ (by omega)]
        have := mac_step (X := wordsNat (v.val.take it.start.val)) hv (ht.trans (by rw [hyi, hxi0]))
        rw [← getElem!_pos] at this
        exact ⟨by simpa using this, by omega⟩
  · exact ⟨hend, hi, hxl, hc, hdrop, hinv⟩

/-- `mul_add`: `x + u·y` over `x`'s limbs, the carry out of the top returned. -/
@[step]
theorem mul_add_spec (x y : Slice U64) (u : U64) (hy : y.length = x.length) :
    low.generic.limb64.mont.mul_add x y u ⦃ r =>
      r.2.length = x.length ∧ r.1.val < 2 ^ 64 ∧
      wordsNat r.2.val + 2 ^ (64 * x.length) * r.1.val = wordsNat x.val + u.val * wordsNat y.val ⦄ := by
  unfold low.generic.limb64.mont.mul_add
  step as ⟨y1, hy1⟩
  have hy1v : y1.val = y.val := by
    rw [hy1]; simp only [Slice.length] at hy; simp [hy]
  have hy1l : y1.length = x.length := by simp [Slice.length, hy1v]; exact hy
  have := mul_add_loop_spec u y1 x hy1l { start := 0#usize, «end» := x.len } x 0#u128 (by simp) (by simp) rfl
    (by simp) rfl (by simp [wordsNat_nil])
  rw [hy1v] at this
  exact this

/-! ## Subtraction with borrow -/

/-- One limb of a subtraction with borrow, as two `overflowing_sub`s. -/
theorem sub_step (xi yi bw diff0 diff1 : Nat) (b1 b2 : Bool) (hxi : xi < 2 ^ 64) (hyi : yi < 2 ^ 64)
    (hbw : bw ≤ 1)
    (h1 : if xi < yi then diff0 + yi = xi + 2 ^ 64 ∧ b1 = true else diff0 = xi - yi ∧ b1 = false)
    (h2 : if diff0 < bw then diff1 + bw = diff0 + 2 ^ 64 ∧ b2 = true else diff1 = diff0 - bw ∧ b2 = false) :
    (xi : Int) - yi - bw = diff1 - 2 ^ 64 * (b1 || b2).toNat := by
  split_ifs at h1 h2 <;> obtain ⟨h1, rfl⟩ := h1 <;> obtain ⟨h2, rfl⟩ := h2 <;> simp <;> omega

theorem from_bool_val (b : Bool) : (core.convert.num.FromU64Bool.from b).val = b.toNat := by
  cases b <;> rfl

/-- The chain's invariant after `i` limbs: the difference of the prefixes is
the limbs written so far, less the borrow out of them. -/
theorem sub_chain_step {X Y D : Int} {bw b : Nat} {xi yi d : Int} (i : Nat)
    (hinv : D - 2 ^ (64 * i) * (bw : Int) = X - Y)
    (hstep : xi - yi - bw = d - 2 ^ 64 * (b : Int)) :
    D + 2 ^ (64 * i) * d - 2 ^ (64 * (i + 1)) * (b : Int) = (X + 2 ^ (64 * i) * xi) - (Y + 2 ^ (64 * i) * yi) := by
  rw [show 64 * (i + 1) = 64 * i + 64 by ring, pow_add]
  linear_combination hinv - (2 ^ (64 * i) : Int) * hstep

theorem cmp_lt_limbs_loop_spec (x y : Slice U64) (hy : y.length = x.length)
    (iter : core.ops.range.Range Usize) (borrow : U64)
    (hend : iter.end.val = x.length) (hi : iter.start.val ≤ x.length) (hb : borrow.val ≤ 1)
    (hinv : ∃ D : Nat, D < 2 ^ (64 * iter.start.val) ∧
      (D : Int) - 2 ^ (64 * iter.start.val) * borrow.val =
        wordsNat (x.val.take iter.start.val) - wordsNat (y.val.take iter.start.val)) :
    low.generic.limb64.mont.cmp_lt_limbs_loop iter x y borrow ⦃ r =>
      r.val = if wordsNat x.val < wordsNat y.val then 1 else 0 ⦄ := by
  unfold low.generic.limb64.mont.cmp_lt_limbs_loop
  apply loop.spec_decr_nat (fun x' => x.length - x'.1.start.val)
    (fun x' : core.ops.range.Range Usize × U64 =>
      x'.1.end.val = x.length ∧ x'.1.start.val ≤ x.length ∧ x'.2.val ≤ 1 ∧
      ∃ D : Nat, D < 2 ^ (64 * x'.1.start.val) ∧
        (D : Int) - 2 ^ (64 * x'.1.start.val) * x'.2.val =
          wordsNat (x.val.take x'.1.start.val) - wordsNat (y.val.take x'.1.start.val))
  · rintro ⟨it, bw⟩ ⟨he, hs, hb, D, hD, hv⟩
    simp only at he hs hb hD hv
    unfold low.generic.limb64.mont.cmp_lt_limbs_loop.body
    step as ⟨op, iter1, hop, hend1⟩
    cases op with
    | none =>
      have h0 : it.start.val = x.length := by
        split at hop
        · simp at hop
        · scalar_tac
      simp only [WP.spec_ok]
      rw [h0] at hv hD
      have hxl : x.val.length = x.length := rfl
      have hyl : y.val.length = x.length := hy
      rw [List.take_of_length_le (by omega), List.take_of_length_le (by omega)] at hv
      have hD' : (D : Int) < 2 ^ (64 * x.length) := by exact_mod_cast hD
      have hb' : bw.val = 0 ∨ bw.val = 1 := by omega
      rcases hb' with h | h <;> rw [h] at hv ⊢ <;> split_ifs with hlt <;> first | rfl | (exfalso; push_cast at hv; omega)
    | some j =>
      have hlt : it.start.val < it.end.val := by
        by_contra hc; simp [hc] at hop
      simp only [hlt, ↓reduceIte, Option.some.injEq] at hop
      obtain ⟨rfl, hst⟩ := hop
      rw [he] at hlt
      have hxL : x.length = x.val.length := rfl
      have hyL : y.length = y.val.length := rfl
      step as ⟨xi, hxi⟩
      step as ⟨yi, hyi⟩
      step as ⟨diff, b1, hd1⟩
      step as ⟨diff1, b2, hd2⟩
      simp only [lift, bind_ok, WP.spec_ok]
      have hstep := sub_step xi.val yi.val bw.val diff.val diff1.val b1 b2 xi.hBounds yi.hBounds hb
        (by simpa [u64_size] using hd1) (by simpa [u64_size] using hd2)
      rw [← from_bool_val] at hstep
      have hc := sub_chain_step it.start.val hv hstep
      refine ⟨by rw [hend1, he], by omega, by rw [from_bool_val]; cases (b1 || b2) <;> simp,
        ⟨D + 2 ^ (64 * it.start.val) * diff1.val, ?_, ?_⟩, by omega⟩
      · rw [hst, show 64 * (it.start.val + 1) = 64 * it.start.val + 64 by ring, pow_add]
        have := diff1.hBounds
        simp only [UScalarTy.numBits] at this
        nlinarith
      · rw [hst, wordsNat_take_succ' _ _ (by omega), wordsNat_take_succ' _ _ (by omega)]
        rw [hxi, hyi, ← getElem!_pos, ← getElem!_pos] at hc
        push_cast
        linarith
  · exact ⟨hend, hi, hb, hinv⟩

@[step]
theorem cmp_lt_limbs_spec (x y : Slice U64) (hy : y.length = x.length) :
    low.generic.limb64.mont.cmp_lt_limbs x y ⦃ r =>
      r.val = if wordsNat x.val < wordsNat y.val then 1 else 0 ⦄ := by
  unfold low.generic.limb64.mont.cmp_lt_limbs
  step as ⟨y1, hy1⟩
  have hy1v : y1.val = y.val := by
    rw [hy1]; simp only [Slice.length] at hy; simp [hy]
  have := cmp_lt_limbs_loop_spec x y1 (by simp [Slice.length, hy1v]; exact hy)
    { start := 0#usize, «end» := x.len } 0#u64 (by simp) (by simp) (by simp)
    ⟨0, by simp, by simp [wordsNat_nil]⟩
  rw [hy1v] at this
  exact this

/-! ## `sub_limbs_masked` -/

/-- A mask of all ones or zero. -/
def IsMask (keep : U64) : Prop := keep.val = 0 ∨ keep.val = 2 ^ 64 - 1

theorem and_mask_val (a keep : U64) (h : IsMask keep) :
    (a &&& keep).val = if keep.val = 0 then 0 else a.val := by
  rw [UScalar.val_and]
  rcases h with h | h
  · rw [h]; simp
  · rw [h, ite_eq_right (by norm_num), Nat.and_two_pow_sub_one_eq_mod]
    exact Nat.mod_eq_of_lt (by have := a.hBounds; simpa using this)

/-- What a masked subtraction takes away: `y`, or nothing. -/
def masked (keep : U64) (y : Nat) : Nat := if keep.val = 0 then 0 else y

theorem masked_take_succ (keep : U64) (l : List U64) (i : Nat) (hi : i < l.length) :
    masked keep (wordsNat (l.take (i + 1))) =
      masked keep (wordsNat (l.take i)) + 2 ^ (64 * i) * (if keep.val = 0 then 0 else l[i]!.val) := by
  unfold masked; split <;> simp [wordsNat_take_succ' _ _ hi]

theorem sub_limbs_masked_loop_spec (x0 y : Slice U64) (keep : U64) (hk : IsMask keep)
    (hy : y.length = x0.length) (iter : core.ops.range.Range Usize) (x : Slice U64) (borrow : U64)
    (hend : iter.end.val = x0.length) (hi : iter.start.val ≤ x0.length) (hxl : x.length = x0.length)
    (hb : borrow.val ≤ 1) (hdrop : x.val.drop iter.start.val = x0.val.drop iter.start.val)
    (hinv : (wordsNat (x.val.take iter.start.val) : Int) - 2 ^ (64 * iter.start.val) * borrow.val =
      wordsNat (x0.val.take iter.start.val) - masked keep (wordsNat (y.val.take iter.start.val))) :
    low.generic.limb64.mont.sub_limbs_masked_loop iter x keep y borrow ⦃ r =>
      r.length = x0.length ∧ ∃ b : Nat, b ≤ 1 ∧
        (wordsNat r.val : Int) - 2 ^ (64 * x0.length) * b = wordsNat x0.val - masked keep (wordsNat y.val) ⦄ := by
  unfold low.generic.limb64.mont.sub_limbs_masked_loop
  apply loop.spec_decr_nat (fun x' => x0.length - x'.1.start.val)
    (fun x' : core.ops.range.Range Usize × Slice U64 × U64 =>
      x'.1.end.val = x0.length ∧ x'.1.start.val ≤ x0.length ∧ x'.2.1.length = x0.length ∧
      x'.2.2.val ≤ 1 ∧ x'.2.1.val.drop x'.1.start.val = x0.val.drop x'.1.start.val ∧
      (wordsNat (x'.2.1.val.take x'.1.start.val) : Int) - 2 ^ (64 * x'.1.start.val) * x'.2.2.val =
        wordsNat (x0.val.take x'.1.start.val) - masked keep (wordsNat (y.val.take x'.1.start.val)))
  · rintro ⟨it, v, bw⟩ ⟨he, hs, hvl, hb, hd, hv⟩
    simp only at he hs hvl hb hd hv
    unfold low.generic.limb64.mont.sub_limbs_masked_loop.body
    step as ⟨op, iter1, hop, hend1⟩
    cases op with
    | none =>
      have h0 : it.start.val = x0.length := by
        split at hop
        · simp at hop
        · scalar_tac
      simp only [WP.spec_ok]
      rw [h0] at hv
      have hvl' : v.val.length = x0.length := hvl
      have hyl : y.val.length = x0.length := hy
      have hx0l : x0.val.length = x0.length := rfl
      rw [List.take_of_length_le (by omega), List.take_of_length_le (by omega),
        List.take_of_length_le (by omega)] at hv
      exact ⟨hvl, bw.val, hb, hv⟩
    | some j =>
      have hlt : it.start.val < it.end.val := by
        by_contra hc; simp [hc] at hop
      simp only [hlt, ↓reduceIte, Option.some.injEq] at hop
      obtain ⟨rfl, hst⟩ := hop
      rw [he] at hlt
      have hvL : v.length = v.val.length := rfl
      have hyL : y.length = y.val.length := rfl
      have hx0L : x0.length = x0.val.length := rfl
      step as ⟨xi, hxi⟩
      step as ⟨yi, hyi⟩
      step as ⟨ym, hym⟩
      step as ⟨diff, b1, hd1⟩
      step as ⟨diff1, b2, hd2⟩
      step as ⟨s, hs⟩
      simp only [lift, bind_ok, WP.spec_ok]
      have hymv : ym.val = if keep.val = 0 then 0 else yi.val := by rw [hym]; exact and_mask_val yi keep hk
      have hstep := sub_step xi.val ym.val bw.val diff.val diff1.val b1 b2 xi.hBounds ym.hBounds hb
        (by simpa [u64_size] using hd1) (by simpa [u64_size] using hd2)
      rw [← from_bool_val] at hstep
      have hc := sub_chain_step it.start.val hv hstep
      have hxi0 : xi = x0.val[it.start.val]! := by
        rw [hxi, ← getElem!_pos]; exact getElem!_of_drop_eq hd
      have hsv : s.val = v.val.set it.start.val diff1 := by rw [hs]; simp
      refine ⟨by rw [hend1, he], by omega, by rw [hs]; simp at hvl ⊢; omega,
        by rw [from_bool_val]; cases (b1 || b2) <;> simp, ?_, ?_, by omega⟩
      · rw [hst, hsv, drop_set_succ']
        rw [List.drop_eq_getElem_cons (show it.start.val < v.val.length by omega),
          List.drop_eq_getElem_cons (show it.start.val < x0.val.length by omega)] at hd
        exact (List.cons.inj hd).2
      · rw [hst, hsv, take_set_succ' _ _ _ (by omega), wordsNat_append, wordsNat_cons, wordsNat_nil,
          List.length_take, Nat.min_eq_left (by omega), wordsNat_take_succ' _ _ (by omega),
          masked_take_succ _ _ _ (by omega)]
        rw [hymv, hxi0, hyi, ← getElem!_pos] at hc
        push_cast
        split_ifs at hc ⊢ <;> push_cast at hc ⊢ <;> linarith
  · exact ⟨hend, hi, hxl, hb, hdrop, hinv⟩

/-- `sub_limbs_masked`: `x - y` where `keep` is all ones, and `x` where it is
zero, modulo `2^(64n)`. -/
@[step]
theorem sub_limbs_masked_spec (x y : Slice U64) (keep : U64) (hk : IsMask keep) (hy : y.length = x.length) :
    low.generic.limb64.mont.sub_limbs_masked x y keep ⦃ r =>
      r.length = x.length ∧ ∃ b : Nat, b ≤ 1 ∧
        (wordsNat r.val : Int) - 2 ^ (64 * x.length) * b = wordsNat x.val - masked keep (wordsNat y.val) ⦄ := by
  unfold low.generic.limb64.mont.sub_limbs_masked
  step as ⟨y1, hy1⟩
  have hy1v : y1.val = y.val := by
    rw [hy1]; simp only [Slice.length] at hy; simp [hy]
  have := sub_limbs_masked_loop_spec x y1 keep hk (by simp [Slice.length, hy1v]; exact hy)
    { start := 0#usize, «end» := x.len } x 0#u64 (by simp) (by simp) rfl (by simp) rfl
    (by simp [wordsNat_nil, masked])
  rw [hy1v] at this
  exact this

/-- A masked subtraction whose difference is not negative leaves it, and no
borrow. -/
theorem masked_sub_exact {r X S n : Nat} {b : Nat} (hb : b ≤ 1) (hr : r < 2 ^ n) (hS : S ≤ X)
    (h : (r : Int) - 2 ^ n * b = X - S) : r = X - S := by
  rcases (show b = 0 ∨ b = 1 by omega) with rfl | rfl
  · push_cast at h; omega
  · exfalso
    have : (2 : Int) ^ n = ((2 ^ n : Nat) : Int) := by push_cast; rfl
    push_cast at h; omega

/-! ## `add_shift`, CIOS's reduction step -/

/-- One limb of `add_shift`: the low half of `s = u·m_j + t_j + c` lands a
limb down, at `j - 1`, and the high half carries. -/
theorem shift_step {W T M c s j tj mj u L : Nat} (hj : 1 ≤ j)
    (hinv : 2 ^ 64 * W + 2 ^ (64 * j) * c + L = T + u * M) (hs : s = u * mj + tj + c) :
    2 ^ 64 * (W + 2 ^ (64 * (j - 1)) * (s % 2 ^ 64)) + 2 ^ (64 * (j + 1)) * (s / 2 ^ 64) + L =
      T + 2 ^ (64 * j) * tj + u * (M + 2 ^ (64 * j) * mj) := by
  obtain ⟨k, rfl⟩ : ∃ k, j = k + 1 := ⟨j - 1, by omega⟩
  have h := Nat.mod_add_div s (2 ^ 64)
  simp only [Nat.add_sub_cancel] at *
  rw [show 64 * (k + 1 + 1) = 64 * k + 64 + 64 by ring, show 64 * (k + 1) = 64 * k + 64 by ring,
    pow_add, pow_add] at *
  zify at *
  linear_combination hinv + (2 ^ (64 * k) * 2 ^ 64 : Int) * h + (2 ^ (64 * k) * 2 ^ 64 : Int) * hs

theorem add_shift_loop_spec (t0 m : Slice U64) (u : U64) (low0 : Nat) (hm : m.length ≤ t0.length)
    (iter : core.ops.range.Range Usize) (t : Slice U64) (carry : U64)
    (hend : iter.end.val = m.length) (h1 : 1 ≤ iter.start.val) (hi : iter.start.val ≤ m.length)
    (htl : t.length = t0.length) (hdrop : t.val.drop iter.start.val = t0.val.drop iter.start.val)
    (hinv : 2 ^ 64 * wordsNat (t.val.take (iter.start.val - 1)) + 2 ^ (64 * iter.start.val) * carry.val + low0 =
      wordsNat (t0.val.take iter.start.val) + u.val * wordsNat (m.val.take iter.start.val)) :
    low.generic.limb64.mont.add_shift_loop iter t m u carry ⦃ r =>
      r.1.length = t0.length ∧ r.1.val.drop m.length = t0.val.drop m.length ∧
      2 ^ 64 * wordsNat (r.1.val.take (m.length - 1)) + 2 ^ (64 * m.length) * r.2.val + low0 =
        wordsNat (t0.val.take m.length) + u.val * wordsNat m.val ⦄ := by
  unfold low.generic.limb64.mont.add_shift_loop
  apply loop.spec_decr_nat (fun x' => m.length - x'.1.start.val)
    (fun x' : core.ops.range.Range Usize × Slice U64 × U64 =>
      x'.1.end.val = m.length ∧ 1 ≤ x'.1.start.val ∧ x'.1.start.val ≤ m.length ∧
      x'.2.1.length = t0.length ∧ x'.2.1.val.drop x'.1.start.val = t0.val.drop x'.1.start.val ∧
      2 ^ 64 * wordsNat (x'.2.1.val.take (x'.1.start.val - 1)) + 2 ^ (64 * x'.1.start.val) * x'.2.2.val + low0 =
        wordsNat (t0.val.take x'.1.start.val) + u.val * wordsNat (m.val.take x'.1.start.val))
  · rintro ⟨it, v, c⟩ ⟨he, h1, hs, hvl, hd, hv⟩
    simp only at he h1 hs hvl hd hv
    unfold low.generic.limb64.mont.add_shift_loop.body
    step as ⟨op, iter1, hop, hend1⟩
    cases op with
    | none =>
      have h0 : it.start.val = m.length := by
        split at hop
        · simp at hop
        · scalar_tac
      simp only [WP.spec_ok]
      rw [h0] at hv hd
      have hml : m.val.length = m.length := rfl
      rw [List.take_of_length_le (l := m.val) (by omega)] at hv
      exact ⟨hvl, hd, hv⟩
    | some j =>
      have hlt : it.start.val < it.end.val := by
        by_contra hc; simp [hc] at hop
      simp only [hlt, ↓reduceIte, Option.some.injEq] at hop
      obtain ⟨rfl, hst⟩ := hop
      rw [he] at hlt
      have hvL : v.length = v.val.length := rfl
      have hmL : m.length = m.val.length := rfl
      have ht0L : t0.length = t0.val.length := rfl
      step as ⟨mi, hmi⟩
      step as ⟨ti, hti⟩
      step as ⟨cw, hcw⟩
      step with mul_add_limb_spec u mi ti cw (by rw [hcw]; exact c.hBounds) as ⟨s, hsv⟩
      step as ⟨k, hk⟩
      step as ⟨w, hw⟩
      step as ⟨v1, hv1⟩
      step as ⟨sh, hsh, _⟩
      step as ⟨c1, hc1⟩
      have hsb : s.val < 2 ^ 128 := by
        rw [hsv]; exact mul_add_limb_bound _ _ _ _ u.hBounds mi.hBounds ti.hBounds
          (by rw [hcw]; exact c.hBounds)
      have hti0 : ti = t0.val[it.start.val]! := by
        rw [hti, ← getElem!_pos]; exact getElem!_of_drop_eq hd
      have hkv : k.val = it.start.val - 1 := by scalar_tac
      have hv1v : v1.val = v.val.set (it.start.val - 1) (UScalar.cast .U64 s) := by rw [hv1, hw, ← hkv]; simp
      have hshv : sh.val = s.val / 2 ^ 64 := by rw [hsh]; simp [Nat.shiftRight_eq_div_pow]
      refine ⟨by rw [hend1, he], by omega, by omega, by rw [hv1]; simp at hvl ⊢; omega, ?_, ?_, by omega⟩
      · rw [hst, hv1v, drop_set_lt _ _ _ _ (by omega)]
        rw [List.drop_eq_getElem_cons (show it.start.val < v.val.length by omega),
          List.drop_eq_getElem_cons (show it.start.val < t0.val.length by omega)] at hd
        exact (List.cons.inj hd).2
      · rw [hst, hv1v, show it.start.val + 1 - 1 = (it.start.val - 1) + 1 by omega,
          take_set_succ' _ _ _ (by omega), wordsNat_append, wordsNat_cons, wordsNat_nil,
          List.length_take, Nat.min_eq_left (by omega), cast_u64_val,
          wordsNat_take_succ' _ _ (by omega), wordsNat_take_succ' (l := m.val) _ (by omega)]
        have hcv : c1.val = s.val / 2 ^ 64 := by
          rw [hc1, cast_u64_val, hshv, Nat.mod_eq_of_lt (by omega)]
        rw [hcv]
        have := shift_step (by omega : 1 ≤ it.start.val) hv
          (hsv.trans (by rw [hcw, hmi, hti0, ← getElem!_pos]))
        exact this
  · exact ⟨hend, h1, hi, htl, hdrop, hinv⟩

/-! ## `mul_add2` -/

/-- `mul_add2`'s block of limbs. -/
abbrev Block := Std.Array U64 4#usize

theorem four_val : (4#usize).val = 4 := by simp

theorem block_eq : low.generic.limb64.mont.BLOCK = 4#usize := by
  unfold low.generic.limb64.mont.BLOCK
  simp [core.num.U64.BITS]

/-- `foldlM` of a step that appends one value a call, leaving its state. -/
theorem foldlM_append_spec {α β S : Type} (φ : List β × S → α → Result (List β × S)) (s : S)
    (P : α → β → Prop) (hφ : ∀ acc a, φ (acc, s) a ⦃ r => ∃ y, r = (acc ++ [y], s) ∧ P a y ⦄)
    (l : List α) (acc : List β) :
    l.foldlM φ (acc, s) ⦃ r => ∃ ys, r = (acc ++ ys, s) ∧ List.Forall₂ P l ys ⦄ := by
  induction l generalizing acc with
  | nil => exact (WP.spec_ok (acc, s)).mpr ⟨[], by simp, List.Forall₂.nil⟩
  | cons a l ih =>
    rw [List.foldlM_cons]
    apply WP.spec_bind (hφ acc a)
    rintro r ⟨y, rfl, hy⟩
    apply WP.spec_mono (ih (acc ++ [y]))
    rintro r ⟨ys, rfl, hys⟩
    exact ⟨y :: ys, by simp, List.Forall₂.cons hy hys⟩

/-- `core::array::from_fn` of a closure that leaves its state: element `k`
is what the closure returns for `k`. -/
theorem from_fn_spec {T F : Type} [Inhabited T] (N : Usize) (n : Nat) (hn : N.val = n)
    (inst : core.ops.function.FnMut F Usize T) (f : F) (P : Nat → T → Prop)
    (hcall : ∀ i : Usize, i.val < n → inst.call_mut f i ⦃ r => r.2 = f ∧ P i.val r.1 ⦄) :
    core.array.from_fn N inst f ⦃ a => ∀ k < n, P k a.val[k]! ⦄ := by
  subst hn
  unfold core.array.from_fn
  apply WP.spec_bind (foldlM_append_spec _ f (fun a y => P a.val y) ?_ _ [])
  · rintro r ⟨ys, rfl, hys⟩
    obtain ⟨hl, hget⟩ := List.forall₂_iff_get.mp hys
    simp only [List.length_attach, List.length_range] at hl
    change (if h : ys.length = N.val then ok (Std.Array.from ys h) else fail .panic) ⦃ a => ∀ k < N.val, P k a.val[k]! ⦄
    rw [dif_pos hl.symm, WP.spec_ok]
    intro k hk
    have := hget k (by simp; omega) (by omega)
    simpa [getElem!_pos ys k (by omega)] using this
  · rintro acc ⟨i, hi⟩
    have hiN : i < N.val := List.mem_range.mp hi
    dsimp only
    apply WP.spec_bind (hcall _ (by simpa using hiN))
    rintro ⟨y, f'⟩ ⟨hf, hy⟩
    subst hf
    refine (WP.spec_ok _).mpr ⟨y, rfl, ?_⟩
    simpa using hy

theorem closure_spec (u : U64) (y : Std.Array U64 4#usize) (i : Usize) (hi : i.val < 4) :
    low.generic.limb64.mont.mul_add2.closure.Insts.CoreOpsFunctionFnMutTupleUsizeU128.call_mut (u, y) i
      ⦃ r => r.2 = (u, y) ∧ r.1.val = u.val * y.val[i.val]!.val ⦄ := by
  unfold low.generic.limb64.mont.mul_add2.closure.Insts.CoreOpsFunctionFnMutTupleUsizeU128.call_mut
  simp only [lift, bind_ok]
  step with Array.index_usize_spec y i (by simpa using hi) as ⟨yi, hyi⟩
  have hb : u.val * yi.val < 2 ^ 128 := by
    have := mul_add_limb_bound u.val yi.val 0 0 u.hBounds yi.hBounds (by norm_num) (by norm_num); omega
  simp only [lift, bind_ok, WP.spec_ok, core.num.U128.wrapping_mul_val_eq, from_u128_val, UScalar.size,
    UScalarTy.numBits]
  refine ⟨rfl, ?_⟩
  rw [Nat.mod_eq_of_lt hb, hyi, getElem!_pos _ _ (by simpa using hi)]

/-- The multiple of `v` that limb `k` of `mul_add2`'s second chain adds:
the limb of `y` below `k`, or `prev` at the bottom. -/
def prevAt (prev : U64) (y : List U64) (k : Nat) : Nat := if k = 0 then prev.val else y[k - 1]!.val

theorem closure1_spec (prev : U64) (y : Std.Array U64 4#usize) (v : U64) (i : Usize) (hi : i.val < 4) :
    low.generic.limb64.mont.mul_add2.closure_1.Insts.CoreOpsFunctionFnMutTupleUsizeU128.call_mut
      (prev, y, v) i ⦃ r => r.2 = (prev, y, v) ∧ r.1.val = v.val * prevAt prev y.val i.val ⦄ := by
  have hcall : low.generic.limb64.mont.mul_add2.closure_1.Insts.CoreOpsFunctionFnMutTupleUsizeU128.call_mut
      (prev, y, v) i = (do
        let below1 ← if i = 0#usize then ok prev else do
          let i1 ← i - 1#usize
          Array.index_usize y i1
        let i1 ← lift (core.convert.num.FromU128U64.from v)
        let i2 ← lift (core.convert.num.FromU128U64.from below1)
        let i3 ← lift (core.num.U128.wrapping_mul i1 i2)
        ok (i3, ((prev, y, v) : low.generic.limb64.mont.mul_add2.closure_1))) := rfl
  rw [hcall]
  have key : ∀ b : U64, b.val = prevAt prev y.val i.val →
      (do
        let i1 ← lift (core.convert.num.FromU128U64.from v)
        let i2 ← lift (core.convert.num.FromU128U64.from b)
        let i3 ← lift (core.num.U128.wrapping_mul i1 i2)
        ok (i3, ((prev, y, v) : low.generic.limb64.mont.mul_add2.closure_1)))
        ⦃ r => r.2 = (prev, y, v) ∧ r.1.val = v.val * prevAt prev y.val i.val ⦄ := by
    intro b hb
    have hbb : v.val * b.val < 2 ^ 128 := by
      have := mul_add_limb_bound v.val b.val 0 0 v.hBounds b.hBounds (by norm_num) (by norm_num); omega
    simp only [lift, bind_ok, WP.spec_ok, core.num.U128.wrapping_mul_val_eq, from_u128_val, UScalar.size,
      UScalarTy.numBits, true_and]
    rw [Nat.mod_eq_of_lt hbb, hb]
  split
  · rename_i h0
    simp only [bind_ok]
    exact key prev (by simp [prevAt, h0])
  · rename_i h0
    have h0' : i.val ≠ 0 := by intro h; apply h0; scalar_tac
    step as ⟨j, hj⟩
    step with Array.index_usize_spec y j (by simp; omega) as ⟨b, hb⟩
    exact key b (by rw [hb, ← getElem!_pos]; simp [prevAt, h0', hj])

/-- The products of `u` and a block's limbs. -/
theorem pu_spec (u : U64) (y : Std.Array U64 4#usize) :
    core.array.from_fn 4#usize
      low.generic.limb64.mont.mul_add2.closure.Insts.CoreOpsFunctionFnMutTupleUsizeU128
      ((u, y) : low.generic.limb64.mont.mul_add2.closure)
      ⦃ a => ∀ k < 4, a.val[k]!.val = u.val * y.val[k]!.val ⦄ := by
  exact from_fn_spec 4#usize 4 four_val
    low.generic.limb64.mont.mul_add2.closure.Insts.CoreOpsFunctionFnMutTupleUsizeU128 (u, y)
    (fun k r => r.val = u.val * y.val[k]!.val)
    (fun i hi => closure_spec u y i hi)

/-- The products of `v` and the limbs a block's second chain adds. -/
theorem pv_spec (prev : U64) (y : Std.Array U64 4#usize) (v : U64) :
    core.array.from_fn 4#usize
      low.generic.limb64.mont.mul_add2.closure_1.Insts.CoreOpsFunctionFnMutTupleUsizeU128
      ((prev, y, v) : low.generic.limb64.mont.mul_add2.closure_1)
      ⦃ a => ∀ k < 4, a.val[k]!.val = v.val * prevAt prev y.val k ⦄ := by
  exact from_fn_spec 4#usize 4 four_val
    low.generic.limb64.mont.mul_add2.closure_1.Insts.CoreOpsFunctionFnMutTupleUsizeU128 (prev, y, v)
    (fun k r => r.val = v.val * prevAt prev y.val k)
    (fun i hi => closure1_spec prev y v i hi)

/-- One limb of `mul_add2`: the first chain's sum `s0 = u·y_j + x_j + c0`
passes its low half to the second's, `s1 = v·prev + s0 mod 2^64 + c1`,
whose low half lands at limb `j`. -/
theorem mac2_step {X X0 Y C c0 c1 s0 s1 j xj yj u v P : Nat}
    (hinv : X + 2 ^ (64 * j) * (c0 + c1 + v * P) = X0 + (u + 2 ^ 64 * v) * Y + C)
    (hs0 : s0 = u * yj + xj + c0) (hs1 : s1 = v * P + s0 % 2 ^ 64 + c1) :
    X + 2 ^ (64 * j) * (s1 % 2 ^ 64) + 2 ^ (64 * (j + 1)) * (s0 / 2 ^ 64 + s1 / 2 ^ 64 + v * yj) =
      X0 + 2 ^ (64 * j) * xj + (u + 2 ^ 64 * v) * (Y + 2 ^ (64 * j) * yj) + C := by
  have h0 := Nat.mod_add_div s0 (2 ^ 64)
  have h1 := Nat.mod_add_div s1 (2 ^ 64)
  rw [show 64 * (j + 1) = 64 * j + 64 by ring, pow_add]
  zify at *
  linear_combination hinv + (2 ^ (64 * j) : Int) * (h1 + h0 + hs1 + hs0)

theorem mul_add2_block_loop_spec (u v prev : U64) (y x0 : Std.Array U64 4#usize) (pu pv : Std.Array U128 4#usize)
    (hpu : ∀ k < 4, pu.val[k]!.val = u.val * y.val[k]!.val)
    (hpv : ∀ k < 4, pv.val[k]!.val = v.val * prevAt prev y.val k) (C : Nat)
    (iter : core.ops.range.Range Usize) (c0 c1 : U128) (x : Std.Array U64 4#usize)
    (hend : iter.end.val = 4) (hi : iter.start.val ≤ 4) (hc0 : c0.val < 2 ^ 64) (hc1 : c1.val < 2 ^ 64)
    (hdrop : x.val.drop iter.start.val = x0.val.drop iter.start.val)
    (hinv : wordsNat (x.val.take iter.start.val) +
        2 ^ (64 * iter.start.val) * (c0.val + c1.val + v.val * prevAt prev y.val iter.start.val) =
      wordsNat (x0.val.take iter.start.val) + (u.val + 2 ^ 64 * v.val) * wordsNat (y.val.take iter.start.val) + C) :
    low.generic.limb64.mont.mul_add2_loop0_loop0 iter c0 c1 x pu pv ⦃ r =>
      r.1.val < 2 ^ 64 ∧ r.2.1.val < 2 ^ 64 ∧
      wordsNat r.2.2.val + 2 ^ 256 * (r.1.val + r.2.1.val + v.val * prevAt prev y.val 4) =
        wordsNat x0.val + (u.val + 2 ^ 64 * v.val) * wordsNat y.val + C ⦄ := by
  unfold low.generic.limb64.mont.mul_add2_loop0_loop0
  apply loop.spec_decr_nat (fun x' => 4 - x'.1.start.val)
    (fun x' : core.ops.range.Range Usize × U128 × U128 × Std.Array U64 4#usize =>
      x'.1.end.val = 4 ∧ x'.1.start.val ≤ 4 ∧ x'.2.1.val < 2 ^ 64 ∧ x'.2.2.1.val < 2 ^ 64 ∧
      x'.2.2.2.val.drop x'.1.start.val = x0.val.drop x'.1.start.val ∧
      wordsNat (x'.2.2.2.val.take x'.1.start.val) +
          2 ^ (64 * x'.1.start.val) * (x'.2.1.val + x'.2.2.1.val + v.val * prevAt prev y.val x'.1.start.val) =
        wordsNat (x0.val.take x'.1.start.val) +
          (u.val + 2 ^ 64 * v.val) * wordsNat (y.val.take x'.1.start.val) + C)
  · rintro ⟨it, a, b, w⟩ ⟨he, hs, ha, hb, hd, hv⟩
    simp only at he hs ha hb hd hv
    unfold low.generic.limb64.mont.mul_add2_loop0_loop0.body
    step as ⟨op, iter1, hop, hend1⟩
    cases op with
    | none =>
      have h0 : it.start.val = 4 := by
        split at hop
        · simp at hop
        · scalar_tac
      simp only [WP.spec_ok]
      rw [h0] at hv
      have hwl : w.val.length = 4 := by simp
      have hyl : y.val.length = 4 := by simp
      have hx0l : x0.val.length = 4 := by simp
      rw [List.take_of_length_le (by omega), List.take_of_length_le (by omega),
        List.take_of_length_le (by omega)] at hv
      exact ⟨ha, hb, hv⟩
    | some k =>
      have hlt : it.start.val < it.end.val := by
        by_contra hc; simp [hc] at hop
      simp only [hlt, ↓reduceIte, Option.some.injEq] at hop
      obtain ⟨rfl, hst⟩ := hop
      rw [he] at hlt
      have hwl : w.val.length = 4 := by simp
      have hyl : y.val.length = 4 := by simp
      have hx0l : x0.val.length = 4 := by simp
      step with Array.index_usize_spec pu it.start (by simp; omega) as ⟨pk, hpk⟩
      step with Array.index_usize_spec w it.start (by simp; omega) as ⟨xk, hxk⟩
      have hpkv : pk.val = u.val * y.val[it.start.val]!.val := by rw [hpk, ← getElem!_pos]; exact hpu _ hlt
      have hxk0 : xk = x0.val[it.start.val]! := by rw [hxk, ← getElem!_pos]; exact getElem!_of_drop_eq hd
      have hpkb : pk.val ≤ (2 ^ 64 - 1) * (2 ^ 64 - 1) := by
        rw [hpkv]; exact Nat.mul_le_mul (u64_le _) (u64_le _)
      have hs0b : pk.val + xk.val + a.val < 2 ^ 128 := by have := u64_lt xk; omega
      simp only [lift, bind_ok]
      step as ⟨c0', hc0', _⟩
      step with Array.index_usize_spec pv it.start (by simp; omega) as ⟨qk, hqk⟩
      have hqkv : qk.val = v.val * prevAt prev y.val it.start.val := by
        rw [hqk, ← getElem!_pos]; exact hpv _ hlt
      have hqkb : qk.val ≤ (2 ^ 64 - 1) * (2 ^ 64 - 1) := by
        rw [hqkv]; refine Nat.mul_le_mul (u64_le _) ?_
        unfold prevAt; split <;> exact u64_le _
      step with Array.update_spec w it.start _ (by simp; omega) as ⟨w1, hw1⟩
      step as ⟨c1', hc1', _⟩
      set s0 := core.num.U128.wrapping_add (core.num.U128.wrapping_add pk (core.convert.num.FromU128U64.from xk)) a
        with hs0def
      set s1 := core.num.U128.wrapping_add (core.num.U128.wrapping_add qk
        (core.convert.num.FromU128U64.from (UScalar.cast UScalarTy.U64 s0))) b with hs1def
      have hs0v : s0.val = pk.val + xk.val + a.val := by
        rw [hs0def]
        simp only [core.num.U128.wrapping_add_val_eq, from_u128_val, UScalar.size, UScalarTy.numBits]
        rw [Nat.mod_eq_of_lt (by omega), Nat.mod_eq_of_lt (by omega)]
      have hs0m : s0.val % 2 ^ 64 < 2 ^ 64 := Nat.mod_lt _ (by norm_num)
      have hs1v : s1.val = qk.val + s0.val % 2 ^ 64 + b.val := by
        rw [hs1def]
        simp only [core.num.U128.wrapping_add_val_eq, from_u128_val, cast_u64_val, UScalar.size,
          UScalarTy.numBits]
        rw [Nat.mod_eq_of_lt (by omega), Nat.mod_eq_of_lt (by omega)]
      have hc0v : c0'.val = s0.val / 2 ^ 64 := by rw [hc0']; simp [Nat.shiftRight_eq_div_pow]
      have hc1v : c1'.val = s1.val / 2 ^ 64 := by rw [hc1']; simp [Nat.shiftRight_eq_div_pow]
      have hw1v : w1.val = w.val.set it.start.val (UScalar.cast .U64 s1) := by rw [hw1]; simp
      refine ⟨by rw [hend1, he], by omega, by rw [hc0v]; omega, by rw [hc1v]; omega, ?_, ?_, by omega⟩
      · rw [hst, hw1v, drop_set_succ']
        rw [List.drop_eq_getElem_cons (show it.start.val < w.val.length by omega),
          List.drop_eq_getElem_cons (show it.start.val < x0.val.length by omega)] at hd
        exact (List.cons.inj hd).2
      · have hP : prevAt prev y.val (it.start.val + 1) = y.val[it.start.val]!.val := by simp [prevAt]
        rw [hst, hw1v, take_set_succ' _ _ _ (by omega), wordsNat_append, wordsNat_cons, wordsNat_nil,
          List.length_take, Nat.min_eq_left (by omega), cast_u64_val, hc0v, hc1v, hP,
          wordsNat_take_succ' _ _ (by omega), wordsNat_take_succ' (l := y.val) _ (by omega), ← hxk0]
        have := mac2_step hv (hs0v.trans (by rw [hpkv])) (hs1v.trans (by rw [hqkv]))
        simpa using this
  · exact ⟨hend, hi, hc0, hc1, hdrop, hinv⟩

/-- `mul_add2`'s blocks, flattened back into limbs. -/
def flat (cs : List Block) : List U64 := cs.flatMap (·.val)

theorem flat_append (a b : List Block) : flat (a ++ b) = flat a ++ flat b :=
  List.flatMap_append ..

theorem flat_singleton (a : Block) : flat [a] = a.val := by simp [flat]

theorem flat_length (cs : List Block) : (flat cs).length = 4 * cs.length := by
  induction cs with
  | nil => simp [flat]
  | cons a cs ih =>
    rw [show a :: cs = [a] ++ cs from rfl, flat_append, List.length_append, ih, flat_singleton]
    simp; ring

theorem wordsNat_flat_take_succ (cs : List Block) (b : Nat) (hb : b < cs.length) :
    wordsNat (flat (cs.take (b + 1))) = wordsNat (flat (cs.take b)) + 2 ^ (64 * (4 * b)) * wordsNat (cs[b]'hb).val := by
  rw [List.take_add_one, List.getElem?_eq_getElem hb, Option.toList_some, flat_append, flat_singleton,
    wordsNat_append, flat_length, List.length_take, Nat.min_eq_left hb.le]

theorem flat_ofFn (s : List U64) (k : Nat) (hk : k * 4 ≤ s.length) (f : Fin k → Block)
    (hf : ∀ i, (f i).val = (s.drop (i.val * 4)).take 4) : flat (List.ofFn f) = s.take (k * 4) := by
  induction k with
  | zero => simp [flat]
  | succ k ih =>
    rw [List.ofFn_succ_last, flat_append, ih (by omega) _ (fun i => hf _), flat_singleton, hf,
      show (k + 1) * 4 = k * 4 + 4 by ring, List.take_add]
    simp

@[step]
theorem as_chunks4_spec (s : Slice U64) :
    core.slice.Slice.as_chunks 4#usize s ⦃ p => p.1.length = s.length / 4 ∧ flat p.1.val ++ p.2.val = s.val ⦄ := by
  unfold core.slice.Slice.as_chunks
  simp only [four_val, OfNat.ofNat_ne_zero, ↓reduceIte, WP.spec_ok]
  refine ⟨by simp [Slice.length], ?_⟩
  simp only [Slice.from_val]
  rw [flat_ofFn s.val _ (by simp [Slice.length]; omega) _ (fun i => by simp [Std.Array.from_val])]
  exact List.take_append_drop _ _

@[step]
theorem as_chunks_mut4_spec (s : Slice U64) :
    core.slice.Slice.as_chunks_mut 4#usize s ⦃ p back =>
      p.1.length = s.length / 4 ∧ flat p.1.val ++ p.2.val = s.val ∧
      ∀ c t, (flat c.val ++ t.val).length ≤ Usize.max → (back (c, t)).val = flat c.val ++ t.val ⦄ := by
  unfold core.slice.Slice.as_chunks_mut
  apply WP.spec_bind (as_chunks4_spec s)
  rintro p ⟨hl, hf⟩
  simp only [WP.spec_ok]
  refine ⟨hl, hf, fun c t hct => ?_⟩
  simp only [flat] at hct ⊢
  rw [dif_pos hct, Slice.from_val]

theorem mul_add2_tail_loop_spec (u v : U64) (y x0 : Slice U64) (hy : y.length = x0.length) (C : Nat)
    (iter : core.ops.range.Range Usize) (c0 c1 : U128) (prev : U64) (x : Slice U64)
    (hend : iter.end.val = x0.length) (hi : iter.start.val ≤ x0.length) (hxl : x.length = x0.length)
    (hc0 : c0.val < 2 ^ 64) (hc1 : c1.val < 2 ^ 64)
    (hdrop : x.val.drop iter.start.val = x0.val.drop iter.start.val)
    (hinv : wordsNat (x.val.take iter.start.val) + 2 ^ (64 * iter.start.val) * (c0.val + c1.val + v.val * prev.val) =
      wordsNat (x0.val.take iter.start.val) + (u.val + 2 ^ 64 * v.val) * wordsNat (y.val.take iter.start.val) + C) :
    low.generic.limb64.mont.mul_add2_loop1 iter u v c0 c1 prev x y ⦃ r =>
      r.2.2.2.length = x0.length ∧ r.1.val < 2 ^ 64 ∧ r.2.1.val < 2 ^ 64 ∧
      wordsNat r.2.2.2.val + 2 ^ (64 * x0.length) * (r.1.val + r.2.1.val + v.val * r.2.2.1.val) =
        wordsNat x0.val + (u.val + 2 ^ 64 * v.val) * wordsNat y.val + C ⦄ := by
  unfold low.generic.limb64.mont.mul_add2_loop1
  apply loop.spec_decr_nat (fun x' => x0.length - x'.1.start.val)
    (fun x' : core.ops.range.Range Usize × U128 × U128 × U64 × Slice U64 =>
      x'.1.end.val = x0.length ∧ x'.1.start.val ≤ x0.length ∧ x'.2.2.2.2.length = x0.length ∧
      x'.2.1.val < 2 ^ 64 ∧ x'.2.2.1.val < 2 ^ 64 ∧
      x'.2.2.2.2.val.drop x'.1.start.val = x0.val.drop x'.1.start.val ∧
      wordsNat (x'.2.2.2.2.val.take x'.1.start.val) +
          2 ^ (64 * x'.1.start.val) * (x'.2.1.val + x'.2.2.1.val + v.val * x'.2.2.2.1.val) =
        wordsNat (x0.val.take x'.1.start.val) + (u.val + 2 ^ 64 * v.val) * wordsNat (y.val.take x'.1.start.val) + C)
  · rintro ⟨it, a, b, p, w⟩ ⟨he, hs, hwl, ha, hb, hd, hv⟩
    simp only at he hs hwl ha hb hd hv
    unfold low.generic.limb64.mont.mul_add2_loop1.body
    step as ⟨op, iter1, hop, hend1⟩
    cases op with
    | none =>
      have h0 : it.start.val = x0.length := by
        split at hop
        · simp at hop
        · scalar_tac
      simp only [WP.spec_ok]
      rw [h0] at hv
      have hwl' : w.val.length = x0.length := hwl
      have hyl : y.val.length = x0.length := hy
      have hx0l : x0.val.length = x0.length := rfl
      rw [List.take_of_length_le (by omega), List.take_of_length_le (by omega),
        List.take_of_length_le (by omega)] at hv
      exact ⟨hwl, ha, hb, hv⟩
    | some j =>
      have hlt : it.start.val < it.end.val := by
        by_contra hc; simp [hc] at hop
      simp only [hlt, ↓reduceIte, Option.some.injEq] at hop
      obtain ⟨rfl, hst⟩ := hop
      rw [he] at hlt
      have hwL : w.length = w.val.length := rfl
      have hyL : y.length = y.val.length := rfl
      have hx0L : x0.length = x0.val.length := rfl
      step as ⟨yi, hyi⟩
      step as ⟨xi, hxi⟩
      step with mul_add_limb_spec u yi xi a ha as ⟨s0, hs0⟩
      step as ⟨c0', hc0', _⟩
      step as ⟨t, ht⟩
      step with mul_add_limb_spec v p t b hb as ⟨s1, hs1⟩
      step as ⟨t1, ht1⟩
      step as ⟨w1, hw1⟩
      step as ⟨c1', hc1', _⟩
      have hxi0 : xi = x0.val[it.start.val]! := by
        rw [hxi, ← getElem!_pos]; exact getElem!_of_drop_eq hd
      have hs0b : s0.val < 2 ^ 128 := by
        rw [hs0]; exact mul_add_limb_bound _ _ _ _ u.hBounds yi.hBounds xi.hBounds ha
      have htv : t.val = s0.val % 2 ^ 64 := by rw [ht, cast_u64_val]
      have hs1b : s1.val < 2 ^ 128 := by
        rw [hs1]; exact mul_add_limb_bound _ _ _ _ v.hBounds p.hBounds t.hBounds hb
      have hc0v : c0'.val = s0.val / 2 ^ 64 := by rw [hc0']; simp [Nat.shiftRight_eq_div_pow]
      have hc1v : c1'.val = s1.val / 2 ^ 64 := by rw [hc1']; simp [Nat.shiftRight_eq_div_pow]
      have hw1v : w1.val = w.val.set it.start.val (UScalar.cast .U64 s1) := by rw [hw1, ht1]; simp
      refine ⟨by rw [hend1, he], by scalar_tac, by rw [hw1]; simp at hwl ⊢; omega,
        by rw [hc0v]; omega, by rw [hc1v]; omega, ?_, ?_, by omega⟩
      · rw [hst, hw1v, drop_set_succ']
        rw [List.drop_eq_getElem_cons (show it.start.val < w.val.length by omega),
          List.drop_eq_getElem_cons (show it.start.val < x0.val.length by omega)] at hd
        exact (List.cons.inj hd).2
      · rw [hst, hw1v, take_set_succ' _ _ _ (by omega), wordsNat_append, wordsNat_cons, wordsNat_nil,
          List.length_take, Nat.min_eq_left (by omega), cast_u64_val, hc0v, hc1v,
          wordsNat_take_succ' _ _ (by omega), wordsNat_take_succ' (l := y.val) _ (by omega), ← hxi0]
        have := mac2_step hv hs0 (hs1.trans (by rw [htv]))
        have hyi' : yi = y.val[it.start.val]! := by rw [hyi, ← getElem!_pos]
        rw [hyi'] at this ⊢
        simpa using this
  · exact ⟨hend, hi, hxl, hc0, hc1, hdrop, hinv⟩

theorem mul_add2_blocks_loop_spec (u v : U64) (ys xs0 : Slice Block)
    (hy : ys.length = xs0.length) (c : Nat)
    (iter : core.ops.range.Range Usize) (c0 c1 : U128) (prev : U64) (xs : Slice Block)
    (hend : iter.end.val = xs0.length) (hi : iter.start.val ≤ xs0.length) (hxl : xs.length = xs0.length)
    (hc0 : c0.val < 2 ^ 64) (hc1 : c1.val < 2 ^ 64)
    (hdrop : xs.val.drop iter.start.val = xs0.val.drop iter.start.val)
    (hinv : wordsNat (flat (xs.val.take iter.start.val)) +
        2 ^ (64 * (4 * iter.start.val)) * (c0.val + c1.val + v.val * prev.val) =
      wordsNat (flat (xs0.val.take iter.start.val)) +
        (u.val + 2 ^ 64 * v.val) * wordsNat (flat (ys.val.take iter.start.val)) + c) :
    low.generic.limb64.mont.mul_add2_loop0 iter u v c0 c1 prev xs ys ⦃ r =>
      r.2.2.2.length = xs0.length ∧ r.1.val < 2 ^ 64 ∧ r.2.1.val < 2 ^ 64 ∧
      wordsNat (flat r.2.2.2.val) + 2 ^ (64 * (4 * xs0.length)) * (r.1.val + r.2.1.val + v.val * r.2.2.1.val) =
        wordsNat (flat xs0.val) + (u.val + 2 ^ 64 * v.val) * wordsNat (flat ys.val) + c ⦄ := by
  unfold low.generic.limb64.mont.mul_add2_loop0
  apply loop.spec_decr_nat (fun x' => xs0.length - x'.1.start.val)
    (fun x' : core.ops.range.Range Usize × U128 × U128 × U64 × Slice Block =>
      x'.1.end.val = xs0.length ∧ x'.1.start.val ≤ xs0.length ∧ x'.2.2.2.2.length = xs0.length ∧
      x'.2.1.val < 2 ^ 64 ∧ x'.2.2.1.val < 2 ^ 64 ∧
      x'.2.2.2.2.val.drop x'.1.start.val = xs0.val.drop x'.1.start.val ∧
      wordsNat (flat (x'.2.2.2.2.val.take x'.1.start.val)) +
          2 ^ (64 * (4 * x'.1.start.val)) * (x'.2.1.val + x'.2.2.1.val + v.val * x'.2.2.2.1.val) =
        wordsNat (flat (xs0.val.take x'.1.start.val)) +
          (u.val + 2 ^ 64 * v.val) * wordsNat (flat (ys.val.take x'.1.start.val)) + c)
  · rintro ⟨it, a, b, p, w⟩ ⟨he, hs, hwl, ha, hb, hd, hv⟩
    simp only at he hs hwl ha hb hd hv
    unfold low.generic.limb64.mont.mul_add2_loop0.body
    step as ⟨op, iter1, hop, hend1⟩
    cases op with
    | none =>
      have h0 : it.start.val = xs0.length := by
        split at hop
        · simp at hop
        · scalar_tac
      simp only [WP.spec_ok]
      rw [h0] at hv
      have hwl' : w.val.length = xs0.length := hwl
      have hyl : ys.val.length = xs0.length := hy
      have hx0l : xs0.val.length = xs0.length := rfl
      rw [List.take_of_length_le (by omega), List.take_of_length_le (by omega),
        List.take_of_length_le (by omega)] at hv
      exact ⟨hwl, ha, hb, hv⟩
    | some j =>
      have hlt : it.start.val < it.end.val := by
        by_contra hc; simp [hc] at hop
      simp only [hlt, ↓reduceIte, Option.some.injEq] at hop
      obtain ⟨rfl, hst⟩ := hop
      rw [he] at hlt
      have hwL : w.length = w.val.length := rfl
      have hyL : ys.length = ys.val.length := rfl
      have hx0L : xs0.length = xs0.val.length := rfl
      simp only [block_eq]
      step as ⟨x, back, hx, hback⟩
      step as ⟨y, hy'⟩
      step with pu_spec u y as ⟨pu, hpu⟩
      step with pv_spec p y v as ⟨pv, hpv⟩
      step with mul_add2_block_loop_spec u v p y x pu pv hpu hpv (a.val + b.val + v.val * p.val)
        { start := 0#usize, «end» := 4#usize } a b x four_val (by simp) ha hb rfl (by simp [prevAt, wordsNat_nil]) as ⟨c0', c1', x1, hc0', hc1', hx1⟩
      step as ⟨i3, hi3⟩
      step with Array.index_usize_spec y i3 (by simp; scalar_tac) as ⟨prev1, hprev1⟩
      have hbv : (back x1).val = w.val.set it.start.val x1 := by rw [hback]; simp
      have hprev1v : prev1.val = prevAt p y.val 4 := by
        rw [hprev1, ← getElem!_pos]; simp [prevAt, hi3]
      rw [List.drop_eq_getElem_cons (show it.start.val < w.val.length by omega),
        List.drop_eq_getElem_cons (show it.start.val < xs0.val.length by omega)] at hd
      have hx0 : x = xs0.val[it.start.val] := by rw [hx]; exact (List.cons.inj hd).1
      refine ⟨by rw [hend1, he], by omega, ?_, hc0', hc1', ?_, ?_, by omega⟩
      · simp only [Slice.length] at hwl ⊢; rw [hbv, List.length_set]; exact hwl
      · rw [hst, hbv, drop_set_succ']
        exact (List.cons.inj hd).2
      · rw [hst, hbv, take_set_succ' _ _ _ (by omega), flat_append, flat_singleton, wordsNat_append, flat_length,
          List.length_take, Nat.min_eq_left (by omega), wordsNat_flat_take_succ _ _ (by omega),
          wordsNat_flat_take_succ (ys.val) _ (by omega), hprev1v, ← hx0, ← hy',
          show 64 * (4 * (it.start.val + 1)) = 64 * (4 * it.start.val) + 256 by ring, pow_add]
        zify at hv hx1 ⊢
        linear_combination hv + (2 ^ (64 * (4 * it.start.val)) : Int) * hx1
  · exact ⟨hend, hi, hxl, hc0, hc1, hdrop, hinv⟩

/-- `mul_add2`: `x + (u + 2^64 v)·y + c` over `x`'s limbs, as many of `y`'s,
what lands above them returned. -/
@[step]
theorem mul_add2_spec (x y : Slice U64) (u v : U64) (c : U128) (hc : c.val < 2 ^ 64) (hy : x.length ≤ y.length) :
    low.generic.limb64.mont.mul_add2 x y u v c ⦃ r =>
      r.2.length = x.length ∧
      wordsNat r.2.val + 2 ^ (64 * x.length) * r.1.val =
        wordsNat x.val + (u.val + 2 ^ 64 * v.val) * wordsNat (y.val.take x.length) + c.val ⦄ := by
  unfold low.generic.limb64.mont.mul_add2
  step as ⟨y1, hy1⟩
  have hy1v : y1.val = y.val.take x.length := by rw [hy1]; simp
  step as ⟨xs, xr, back, hxsl, hxf, hback⟩
  step as ⟨ys, yr, hysl, hyf⟩
  have hxL : x.length = x.val.length := rfl
  have hyL : y.length = y.val.length := rfl
  have hy1L : y1.val.length = x.length := by rw [hy1v, List.length_take]; omega
  have hxfl := congrArg List.length hxf
  have hyfl := congrArg List.length hyf
  rw [List.length_append, flat_length] at hxfl hyfl
  have hxsL : xs.val.length = x.length / 4 := hxsl
  have hysL : ys.val.length = x.length / 4 := by rw [← hy1L]; exact hysl
  step with mul_add2_blocks_loop_spec u v ys xs (by simp only [Slice.length]; omega) c.val
    { start := 0#usize, «end» := xs.len } c 0#u128 0#u64 xs (by simp) (by simp) rfl hc (by simp) rfl
    (by simp [flat, wordsNat_nil]) as ⟨c0, c1, prev, xs1, hxs1l, hc0, hc1, hxs1⟩
  step with mul_add2_tail_loop_spec u v yr xr (by simp only [Slice.length]; omega) (c0.val + c1.val + v.val * prev.val)
    { start := 0#usize, «end» := xr.len } c0 c1 prev xr (by simp) (by simp) rfl hc0 hc1 rfl
    (by simp [wordsNat_nil]) as ⟨c01, c11, prev1, xr1, hxr1l, hc01, hc11, hxr1⟩
  step as ⟨i3, hi3⟩
  step with mul_add_limb_spec v prev1 i3 c11 hc11 as ⟨r, hr⟩
  have hi3v : i3.val = c01.val := by rw [hi3, cast_u64_val, Nat.mod_eq_of_lt hc01]
  have hlen : (flat xs1.val ++ xr1.val).length = x.length := by
    rw [List.length_append, flat_length]; simp only [Slice.length] at hxs1l hxr1l; omega
  have hbv := hback xs1 xr1 (by rw [hlen]; exact x.property)
  refine ⟨by simp only [Slice.length]; rw [hbv]; exact hlen, ?_⟩
  rw [hbv, wordsNat_append, flat_length, ← hxf, ← hy1v, ← hyf, wordsNat_append, wordsNat_append, flat_length,
    flat_length, hr, hi3v]
  have hxs1L : xs1.val.length = x.length / 4 := by simp only [Slice.length] at hxs1l; omega
  have hxrL : xr.length = x.length - 4 * (x.length / 4) := by simp only [Slice.length]; omega
  rw [hxs1L, hxsL, hysL]
  rw [hxrL] at hxr1
  simp only [Slice.length] at hxs1
  rw [hxsL] at hxs1
  rw [show 64 * x.length = 64 * (4 * (x.length / 4)) + 64 * (x.length - 4 * (x.length / 4)) by omega, pow_add]
  zify at hxs1 hxr1 ⊢
  linear_combination hxs1 + (2 ^ (64 * (4 * (x.length / 4))) : Int) * hxr1

/-! ## `redc` -/

theorem setSlice_eq {α : Type} (s w : List α) (i : Nat) (hw : i + w.length ≤ s.length) :
    s.setSlice! i w = s.take i ++ w ++ s.drop (i + w.length) := by
  simp only [List.setSlice!]
  rw [show min w.length (s.length - i) = w.length by omega, List.take_length]

theorem window_eq {α : Type} (s : List α) (i n : Nat) :
    s = s.take i ++ s.slice i (i + n) ++ s.drop (i + n) := by
  simp only [List.slice, Nat.add_sub_cancel_left, List.append_assoc]
  conv_lhs => rw [← List.take_append_drop i s, ← List.take_append_drop n (s.drop i)]
  rw [List.drop_drop]

/-- Writing `w` over the limbs at `i` adds the difference there. -/
theorem wordsNat_window (s w : List U64) (i : Nat) (hw : i + w.length ≤ s.length) :
    wordsNat (s.setSlice! i w) + 2 ^ (64 * i) * wordsNat (s.slice i (i + w.length)) =
      wordsNat s + 2 ^ (64 * i) * wordsNat w := by
  have hsl : (s.slice i (i + w.length)).length = w.length := by simp [List.slice_length]; omega
  conv_rhs => rw [window_eq s i w.length]
  rw [setSlice_eq s w i hw]
  simp only [wordsNat_append, List.length_append, List.length_take, hsl, Nat.min_eq_left (by omega : i ≤ s.length)]
  ring

theorem getElem!_set_ne' {α : Type} [Inhabited α] (l : List α) (i j : Nat) (x : α) (h : i ≠ j) :
    (l.set i x)[j]! = l[j]! := by
  simp [List.getElem!_eq_getElem?_getD, List.getElem?_set_ne h]

/-- Writing `x` at limb `j` adds the difference there. -/
theorem wordsNat_set (s : List U64) (j : Nat) (x : U64) (hj : j < s.length) :
    wordsNat (s.set j x) + 2 ^ (64 * j) * s[j]!.val = wordsNat s + 2 ^ (64 * j) * x.val := by
  have h := wordsNat_window s [x] j (by simp; omega)
  have h1 : s.setSlice! j [x] = s.set j x := by
    rw [setSlice_eq s [x] j (by simp; omega), List.set_eq_take_append_cons_drop]
    simp [hj]
  have h2 : s.slice j (j + [x].length) = [s[j]!] := by
    simp only [List.slice, List.length_singleton, Nat.add_sub_cancel_left, getElem!_pos s j hj]
    exact List.take_one_drop_eq_of_lt_length hj
  rw [h1, h2] at h
  simpa [wordsNat_cons, wordsNat_nil] using h

theorem take_setSlice {α : Type} (s w : List α) (i c : Nat) (hw : i + w.length ≤ s.length) (hc : c ≤ w.length) :
    (s.setSlice! i w).take (i + c) = s.take i ++ w.take c := by
  have hA : (s.take i).length = i := by simp; omega
  have := List.take_length_add_append (l₁ := s.take i) (l₂ := w ++ s.drop (i + w.length)) c
  rw [hA] at this
  rw [setSlice_eq s w i hw, List.append_assoc, this, List.take_append_of_le_length hc]

theorem drop_setSlice {α : Type} (s w : List α) (i : Nat) (hw : i + w.length = s.length) :
    (s.setSlice! i w).drop i = w := by
  rw [setSlice_eq s w i (by omega), List.append_assoc, List.drop_append_of_le_length (by simp; omega)]
  simp [show i + w.length = s.length from hw]

theorem wordsNat_mod_limb (l : List U64) (h : 1 ≤ l.length) : wordsNat l % 2 ^ 64 = l[0]!.val := by
  obtain ⟨a, l, rfl⟩ : ∃ a l', l = a :: l' := ⟨l.head (by rintro rfl; simp at h), l.tail, by simp⟩
  rw [wordsNat_cons, Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt (u64_lt a)]
  simp

theorem wordsNat_mod_limbs2 (l : List U64) (h : 2 ≤ l.length) :
    wordsNat l % 2 ^ 128 = l[0]!.val + 2 ^ 64 * l[1]!.val := by
  rw [show (2 : Nat) ^ 128 = 2 ^ (64 * 2) by norm_num, ← wordsNat_take_mod]
  obtain ⟨a, b, l, rfl⟩ : ∃ a b l', l = a :: b :: l' := by
    match l, h with
    | a :: b :: l', _ => exact ⟨a, b, l', rfl⟩
  simp [wordsNat_cons, wordsNat_nil]

/-- A multiple `u = a·n0 mod 2^64` of `m0`, for `n0 = -m0⁻¹`, clears `a`'s
low limb. -/
theorem clear_limb {a n0 m0 : Nat} (hn : (m0 * n0 + 1) % 2 ^ 64 = 0) :
    (a + (a * n0 % 2 ^ 64) * m0) % 2 ^ 64 = 0 := by
  have h : a + (a * n0 % 2 ^ 64) * m0 ≡ a * (m0 * n0 + 1) [MOD 2 ^ 64] := by
    have := ((Nat.mod_modEq (a * n0) (2 ^ 64)).mul_right m0).add_left a
    rw [show a * (m0 * n0 + 1) = a + a * n0 * m0 by ring]; exact this
  unfold Nat.ModEq at h
  rw [h, Nat.mul_mod, hn]; simp

/-- `redc`'s two steps a pass clear two limbs: `u` the low one, and `v` the
next, as the first step's sum leaves it. -/
theorem clear_two {a0 a1 m0 m1 n0 u v : Nat} (hn : (m0 * n0 + 1) % 2 ^ 64 = 0) (hu : u = a0 * n0 % 2 ^ 64)
    (hv : v = ((u * m1 + a1 + (u * m0 + a0) / 2 ^ 64) % 2 ^ 64) * n0 % 2 ^ 64) :
    (a0 + 2 ^ 64 * a1 + (u + 2 ^ 64 * v) * (m0 + 2 ^ 64 * m1)) % 2 ^ 128 = 0 := by
  have hc0 : (u * m0 + a0) % 2 ^ 64 = 0 := by
    have := clear_limb (a := a0) hn; rw [← hu] at this; rw [← this]; ring_nf
  have hc := Nat.mod_add_div (u * m0 + a0) (2 ^ 64)
  rw [hc0, zero_add] at hc
  set c := (u * m0 + a0) / 2 ^ 64
  set nx := u * m1 + a1 + c
  have he0 : (nx + v * m0) % 2 ^ 64 = 0 := by
    have := clear_limb (a := nx) hn
    rw [hv, Nat.mod_mul_mod]; rw [← this]
  have he := Nat.mod_add_div (nx + v * m0) (2 ^ 64)
  rw [he0, zero_add] at he
  set e := (nx + v * m0) / 2 ^ 64
  have : a0 + 2 ^ 64 * a1 + (u + 2 ^ 64 * v) * (m0 + 2 ^ 64 * m1) = 2 ^ 128 * (e + v * m1) := by
    simp only [nx] at he
    zify at hc he ⊢
    linear_combination -hc - (2 ^ 64 : Int) * he
  rw [this, Nat.mul_mod_right]

/-- `redc`'s state after clearing `i` limbs of `t`, from `T`: those limbs
are zero, and `t`, with `top` above limb `i + k`, is `T` plus a multiple of
`M` below `2^(64i)`. -/
def RedcInv (T M k p : Nat) (t : Slice U64) (top : U128) (i : Nat) : Prop :=
  t.length = p + k ∧ i ≤ p ∧ top.val < 2 ^ 64 ∧ wordsNat (t.val.take i) = 0 ∧
    ∃ Q, Q < 2 ^ (64 * i) ∧ wordsNat t.val + 2 ^ (64 * (i + k)) * top.val = T + M * Q

theorem redc_loop0_spec (m : Slice U64) (n0 : U64) (k p : Usize) (T : Nat) (hk : k.val = m.length)
    (hn : (m.val[0]!.val * n0.val + 1) % 2 ^ 64 = 0)
    (t : Slice U64) (top : U128) (i : Usize) (hinv : RedcInv T (wordsNat m.val) k.val p.val t top i.val) :
    low.generic.limb64.mont.redc_loop0 t m n0 k p top i ⦃ r =>
      RedcInv T (wordsNat m.val) k.val p.val r.1 r.2.1 r.2.2.val ⦄ := by
  unfold low.generic.limb64.mont.redc_loop0
  apply loop.spec_decr_nat (fun x => p.val + 1 - x.2.2.val)
    (fun x : Slice U64 × U128 × Usize => RedcInv T (wordsNat m.val) k.val p.val x.1 x.2.1 x.2.2.val)
  · rintro ⟨t, top, i⟩ hI
    dsimp only at hI ⊢
    unfold low.generic.limb64.mont.redc_loop0.body
    have hI' := hI
    obtain ⟨htl, hip, htop, hlow, Q, hQ, hval⟩ := hI'
    have htmax : t.length ≤ Usize.max := t.property
    split
    · rename_i hk2
      step as ⟨i1, hi1⟩
      split
      · rename_i hlt
        have hk2' : 2 ≤ k.val := by scalar_tac
        have hlt' : i.val + 1 < p.val := by scalar_tac
        have htL : t.val.length = p.val + k.val := htl
        have hmL : m.val.length = k.val := hk.symm
        step as ⟨ti, hti⟩
        step as ⟨u, hu⟩
        step as ⟨m0, hm0⟩
        step with mul_add_limb_spec u m0 ti 0#u128 (by simp) as ⟨s0, hs0⟩
        step as ⟨cy, hcy, _⟩
        step as ⟨m1, hm1⟩
        step as ⟨ti1, hti1⟩
        have hs0b : s0.val < 2 ^ 128 := by
          rw [hs0]; exact mul_add_limb_bound _ _ _ _ u.hBounds m0.hBounds ti.hBounds (by norm_num)
        have hcyv : cy.val = s0.val / 2 ^ 64 := by rw [hcy]; simp [Nat.shiftRight_eq_div_pow]
        step with mul_add_limb_spec u m1 ti1 cy (by rw [hcyv]; omega) as ⟨nx, hnx⟩
        step as ⟨nxl, hnxl⟩
        step as ⟨v, hv⟩
        step as ⟨ik, hik⟩
        step as ⟨w, back, hw, hwl, hback⟩
        step with mul_add2_spec w m u v 0#u128 (by simp) (by simp only [Slice.length] at hwl ⊢; omega)
          as ⟨rest, w1, hw1l, hw1⟩
        step as ⟨tk, htk⟩
        simp only [lift, bind_ok]
        step as ⟨t2, ht2⟩
        step as ⟨ik1, hik1⟩
        step as ⟨tk1, htk1⟩
        step as ⟨rh, hrh, _⟩
        step as ⟨sh, hsh, _⟩
        step as ⟨ik2, hik2⟩
        step as ⟨t3, ht3⟩
        step as ⟨top1, htop1, _⟩
        step as ⟨i2, hi2⟩
        set sum := core.num.U128.wrapping_add (core.num.U128.wrapping_add (core.convert.num.FromU128U64.from tk)
          (core.convert.num.FromU128U64.from (UScalar.cast UScalarTy.U64 rest))) top with hsumdef
        set sum1 := core.num.U128.wrapping_add (core.num.U128.wrapping_add (core.convert.num.FromU128U64.from tk1) rh)
          sh with hsum1def
        have hiL : i.val + k.val ≤ t.val.length := by omega
        have hwL : w.val.length = k.val := by simp only [Slice.length] at hwl; omega
        have hw1L : w1.val.length = k.val := by simp only [Slice.length] at hw1l; omega
        have huv : u.val = ti.val * n0.val % 2 ^ 64 := by
          rw [hu]; simp [core.num.U64.wrapping_mul_val_eq, u64_size]
        have hvv : v.val = nx.val % 2 ^ 64 * n0.val % 2 ^ 64 := by
          rw [hv, hnxl]; simp [core.num.U64.wrapping_mul_val_eq, cast_u64_val, u64_size, Nat.mod_mul_mod]
        have hrhv : rh.val = rest.val / 2 ^ 64 := by rw [hrh]; simp [Nat.shiftRight_eq_div_pow]
        have hrestb := rest.hBounds
        simp only [UScalarTy.numBits] at hrestb
        have hsumv : sum.val = tk.val + rest.val % 2 ^ 64 + top.val := by
          rw [hsumdef]
          have := u64_lt tk
          have : rest.val % 2 ^ 64 < 2 ^ 64 := Nat.mod_lt _ (by norm_num)
          simp only [core.num.U128.wrapping_add_val_eq, from_u128_val, cast_u64_val, UScalar.size,
            UScalarTy.numBits]
          rw [Nat.mod_eq_of_lt (by omega), Nat.mod_eq_of_lt (by omega)]
        have hshv : sh.val = sum.val / 2 ^ 64 := by rw [hsh]; simp [Nat.shiftRight_eq_div_pow]
        have hsum1v : sum1.val = tk1.val + rh.val + sh.val := by
          rw [hsum1def]
          have := u64_lt tk1
          have : rh.val < 2 ^ 64 := by rw [hrhv]; omega
          have : sh.val < 4 := by rw [hshv, hsumv]; have := u64_lt tk; omega
          simp only [core.num.U128.wrapping_add_val_eq, from_u128_val, UScalar.size, UScalarTy.numBits]
          rw [Nat.mod_eq_of_lt (by omega), Nat.mod_eq_of_lt (by omega)]
        have htop1v : top1.val = sum1.val / 2 ^ 64 := by rw [htop1]; simp [Nat.shiftRight_eq_div_pow]
        have hbv : (back w1).val = t.val.setSlice! i.val w1.val := by rw [hback]; simp [Slice.setSlice!_val]
        have hbL : (back w1).val.length = p.val + k.val := by rw [hbv, List.length_setSlice!]; omega
        have htkb : (back w1).val[i.val + k.val]! = tk := by rw [htk, ← getElem!_pos, hik]
        have htkv : tk = t.val[i.val + k.val]! := by
          rw [← htkb, hbv]
          exact List.getElem!_setSlice!_same _ _ _ _ (Or.inr (by omega))
        have ht2v : t2.val = (back w1).val.set (i.val + k.val) (UScalar.cast .U64 sum) := by
          rw [ht2, ← hik]; simp
        have htk1b : t2.val[i.val + k.val + 1]! = tk1 := by rw [htk1, ← getElem!_pos, hik1, hik]
        have ht3v : t3.val = t2.val.set (i.val + k.val + 1) (UScalar.cast .U64 sum1) := by
          rw [ht3]; simp [hik2, hik]
        have hmk : List.take w.length m.val = m.val := List.take_of_length_le (by simp only [Slice.length]; omega)
        have hw1' : wordsNat w1.val + 2 ^ (64 * k.val) * rest.val =
            wordsNat w.val + (u.val + 2 ^ 64 * v.val) * wordsNat m.val := by
          rw [hmk, show w.length = k.val by simp only [Slice.length]; omega] at hw1; simpa using hw1
        have hW := wordsNat_window t.val w1.val i.val (by omega)
        rw [hw1L, show t.val.slice i.val (i.val + k.val) = w.val by rw [hw, hik], ← hbv] at hW
        have hS2 := wordsNat_set (back w1).val (i.val + k.val) (UScalar.cast .U64 sum) (by omega)
        rw [← ht2v, htkb, cast_u64_val] at hS2
        have ht2L : t2.val.length = p.val + k.val := by rw [ht2v, List.length_set]; exact hbL
        have hS3 := wordsNat_set t2.val (i.val + k.val + 1) (UScalar.cast .U64 sum1) (by omega)
        rw [← ht3v, htk1b, cast_u64_val] at hS3
        have hrmd := Nat.mod_add_div rest.val (2 ^ 64)
        have hsmd := Nat.mod_add_div sum.val (2 ^ 64)
        have hs1md := Nat.mod_add_div sum1.val (2 ^ 64)
        rw [hrhv, hshv] at hsum1v
        have hBi : u.val + 2 ^ 64 * v.val + 1 ≤ 2 ^ 128 := by
          have := u64_lt u; have := u64_lt v; omega
        -- The pass clears limbs `i` and `i + 1`.
        have hclear : wordsNat w1.val % 2 ^ 128 = 0 := by
          have h1 : wordsNat w1.val % 2 ^ 128 = (wordsNat w.val + (u.val + 2 ^ 64 * v.val) * wordsNat m.val) % 2 ^ 128 := by
            rw [← hw1', show 64 * k.val = 128 + 64 * (k.val - 2) by omega, pow_add, mul_assoc,
              Nat.add_mul_mod_self_left]
          have hw0 : w.val[0]! = ti := by
            rw [hw, List.getElem!_slice _ _ _ _ ⟨by omega, by omega⟩, hti, ← getElem!_pos]; simp
          have hw1v : w.val[1]! = ti1 := by
            rw [hw, List.getElem!_slice _ _ _ _ ⟨by omega, by omega⟩, hti1, ← getElem!_pos, hi1]
          have hWm : wordsNat w.val ≡ ti.val + 2 ^ 64 * ti1.val [MOD 2 ^ 128] := by
            unfold Nat.ModEq
            rw [wordsNat_mod_limbs2 _ (by omega), hw0, hw1v, Nat.mod_eq_of_lt]
            have := u64_lt ti; have := u64_lt ti1; omega
          have hm0v : m.val[0]! = m0 := by rw [hm0, ← getElem!_pos]
          have hm1v : m.val[1]! = m1 := by rw [hm1, ← getElem!_pos]
          have hMm : wordsNat m.val ≡ m0.val + 2 ^ 64 * m1.val [MOD 2 ^ 128] := by
            unfold Nat.ModEq
            rw [wordsNat_mod_limbs2 _ (by omega), hm0v, hm1v, Nat.mod_eq_of_lt]
            have := u64_lt m0; have := u64_lt m1; omega
          have hsum := hWm.add (hMm.mul_left (u.val + 2 ^ 64 * v.val))
          unfold Nat.ModEq at hsum
          rw [h1, hsum]
          refine clear_two (n0 := n0.val) (by rw [← hm0v]; exact hn) huv ?_
          rw [hvv, hnx, hcyv, hs0]; simp
        refine ⟨⟨?_, by omega, ?_, ?_, Q + 2 ^ (64 * i.val) * (u.val + 2 ^ 64 * v.val), ?_, ?_⟩, by omega⟩
        · simp only [Slice.length]; rw [ht3v, List.length_set]; exact ht2L
        · rw [htop1v]; have := u64_lt tk1; have := u64_lt tk; omega
        · have htake : t3.val.take (i.val + 2) = t.val.take i.val ++ w1.val.take 2 := by
            rw [ht3v, List.take_set_of_le (by omega), ht2v, List.take_set_of_le (by omega), hbv,
              take_setSlice _ _ _ _ (by omega) (by omega)]
          rw [hi2, htake, wordsNat_append, hlow, wordsNat_take_mod, show 64 * 2 = 128 by rfl, hclear]
          simp
        · rw [hi2, show 64 * (i.val + 2) = 64 * i.val + 128 by ring, pow_add]
          calc Q + 2 ^ (64 * i.val) * (u.val + 2 ^ 64 * v.val)
              < 2 ^ (64 * i.val) * (u.val + 2 ^ 64 * v.val + 1) := by rw [Nat.mul_add_one]; omega
            _ ≤ 2 ^ (64 * i.val) * 2 ^ 128 := Nat.mul_le_mul_left _ hBi
        · rw [hi2, htop1v]
          zify at hS3 hS2 hW hw1' hval hs1md hsum1v hrmd hsmd hsumv ⊢
          linear_combination hS3 + hS2 + hW + (2 ^ (64 * i.val) : Int) * hw1' + hval +
            (2 ^ (64 * (i.val + k.val + 1)) : Int) * (hs1md + hsum1v) +
            (2 ^ (64 * (i.val + k.val)) : Int) * (hrmd + hsmd + hsumv)
      · simp only [WP.spec_ok]; exact hI
    · simp only [WP.spec_ok]; exact hI
  · exact hinv

theorem redc_loop1_spec (m : Slice U64) (n0 : U64) (k p : Usize) (T : Nat) (hk : k.val = m.length)
    (hk1 : 1 ≤ k.val) (hn : (m.val[0]!.val * n0.val + 1) % 2 ^ 64 = 0)
    (t : Slice U64) (top : U128) (i : Usize) (hinv : RedcInv T (wordsNat m.val) k.val p.val t top i.val) :
    low.generic.limb64.mont.redc_loop1 t m n0 k p top i ⦃ r =>
      RedcInv T (wordsNat m.val) k.val p.val r.1 r.2 p.val ⦄ := by
  unfold low.generic.limb64.mont.redc_loop1
  apply loop.spec_decr_nat (fun x => p.val - x.2.2.val)
    (fun x : Slice U64 × U128 × Usize => RedcInv T (wordsNat m.val) k.val p.val x.1 x.2.1 x.2.2.val)
  · rintro ⟨t, top, i⟩ hI
    dsimp only at hI ⊢
    unfold low.generic.limb64.mont.redc_loop1.body
    have hI' := hI
    obtain ⟨htl, hip, htop, hlow, Q, hQ, hval⟩ := hI'
    have htmax : t.length ≤ Usize.max := t.property
    split
    · rename_i hlt
      have hlt' : i.val < p.val := by scalar_tac
      have htL : t.val.length = p.val + k.val := htl
      have hmL : m.val.length = k.val := hk.symm
      step as ⟨ti, hti⟩
      step as ⟨u, hu⟩
      step as ⟨ik, hik⟩
      step as ⟨w, back, hw, hwl, hback⟩
      step with mul_add_spec w m u (by simp only [Slice.length] at hwl ⊢; omega) as ⟨cy, w1, hw1l, hcy, hw1⟩
      step as ⟨tk, htk⟩
      simp only [lift, bind_ok]
      step as ⟨t2, ht2⟩
      step as ⟨top1, htop1, _⟩
      step as ⟨i2, hi2⟩
      set sum := core.num.U128.wrapping_add (core.num.U128.wrapping_add (core.convert.num.FromU128U64.from tk) cy)
        top with hsumdef
      have hwL : w.val.length = k.val := by simp only [Slice.length] at hwl; omega
      have hw1L : w1.val.length = k.val := by simp only [Slice.length] at hw1l; omega
      have huv : u.val = ti.val * n0.val % 2 ^ 64 := by
        rw [hu]; simp [core.num.U64.wrapping_mul_val_eq, u64_size]
      have hsumv : sum.val = tk.val + cy.val + top.val := by
        rw [hsumdef]
        have := u64_lt tk
        simp only [core.num.U128.wrapping_add_val_eq, from_u128_val, UScalar.size, UScalarTy.numBits]
        rw [Nat.mod_eq_of_lt (by omega), Nat.mod_eq_of_lt (by omega)]
      have htop1v : top1.val = sum.val / 2 ^ 64 := by rw [htop1]; simp [Nat.shiftRight_eq_div_pow]
      have hbv : (back w1).val = t.val.setSlice! i.val w1.val := by rw [hback]; simp [Slice.setSlice!_val]
      have hbL : (back w1).val.length = p.val + k.val := by rw [hbv, List.length_setSlice!]; omega
      have htkb : (back w1).val[i.val + k.val]! = tk := by rw [htk, ← getElem!_pos, hik]
      have ht2v : t2.val = (back w1).val.set (i.val + k.val) (UScalar.cast .U64 sum) := by
        rw [ht2]; simp [hik]
      have hw1' : wordsNat w1.val + 2 ^ (64 * k.val) * cy.val = wordsNat w.val + u.val * wordsNat m.val := by
        rw [show w.length = k.val by simp only [Slice.length]; omega] at hw1; exact hw1
      have hW := wordsNat_window t.val w1.val i.val (by omega)
      rw [hw1L, show t.val.slice i.val (i.val + k.val) = w.val by rw [hw, hik], ← hbv] at hW
      have hS := wordsNat_set (back w1).val (i.val + k.val) (UScalar.cast .U64 sum) (by omega)
      rw [← ht2v, htkb, cast_u64_val] at hS
      have hsmd := Nat.mod_add_div sum.val (2 ^ 64)
      -- The step clears limb `i`.
      have hclear : wordsNat w1.val % 2 ^ 64 = 0 := by
        have h1 : wordsNat w1.val % 2 ^ 64 = (wordsNat w.val + u.val * wordsNat m.val) % 2 ^ 64 := by
          rw [← hw1', show 64 * k.val = 64 + 64 * (k.val - 1) by omega, pow_add, mul_assoc,
            Nat.add_mul_mod_self_left]
        have hw0 : w.val[0]! = ti := by
          rw [hw, List.getElem!_slice _ _ _ _ ⟨by omega, by omega⟩, hti, ← getElem!_pos]; simp
        have hWm : wordsNat w.val ≡ ti.val [MOD 2 ^ 64] := by
          unfold Nat.ModEq; rw [wordsNat_mod_limb _ (by omega), hw0, Nat.mod_eq_of_lt (u64_lt ti)]
        have hMm : wordsNat m.val ≡ m.val[0]!.val [MOD 2 ^ 64] := by
          unfold Nat.ModEq; rw [wordsNat_mod_limb _ (by omega), Nat.mod_eq_of_lt (u64_lt _)]
        have hsum := hWm.add (hMm.mul_left u.val)
        unfold Nat.ModEq at hsum
        rw [h1, hsum, huv]
        exact clear_limb hn
      refine ⟨⟨?_, by omega, ?_, ?_, Q + 2 ^ (64 * i.val) * u.val, ?_, ?_⟩, by omega⟩
      · simp only [Slice.length]; rw [ht2v, List.length_set]; exact hbL
      · rw [htop1v, hsumv]; have := u64_lt tk; omega
      · have htake : t2.val.take (i.val + 1) = t.val.take i.val ++ w1.val.take 1 := by
          rw [ht2v, List.take_set_of_le (by omega), hbv, take_setSlice _ _ _ _ (by omega) (by omega)]
        rw [hi2, htake, wordsNat_append, hlow, wordsNat_take_mod, show 64 * 1 = 64 by rfl, hclear]
        simp
      · rw [hi2, show 64 * (i.val + 1) = 64 * i.val + 64 by ring, pow_add]
        calc Q + 2 ^ (64 * i.val) * u.val
            < 2 ^ (64 * i.val) * (u.val + 1) := by rw [Nat.mul_add_one]; omega
          _ ≤ 2 ^ (64 * i.val) * 2 ^ 64 := Nat.mul_le_mul_left _ (u64_lt u)
      · rw [hi2, htop1v]
        zify at hS hW hw1' hval hsmd hsumv ⊢
        linear_combination hS + hW + (2 ^ (64 * i.val) : Int) * hw1' + hval +
          (2 ^ (64 * (i.val + k.val)) : Int) * (hsmd + hsumv)
    · rename_i hge
      have : i.val = p.val := by scalar_tac
      simp only [WP.spec_ok]
      rw [this] at hI; exact hI
  · exact hinv

/-- `0 - b` for a bit `b`: no limb, or every one. -/
theorem neg_bit_val (b : U64) (hb : b.val ≤ 1) :
    (core.num.U64.wrapping_sub 0#u64 b).val = if b.val = 0 then 0 else 2 ^ 64 - 1 := by
  rcases (show b.val = 0 ∨ b.val = 1 by omega) with h | h <;> simp [core.num.U64.wrapping_sub_val_eq, u64_size, h]

theorem neg_bit_mask (b : U64) (hb : b.val ≤ 1) : IsMask (core.num.U64.wrapping_sub 0#u64 b) := by
  unfold IsMask; rw [neg_bit_val b hb]; split <;> simp

theorem or_not_val (t c : U64) (ht : t.val ≤ 1) (hc : c.val ≤ 1) :
    (t ||| (c ^^^ 1#u64)).val = if t.val = 0 ∧ c.val = 1 then 0 else 1 := by
  rw [UScalar.val_or, UScalar.val_xor, show (1#u64).val = 1 by simp]
  rcases (show t.val = 0 ∨ t.val = 1 by omega) with h1 | h1 <;>
    rcases (show c.val = 0 ∨ c.val = 1 by omega) with h2 | h2 <;> simp [h1, h2]

/-- `redc`: for `t` below `2^(64p)·m`, `p` limbs beyond the odd `m`'s `k`,
the `k` limbs from `p` are `t / 2^(64p)` modulo `m`. -/
@[step]
theorem redc_spec (t m : Slice U64) (n0 : U64) (hk1 : 1 ≤ m.length) (hkt : m.length ≤ t.length)
    (hn0 : (wordsNat m.val * n0.val + 1) % 2 ^ 64 = 0)
    (hT : wordsNat t.val < 2 ^ (64 * (t.length - m.length)) * wordsNat m.val) :
    low.generic.limb64.mont.redc t m n0 ⦃ r =>
      r.length = t.length ∧ wordsNat (r.val.drop (t.length - m.length)) < wordsNat m.val ∧
      wordsNat (r.val.drop (t.length - m.length)) * 2 ^ (64 * (t.length - m.length)) % wordsNat m.val =
        wordsNat t.val % wordsNat m.val ⦄ := by
  unfold low.generic.limb64.mont.redc
  have hmL : m.val.length = m.length := rfl
  have htL : t.val.length = t.length := rfl
  have hn : (m.val[0]!.val * n0.val + 1) % 2 ^ 64 = 0 := by
    rw [← wordsNat_mod_limb _ (by omega), Nat.add_mod, Nat.mul_mod, Nat.mod_mod, ← Nat.mul_mod, ← Nat.add_mod]
    exact hn0
  step as ⟨pp, hpp⟩
  have hppv : pp.val = t.length - m.length := by scalar_tac
  set p := t.length - m.length with hpdef
  set k := m.length with hkdef
  set M := wordsNat m.val
  set T := wordsNat t.val
  step with redc_loop0_spec m n0 m.len pp T (by simp) hn t 0#u128 0#usize
    ⟨by simp [Slice.length] at hppv ⊢; omega, by simp, by simp, by simp [wordsNat_nil], 0, by simp, by simp [T]⟩
    as ⟨t1, top, i1, hI1⟩
  step with redc_loop1_spec m n0 m.len pp T (by simp) (by simp; omega) hn t1 top i1 hI1 as ⟨t2, top1, hI2⟩
  obtain ⟨ht2l, -, htop, hlow, Q, hQ, hval⟩ := hI2
  simp only [Slice.len_val] at ht2l hval
  rw [hppv] at ht2l hlow hQ hval
  have ht2L : t2.val.length = p + k := ht2l
  step as ⟨r, back, hr, hrl, hback⟩
  have hrL : r.length = k := by simp only [Slice.length] at hrl ⊢; omega
  step with cmp_lt_limbs_spec r m (by omega) as ⟨below, hbelow⟩
  -- `t2` is `R` above `p` zero limbs, with `top` above it.
  have hR : wordsNat t2.val = 2 ^ (64 * p) * wordsNat r.val := by
    rw [wordsNat_take_drop t2.val p, hlow, List.length_take, Nat.min_eq_left (by omega), hr, hppv]
    simp
  set R := wordsNat r.val
  have hMk : M < 2 ^ (64 * k) := wordsNat_lt' m.val
  have hX : 2 ^ (64 * p) * (R + 2 ^ (64 * k) * top1.val) = T + M * Q := by
    rw [← hval, hR, show 64 * (p + k) = 64 * p + 64 * k by ring, pow_add]; ring
  have hXlt : R + 2 ^ (64 * k) * top1.val < 2 * M := by
    have h1 : M * Q < M * 2 ^ (64 * p) := Nat.mul_lt_mul_of_pos_left hQ (by
      rcases Nat.eq_zero_or_pos M with h | h
      · rw [h, mul_zero] at hT; omega
      · exact h)
    have h2 : 2 ^ (64 * p) * (R + 2 ^ (64 * k) * top1.val) < 2 ^ (64 * p) * (2 * M) := by
      rw [hX]; nlinarith
    exact Nat.lt_of_mul_lt_mul_left h2
  have htop1 : top1.val ≤ 1 := by
    by_contra h
    have : 2 ^ (64 * k) * 2 ≤ 2 ^ (64 * k) * top1.val := Nat.mul_le_mul_left _ (by omega)
    omega
  have hbel : below.val ≤ 1 := by rw [hbelow]; split <;> simp
  have hcast : (UScalar.cast .U64 top1).val = top1.val := by rw [cast_u64_val, Nat.mod_eq_of_lt (by omega)]
  have hbit : (UScalar.cast .U64 top1 ||| (below ^^^ 1#u64)).val ≤ 1 := by
    rw [or_not_val _ _ (by omega) hbel]; split <;> simp
  simp only [lift, bind_ok]
  step with sub_limbs_masked_spec r m _ (neg_bit_mask _ hbit) (by omega) as ⟨r1, hr1l, b, hb, hr1⟩
  have hr1L : r1.val.length = k := by simp only [Slice.length] at hr1l hrL; omega
  have hdrop : (back r1).val.drop p = r1.val := by
    rw [hback, hppv]; exact drop_setSlice _ _ _ (by omega)
  have hmasked : masked (core.num.U64.wrapping_sub 0#u64 (UScalar.cast .U64 top1 ||| (below ^^^ 1#u64))) M =
      if top1.val = 0 ∧ below.val = 1 then 0 else M := by
    unfold masked
    rw [neg_bit_val _ hbit, or_not_val _ _ (by omega) hbel, hcast]
    by_cases hc : top1.val = 0 ∧ below.val = 1 <;> simp [hc]
  rw [hmasked, hrL] at hr1
  have hr1lt : wordsNat r1.val < 2 ^ (64 * k) := by have := wordsNat_lt' r1.val; rwa [hr1L] at this
  have hRlt : R < 2 ^ (64 * k) := by have := wordsNat_lt' r.val; simp only [Slice.length] at hrL; rwa [hrL] at this
  have hM0 : 0 < M := by
    rcases Nat.eq_zero_or_pos M with h | h
    · rw [h, mul_zero] at hT; omega
    · exact h
  have hR1 : wordsNat r1.val = (R + 2 ^ (64 * k) * top1.val) % M := by
    rw [show (2 : Int) ^ (64 * k) = ((2 ^ (64 * k) : Nat) : Int) by push_cast; rfl] at hr1
    generalize 2 ^ (64 * k) = B at *
    rcases (show top1.val = 0 ∨ top1.val = 1 by omega) with ht | ht
    · rw [ht] at hr1 hXlt ⊢
      simp only [mul_zero, add_zero] at hXlt ⊢
      by_cases hRM : R < M
      · have hb1 : below.val = 1 := by rw [hbelow]; exact if_pos hRM
        simp only [hb1, and_self, ↓reduceIte, Nat.cast_zero, sub_zero] at hr1
        rw [Nat.mod_eq_of_lt hRM]
        rcases (show b = 0 ∨ b = 1 by omega) with rfl | rfl <;> push_cast at hr1 <;> omega
      · have hb0 : below.val = 0 := by rw [hbelow]; exact if_neg hRM
        simp only [hb0, zero_ne_one, and_false, ↓reduceIte] at hr1
        rw [Nat.mod_eq_sub_mod (by omega), Nat.mod_eq_of_lt (by omega)]
        rcases (show b = 0 ∨ b = 1 by omega) with rfl | rfl <;> push_cast at hr1 <;> omega
    · rw [ht] at hr1 hXlt ⊢
      simp only [one_ne_zero, false_and, ↓reduceIte] at hr1
      simp only [mul_one] at hXlt ⊢
      rw [Nat.mod_eq_sub_mod (by omega), Nat.mod_eq_of_lt (by omega)]
      rcases (show b = 0 ∨ b = 1 by omega) with rfl | rfl <;> push_cast at hr1 <;> omega
  refine ⟨?_, ?_, ?_⟩
  · simp only [Slice.length]; rw [hback, List.length_setSlice!, ht2L]; omega
  · rw [hdrop, hR1]; exact Nat.mod_lt _ hM0
  · rw [hdrop, hR1, Nat.mod_mul_mod, mul_comm, hX, Nat.add_mul_mod_self_left]

/-! ## `mul_limbs` -/

/-- Limbs of `l` from `q` up are zero. -/
def ZeroFrom (l : List U64) (q : Nat) : Prop := ∀ j, q ≤ j → l[j]!.val = 0

theorem mul_limbs_loop_spec (x y : Slice U64) (n : Usize) (hx : x.length = n.val) (hy : y.length = n.val)
    (iter : core.ops.range.Range Usize) (z : Slice U64) (hend : iter.end.val = n.val / 2)
    (hi : iter.start.val ≤ n.val / 2) (hzl : z.length = 2 * n.val)
    (hzero : ZeroFrom z.val (2 * iter.start.val + n.val))
    (hval : wordsNat z.val = wordsNat (x.val.take (2 * iter.start.val)) * wordsNat y.val) :
    low.generic.limb64.mont.mul_limbs_loop iter x y n z ⦃ r =>
      r.length = 2 * n.val ∧ ZeroFrom r.val (2 * (n.val / 2) + n.val) ∧
      wordsNat r.val = wordsNat (x.val.take (2 * (n.val / 2))) * wordsNat y.val ⦄ := by
  unfold low.generic.limb64.mont.mul_limbs_loop
  apply loop.spec_decr_nat (fun x' => n.val / 2 - x'.1.start.val)
    (fun x' : core.ops.range.Range Usize × Slice U64 =>
      x'.1.end.val = n.val / 2 ∧ x'.1.start.val ≤ n.val / 2 ∧ x'.2.length = 2 * n.val ∧
      ZeroFrom x'.2.val (2 * x'.1.start.val + n.val) ∧
      wordsNat x'.2.val = wordsNat (x.val.take (2 * x'.1.start.val)) * wordsNat y.val)
  · rintro ⟨it, w⟩ ⟨he, hs, hwl, hz, hv⟩
    simp only at he hs hwl hz hv
    unfold low.generic.limb64.mont.mul_limbs_loop.body
    step as ⟨op, iter1, hop, hend1⟩
    cases op with
    | none =>
      have h0 : it.start.val = n.val / 2 := by
        split at hop
        · simp at hop
        · scalar_tac
      simp only [WP.spec_ok]
      rw [h0] at hz hv
      exact ⟨hwl, hz, hv⟩
    | some j =>
      have hlt : it.start.val < it.end.val := by
        by_contra hc; simp [hc] at hop
      simp only [hlt, ↓reduceIte, Option.some.injEq] at hop
      obtain ⟨rfl, hst⟩ := hop
      rw [he] at hlt
      have hwL : w.val.length = 2 * n.val := hwl
      have hxL : x.val.length = n.val := hx
      have hyL : y.val.length = n.val := hy
      have hwmax : w.length ≤ Usize.max := w.property
      step as ⟨i, hi'⟩
      step as ⟨i1, hi1⟩
      step as ⟨s, back, hs', hsl, hback⟩
      step as ⟨xi, hxi⟩
      step as ⟨i3, hi3⟩
      step as ⟨xi1, hxi1⟩
      step with mul_add2_spec s y xi xi1 0#u128 (by simp) (by simp only [Slice.length] at hsl ⊢; omega)
        as ⟨rest, s1, hs1l, hs1⟩
      step as ⟨a, ha⟩
      step as ⟨z2, hz2⟩
      step as ⟨rh, hrh, _⟩
      step as ⟨i7, hi7⟩
      step as ⟨b, hb⟩
      step as ⟨s2, hs2⟩
      have hsL : s.val.length = n.val := by simp only [Slice.length] at hsl; omega
      have hs1L : s1.val.length = n.val := by simp only [Slice.length] at hs1l hsl; omega
      have hbv : (back s1).val = w.val.setSlice! i.val s1.val := by rw [hback]; simp [Slice.setSlice!_val]
      have hz2v : z2.val = (back s1).val.set (i.val + n.val) a := by rw [hz2]; simp [hi1]
      have hs2v : s2.val = z2.val.set (i.val + n.val + 1) b := by rw [hs2]; simp [hi7, hi1]
      have hbL : (back s1).val.length = 2 * n.val := by rw [hbv, List.length_setSlice!]; omega
      have hz2L : z2.val.length = 2 * n.val := by rw [hz2v, List.length_set]; exact hbL
      have hz1 : (back s1).val[i.val + n.val]!.val = 0 := by
        rw [hbv, List.getElem!_setSlice!_same _ _ _ _ (Or.inr (by omega))]; exact hz _ (by omega)
      have hz2' : z2.val[i.val + n.val + 1]!.val = 0 := by
        rw [hz2v, getElem!_set_ne' _ _ _ _ (by omega), hbv,
          List.getElem!_setSlice!_same _ _ _ _ (Or.inr (by omega))]
        exact hz _ (by omega)
      have hyt : List.take s.length y.val = y.val := List.take_of_length_le (by simp only [Slice.length]; omega)
      rw [hyt, show s.length = n.val by simp only [Slice.length]; omega] at hs1
      have hW := wordsNat_window w.val s1.val i.val (by omega)
      rw [hs1L, show w.val.slice i.val (i.val + n.val) = s.val by rw [hs', hi1]] at hW
      rw [← hbv] at hW
      have hS2 := wordsNat_set (back s1).val (i.val + n.val) a (by omega)
      rw [← hz2v, hz1] at hS2
      have hS3 := wordsNat_set z2.val (i.val + n.val + 1) b (by omega)
      rw [← hs2v, hz2'] at hS3
      have hav : a.val = rest.val % 2 ^ 64 := by rw [ha, cast_u64_val]
      have hrestb := rest.hBounds
      simp only [UScalarTy.numBits] at hrestb
      have hbv' : b.val = rest.val / 2 ^ 64 := by
        rw [hb, cast_u64_val, hrh]; simp [Nat.shiftRight_eq_div_pow]; omega
      have hrmd := Nat.mod_add_div rest.val (2 ^ 64)
      have hxi0 : xi = x.val[i.val]! := by rw [hxi, ← getElem!_pos]
      have hxi1' : xi1 = x.val[i.val + 1]! := by rw [hxi1, ← getElem!_pos, hi3]
      have hX : wordsNat (x.val.take (i.val + 2)) =
          wordsNat (x.val.take i.val) + 2 ^ (64 * i.val) * xi.val + 2 ^ (64 * (i.val + 1)) * xi1.val := by
        rw [show i.val + 2 = i.val + 1 + 1 by ring, wordsNat_take_succ' _ _ (by omega),
          wordsNat_take_succ' _ _ (by omega), hxi0, hxi1']
      refine ⟨by rw [hend1, he], by omega, ?_, ?_, ?_, by omega⟩
      · simp only [Slice.length]; rw [hs2v, List.length_set]; exact hz2L
      · intro q hq
        rw [hs2v, getElem!_set_ne' _ _ _ _ (by omega), hz2v, getElem!_set_ne' _ _ _ _ (by omega), hbv,
          List.getElem!_setSlice!_same _ _ _ _ (Or.inr (by omega))]
        exact hz _ (by omega)
      · rw [hst, show 2 * (it.start.val + 1) = i.val + 2 by omega, hX]
        rw [← hi'] at hv
        rw [hav] at hS2; rw [hbv'] at hS3
        simp only [mul_zero, add_zero] at hS2 hS3
        zify at hS3 hS2 hW hs1 hv hrmd ⊢
        linear_combination hS3 + hS2 + hW + (2 ^ (64 * i.val) : Int) * hs1 + hv +
          (2 ^ (64 * (i.val + n.val)) : Int) * hrmd
  · exact ⟨hend, hi, hzl, hzero, hval⟩

/-! ## `abs_diff` -/

theorem slice_get_spec (x : Slice U64) (i : Usize) :
    core.slice.Slice.get (core.slice.index.SliceIndexUsizeSlice U64) x i ⦃ o => o = x.val[i.val]? ⦄ := by
  simp [core.slice.Slice.get]

@[step]
theorem copied_spec (o : Option U64) :
    core.option.OptionShared0T.copied core.marker.CopyU64 o ⦃ r => r = o ⦄ := by
  simp [core.option.OptionShared0T.copied]

theorem unwrap_get (l : List U64) (i : Nat) : core.option.Option.unwrap_or l[i]? 0#u64 = l[i]! := by
  by_cases h : i < l.length
  · simp [h, getElem!_pos, core.option.Option.unwrap_or]
  · simp [h, core.option.Option.unwrap_or, List.getElem!_eq_getElem?_getD]; rfl

theorem wordsNat_take_succ_any (l : List U64) (i : Nat) :
    wordsNat (l.take (i + 1)) = wordsNat (l.take i) + 2 ^ (64 * i) * l[i]!.val := by
  by_cases h : i < l.length
  · exact wordsNat_take_succ' l i h
  · rw [List.take_of_length_le (by omega), List.take_of_length_le (by omega)]
    simp [show l.length ≤ i by omega]

/-- A limb XORed with a mask: itself, or its complement. -/
theorem xor_mask_val (a flip : U64) (h : IsMask flip) :
    (a ^^^ flip).val = if flip.val = 0 then a.val else 2 ^ 64 - 1 - a.val := by
  rcases h with h | h
  · rw [UScalar.val_xor, h]; simp
  · rw [ite_cond_eq_false _ _ (by rw [h]; simp)]
    have : flip.bv = BitVec.allOnes 64 := by
      apply BitVec.eq_of_toNat_eq; rw [BitVec.toNat_allOnes]; exact h
    show (a.bv ^^^ flip.bv).toNat = 2 ^ 64 - 1 - a.bv.toNat
    rw [this, BitVec.xor_allOnes, BitVec.toNat_not]

/-- The limbs of `l` XORed with a mask, read as a number: `l`, or its
complement. -/
def xorSum (flip : U64) (l : List U64) : Int :=
  if flip.val = 0 then wordsNat l else 2 ^ (64 * l.length) - 1 - wordsNat l

theorem xorSum_take_succ (flip : U64) (h : IsMask flip) (l : List U64) (i : Nat) (hi : i < l.length) :
    xorSum flip (l.take (i + 1)) = xorSum flip (l.take i) + 2 ^ (64 * i) * (l[i]! ^^^ flip).val := by
  unfold xorSum
  rw [xor_mask_val _ _ h, wordsNat_take_succ' _ _ hi]
  simp only [List.length_take, Nat.min_eq_left hi.le, Nat.min_eq_left (show i + 1 ≤ l.length by omega)]
  have := u64_lt l[i]!
  split
  · push_cast; ring
  · rw [Nat.cast_sub (by omega)]; push_cast
    rw [show 64 * (i + 1) = 64 * i + 64 by ring, pow_add]; ring

theorem abs_diff_loop0_spec (x y : Slice U64) (h : Nat) (hx : x.length ≤ h) (hy : y.length ≤ h)
    (iter : core.ops.range.Range Usize) (z : Slice U64) (borrow : U64)
    (hend : iter.end.val = h) (hi : iter.start.val ≤ h) (hzl : z.length = h) (hb : borrow.val ≤ 1)
    (hinv : (wordsNat (z.val.take iter.start.val) : Int) - 2 ^ (64 * iter.start.val) * borrow.val =
      wordsNat (x.val.take iter.start.val) - wordsNat (y.val.take iter.start.val)) :
    low.generic.limb64.mont.abs_diff_loop0 iter z x y borrow ⦃ r =>
      r.1.length = h ∧ r.2.val ≤ 1 ∧
      (wordsNat r.1.val : Int) - 2 ^ (64 * h) * r.2.val = wordsNat x.val - wordsNat y.val ⦄ := by
  unfold low.generic.limb64.mont.abs_diff_loop0
  apply loop.spec_decr_nat (fun x' => h - x'.1.start.val)
    (fun x' : core.ops.range.Range Usize × Slice U64 × U64 =>
      x'.1.end.val = h ∧ x'.1.start.val ≤ h ∧ x'.2.1.length = h ∧ x'.2.2.val ≤ 1 ∧
      (wordsNat (x'.2.1.val.take x'.1.start.val) : Int) - 2 ^ (64 * x'.1.start.val) * x'.2.2.val =
        wordsNat (x.val.take x'.1.start.val) - wordsNat (y.val.take x'.1.start.val))
  · rintro ⟨it, w, bw⟩ ⟨he, hs, hwl, hb, hv⟩
    simp only at he hs hwl hb hv
    unfold low.generic.limb64.mont.abs_diff_loop0.body
    step as ⟨op, iter1, hop, hend1⟩
    cases op with
    | none =>
      have h0 : it.start.val = h := by
        split at hop
        · simp at hop
        · scalar_tac
      simp only [WP.spec_ok]
      rw [h0] at hv
      have hwL : w.val.length = h := hwl
      have hxL : x.val.length ≤ h := hx
      have hyL : y.val.length ≤ h := hy
      rw [List.take_of_length_le (by omega), List.take_of_length_le (by omega),
        List.take_of_length_le (by omega)] at hv
      exact ⟨hwl, hb, hv⟩
    | some j =>
      have hlt : it.start.val < it.end.val := by
        by_contra hc; simp [hc] at hop
      simp only [hlt, ↓reduceIte, Option.some.injEq] at hop
      obtain ⟨rfl, hst⟩ := hop
      rw [he] at hlt
      have hwL : w.val.length = h := hwl
      step with slice_get_spec x it.start as ⟨o1, ho1⟩
      step as ⟨o2, ho2⟩
      step as ⟨xi, hxi⟩
      step with slice_get_spec y it.start as ⟨o3, ho3⟩
      step as ⟨o4, ho4⟩
      step as ⟨yi, hyi⟩
      step as ⟨diff, b1, hd1⟩
      step as ⟨diff1, b2, hd2⟩
      step as ⟨w1, hw1⟩
      simp only [lift, bind_ok, WP.spec_ok]
      have hxi' : xi = x.val[it.start.val]! := by rw [hxi, ho2, ho1, unwrap_get]
      have hyi' : yi = y.val[it.start.val]! := by rw [hyi, ho4, ho3, unwrap_get]
      have hstep := sub_step xi.val yi.val bw.val diff.val diff1.val b1 b2 xi.hBounds yi.hBounds hb
        (by simpa [u64_size] using hd1) (by simpa [u64_size] using hd2)
      rw [← from_bool_val] at hstep
      have hc := sub_chain_step it.start.val hv hstep
      have hw1v : w1.val = w.val.set it.start.val diff1 := by rw [hw1]; simp
      refine ⟨by rw [hend1, he], by omega, by rw [hw1]; simp at hwl ⊢; omega,
        by rw [from_bool_val]; cases (b1 || b2) <;> simp, ?_, by omega⟩
      rw [hst, hw1v, take_set_succ' _ _ _ (by omega), wordsNat_append, wordsNat_cons, wordsNat_nil,
        List.length_take, Nat.min_eq_left (by omega), wordsNat_take_succ_any, wordsNat_take_succ_any,
        ← hxi', ← hyi']
      push_cast
      linarith
  · exact ⟨hend, hi, hzl, hb, hinv⟩

theorem abs_diff_loop1_spec (z0 : Slice U64) (flip : U64) (hf : IsMask flip) (c0 : Nat)
    (iter : core.ops.range.Range Usize) (z : Slice U64) (carry : U128)
    (hend : iter.end.val = z0.length) (hi : iter.start.val ≤ z0.length) (hzl : z.length = z0.length)
    (hc : carry.val ≤ 1) (hdrop : z.val.drop iter.start.val = z0.val.drop iter.start.val)
    (hinv : (wordsNat (z.val.take iter.start.val) : Int) + 2 ^ (64 * iter.start.val) * carry.val =
      xorSum flip (z0.val.take iter.start.val) + c0) :
    low.generic.limb64.mont.abs_diff_loop1 iter z flip carry ⦃ r =>
      r.length = z0.length ∧ ∃ c : Nat, c ≤ 1 ∧
        (wordsNat r.val : Int) + 2 ^ (64 * z0.length) * c = xorSum flip z0.val + c0 ⦄ := by
  unfold low.generic.limb64.mont.abs_diff_loop1
  apply loop.spec_decr_nat (fun x' => z0.length - x'.1.start.val)
    (fun x' : core.ops.range.Range Usize × Slice U64 × U128 =>
      x'.1.end.val = z0.length ∧ x'.1.start.val ≤ z0.length ∧ x'.2.1.length = z0.length ∧ x'.2.2.val ≤ 1 ∧
      x'.2.1.val.drop x'.1.start.val = z0.val.drop x'.1.start.val ∧
      (wordsNat (x'.2.1.val.take x'.1.start.val) : Int) + 2 ^ (64 * x'.1.start.val) * x'.2.2.val =
        xorSum flip (z0.val.take x'.1.start.val) + c0)
  · rintro ⟨it, w, cy⟩ ⟨he, hs, hwl, hc, hd, hv⟩
    simp only at he hs hwl hc hd hv
    unfold low.generic.limb64.mont.abs_diff_loop1.body
    step as ⟨op, iter1, hop, hend1⟩
    cases op with
    | none =>
      have h0 : it.start.val = z0.length := by
        split at hop
        · simp at hop
        · scalar_tac
      simp only [WP.spec_ok]
      rw [h0] at hv
      have hwL : w.val.length = z0.length := hwl
      have hz0L : z0.val.length = z0.length := rfl
      rw [List.take_of_length_le (by omega), List.take_of_length_le (by omega)] at hv
      exact ⟨hwl, cy.val, hc, hv⟩
    | some j =>
      have hlt : it.start.val < it.end.val := by
        by_contra hc; simp [hc] at hop
      simp only [hlt, ↓reduceIte, Option.some.injEq] at hop
      obtain ⟨rfl, hst⟩ := hop
      rw [he] at hlt
      have hwL : w.val.length = z0.length := hwl
      have hz0L : z0.val.length = z0.length := rfl
      step as ⟨zi, hzi⟩
      simp only [lift, bind_ok]
      step as ⟨w1, hw1⟩
      step as ⟨c1, hc1, _⟩
      have hzi0 : zi = z0.val[it.start.val]! := by
        rw [hzi, ← getElem!_pos]; exact getElem!_of_drop_eq hd
      set sv := core.num.U128.wrapping_add (core.convert.num.FromU128U64.from (zi ^^^ flip)) cy with hsdef
      have hsv : sv.val = (zi ^^^ flip).val + cy.val := by
        rw [hsdef]
        have := u64_lt (zi ^^^ flip)
        simp only [core.num.U128.wrapping_add_val_eq, from_u128_val, UScalar.size, UScalarTy.numBits]
        rw [Nat.mod_eq_of_lt (by omega)]
      have hc1v : c1.val = sv.val / 2 ^ 64 := by rw [hc1]; simp [Nat.shiftRight_eq_div_pow]
      have hw1v : w1.val = w.val.set it.start.val (UScalar.cast .U64 sv) := by rw [hw1]; simp
      have hmd := Nat.mod_add_div sv.val (2 ^ 64)
      refine ⟨by rw [hend1, he], by omega, by rw [hw1]; simp at hwl ⊢; omega,
        by rw [hc1v, hsv]; have := u64_lt (zi ^^^ flip); omega, ?_, ?_, by omega⟩
      · rw [hst, hw1v, drop_set_succ']
        rw [List.drop_eq_getElem_cons (show it.start.val < w.val.length by omega),
          List.drop_eq_getElem_cons (show it.start.val < z0.val.length by omega)] at hd
        exact (List.cons.inj hd).2
      · rw [hst, hw1v, take_set_succ' _ _ _ (by omega), wordsNat_append, wordsNat_cons, wordsNat_nil,
          List.length_take, Nat.min_eq_left (by omega), cast_u64_val, hc1v,
          xorSum_take_succ _ hf _ _ (by omega), ← hzi0]
        rw [show 64 * (it.start.val + 1) = 64 * it.start.val + 64 by ring, pow_add]
        zify at hmd hsv
        push_cast at hmd hsv ⊢
        linear_combination hv + (2 ^ (64 * it.start.val) : Int) * (hmd + hsv)
  · exact ⟨hend, hi, hzl, hc, hdrop, hinv⟩

theorem wordsNat_lt_of_le (l : List U64) (h : Nat) (hl : l.length ≤ h) : wordsNat l < 2 ^ (64 * h) :=
  lt_of_lt_of_le (wordsNat_lt' l) (Nat.pow_le_pow_right (by norm_num) (by omega))

/-- `abs_diff`: `|x - y|` over `z`'s limbs, which `x` and `y` fit, and
whether `x < y`. -/
@[step]
theorem abs_diff_spec (z x y : Slice U64) (hx : x.length ≤ z.length) (hy : y.length ≤ z.length) :
    low.generic.limb64.mont.abs_diff z x y ⦃ r =>
      r.2.length = z.length ∧ r.1.val = (if wordsNat x.val < wordsNat y.val then 1 else 0) ∧
      wordsNat r.2.val = (if wordsNat x.val < wordsNat y.val then wordsNat y.val - wordsNat x.val
        else wordsNat x.val - wordsNat y.val) ⦄ := by
  unfold low.generic.limb64.mont.abs_diff
  step with abs_diff_loop0_spec x y z.length hx hy { start := 0#usize, «end» := z.len } z 0#u64
    (by simp) (by simp) rfl (by simp) (by simp [wordsNat_nil]) as ⟨z1, bw, hz1l, hbw, hz1⟩
  simp only [lift, bind_ok]
  step with abs_diff_loop1_spec z1 _ (neg_bit_mask bw hbw) bw.val { start := 0#usize, «end» := z1.len } z1
    (core.convert.num.FromU128U64.from bw) (by simp) (by simp) rfl (by rw [from_u128_val]; exact hbw) rfl
    (by simp [xorSum, wordsNat_nil, from_u128_val]) as ⟨z2, hz2l, c, hc, hz2⟩
  refine ⟨by rw [hz2l, hz1l], ?_⟩
  have hX := wordsNat_lt_of_le x.val z.length hx
  have hY := wordsNat_lt_of_le y.val z.length hy
  have hZ1 := wordsNat_lt_of_le z1.val z.length (le_of_eq hz1l)
  have hZ2 := wordsNat_lt_of_le z2.val z.length (le_of_eq (hz2l.trans hz1l))
  rw [hz1l] at hz2
  unfold xorSum at hz2
  rw [neg_bit_val bw hbw] at hz2
  rw [show z1.val.length = z.length from hz1l] at hz2
  rw [show (2 : Int) ^ (64 * z.length) = ((2 ^ (64 * z.length) : Nat) : Int) by push_cast; rfl] at hz1 hz2
  generalize 2 ^ (64 * z.length) = B at *
  rcases (show bw.val = 0 ∨ bw.val = 1 by omega) with h | h
  · simp only [h, ↓reduceIte] at hz1 hz2 ⊢
    push_cast at hz1 hz2
    have hge : ¬ wordsNat x.val < wordsNat y.val := by omega
    simp only [hge, ↓reduceIte, true_and]
    rcases (show c = 0 ∨ c = 1 by omega) with rfl | rfl <;> push_cast at hz2 <;> omega
  · simp only [h, one_ne_zero, ↓reduceIte] at hz1 hz2 ⊢
    push_cast at hz1 hz2
    have hlt : wordsNat x.val < wordsNat y.val := by omega
    simp only [hlt, ↓reduceIte, true_and]
    rcases (show c = 0 ∨ c = 1 by omega) with rfl | rfl <;> push_cast at hz2 <;> omega

end rind.portable
