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

end rind.portable
