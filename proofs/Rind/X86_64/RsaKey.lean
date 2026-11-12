import Rind.X86_64.RsaPublic
open Aeneas Aeneas.Std Result rind.spec rind.spec.rsa

/-!
# RSA public key loading on x86_64

`RsaPublicKey::new` checks the modulus and exponent and computes the
Montgomery constants the public operation takes: `pub_montifier`'s
`2^(128k) mod n`, by `k + 1` steps of Knuth's algorithm D in
`mul_word_mod`, and `mont_neg_inverse`'s `-n⁻¹ mod 2^64`. A key it returns
meets `PubKeyInv`.
-/

namespace rind.x86_64

theorem word_below_spec (x : Slice U64) (i : Usize) (hi : 1 ≤ i.val) :
    low.posint.word_below x i ⦃ r =>
      r = if i.val ≤ x.length then x.val[x.length - i.val]! else 0#u64 ⦄ := by
  unfold low.posint.word_below
  simp only [lift, bind_ok]
  have := Usize.checked_sub_bv_spec x.len i
  split
  · rename_i h
    rw [h] at this
    simp only [WP.spec_ok]
    have : ¬ i.val ≤ x.length := by scalar_tac
    simp [this]
  · rename_i j h
    rw [h] at this
    obtain ⟨hle, hj, -⟩ := this
    step as ⟨r, hr⟩
    have hle' : i.val ≤ x.length := by scalar_tac
    rw [ite_eq_left hle', hr, ← getElem!_pos]
    congr 1

/-- `mul_word_mod`'s first loop moves each word of `u` up one place, from
the top down. -/
theorem mul_word_mod_loop0_spec (u0 : Slice U64) (k : Usize) (hk : k.val = u0.length)
    (iter : core.ops.range.Range Usize) (u : Slice U64) (hend : iter.end = k) (hj1 : 1 ≤ iter.start.val)
    (hjk : iter.start.val ≤ k.val) (hl : u.length = u0.length)
    (hinv : ∀ p < u0.length,
      u.val[p]! = if k.val - iter.start.val < p then u0.val[p - 1]! else u0.val[p]!) :
    low.posint.mul_word_mod_loop0 iter u k ⦃ r => r.length = u0.length ∧
      ∀ p < u0.length, r.val[p]! = if 0 < p then u0.val[p - 1]! else u0.val[p]! ⦄ := by
  unfold low.posint.mul_word_mod_loop0
  apply loop.spec_decr_nat (fun x => k.val - x.1.start.val)
    (fun x : core.ops.range.Range Usize × Slice U64 => x.1.end = k ∧ 1 ≤ x.1.start.val ∧
      x.1.start.val ≤ k.val ∧ x.2.length = u0.length ∧
      ∀ p < u0.length, x.2.val[p]! = if k.val - x.1.start.val < p then u0.val[p - 1]! else u0.val[p]!)
  · rintro ⟨it, v⟩ ⟨he, hs1, hsk, hvl, hv⟩
    simp only at he hs1 hsk hvl hv
    unfold low.posint.mul_word_mod_loop0.body
    step as ⟨op, iter1, hop, hend1⟩
    cases op with
    | none =>
      have : it.start.val = k.val := by
        split at hop
        · simp at hop
        · rw [he] at *; scalar_tac
      simp only [WP.spec_ok]
      refine ⟨hvl, fun p hp => ?_⟩
      rw [hv p hp, this]
      simp
    | some j =>
      have hlt : it.start.val < it.end.val := by
        by_contra hc; simp [hc] at hop
      simp only [hlt, ↓reduceIte, Option.some.injEq] at hop
      obtain ⟨rfl, hst⟩ := hop
      rw [he] at hlt
      have hvL : v.length = v.val.length := rfl
      have hu0L : u0.length = u0.val.length := rfl
      step as ⟨i, hi⟩
      step as ⟨i1, hi1⟩
      step as ⟨w, hw⟩
      step as ⟨s, hs⟩
      have hsl : s.length = u0.length := by
        rw [hs]; show (v.set i w).val.length = _; rw [Slice.set_val_eq, List.length_set]; exact hvl
      have hstep : ∀ p < u0.length,
          s.val[p]! = if k.val - iter1.start.val < p then u0.val[p - 1]! else u0.val[p]! := by
        intro p hp
        rw [hs, Slice.set_val_eq]
        by_cases hpi : p = i.val
        · subst hpi
          rw [getElem!_set_of_lt _ _ _ _ (by omega), ite_eq_left rfl, hw, ← getElem!_pos, hv _ (by omega),
            ite_eq_right (by scalar_tac), ite_eq_left (by scalar_tac), hi1]
        · rw [getElem!_set_of_lt _ _ _ _ (by omega), ite_eq_right hpi, hv p hp]
          have : (k.val - it.start.val < p) ↔ (k.val - iter1.start.val < p) := by scalar_tac
          simp only [this]
      split_ands <;> first | exact hsl | exact hstep | scalar_tac
  · exact ⟨hend, hj1, hjk, hl, hinv⟩

/-- Two words as a `u128`: `(hi << 64) | lo`. -/
theorem pair_val (a b : Nat) (ha : a < 2 ^ 64) (hb : b < 2 ^ 64) :
    (a <<< 64) % 2 ^ 128 ||| b = a * 2 ^ 64 + b := by
  have : a * 2 ^ 64 < 2 ^ 128 := by
    calc a * 2 ^ 64 < 2 ^ 64 * 2 ^ 64 := Nat.mul_lt_mul_of_pos_right ha (by positivity)
      _ = 2 ^ 128 := by norm_num
  rw [Nat.shiftLeft_eq, Nat.mod_eq_of_lt this, ← Nat.shiftLeft_eq, ← Nat.shiftLeft_add_eq_or_of_lt hb,
    Nat.shiftLeft_eq]

/-- `mul_word_mod`'s second loop lowers the quotient estimate `q` while
it times the divisor's top two words `D2` exceeds the dividend's top three
`T`, keeping `rem = num - q·d1` below `2^64`. `P` holds of each `q` it
passes, and a `q` too large keeps it for `q - 1`. -/
theorem mul_word_mod_loop1_spec (d1 d0 u0 : U64) (num T D2 : Nat) (hd1 : 0 < d1.val)
    (hD2 : D2 = d1.val * 2 ^ 64 + d0.val) (hT : T = num * 2 ^ 64 + u0.val) (P : Nat → Prop)
    (hdec : ∀ q, P q → T < q * D2 → P (q - 1)) (q rem : U128) (hq : q.val < 2 ^ 64)
    (hnum : q.val * d1.val + rem.val = num) (hP : P q.val) :
    low.posint.mul_word_mod_loop1 d1 d0 u0 q rem ⦃ q1 => q1.val * D2 ≤ T ∧ P q1.val ∧ q1.val ≤ q.val ⦄ := by
  unfold low.posint.mul_word_mod_loop1
  have hd0 := d0.hBounds
  have hu0 := u0.hBounds
  have hd1' := d1.hBounds
  apply loop.spec_decr_nat (fun x : U128 × U128 => x.1.val)
    (fun x : U128 × U128 => x.1.val < 2 ^ 64 ∧ x.1.val * d1.val + x.2.val = num ∧ P x.1.val ∧
      x.1.val ≤ q.val)
  · rintro ⟨q', r'⟩ ⟨hq', hn', hP', hle⟩
    simp only at hq' hn' hP' hle
    unfold low.posint.mul_word_mod_loop1.body
    -- `q'·D2 ≤ T` exactly when `q'·d0 ≤ r'·2^64 + u0`.
    have hkey : q'.val * D2 ≤ T ↔ q'.val * d0.val ≤ r'.val * 2 ^ 64 + u0.val := by
      rw [hD2, hT, ← hn']
      constructor <;> intro h <;> nlinarith
    step as ⟨i, hi, _⟩
    split
    · rename_i hi0
      have hr : r'.val < 2 ^ 64 := by
        have : i.val = 0 := by simpa using congrArg UScalar.val hi0
        rw [hi, Nat.shiftRight_eq_div_pow] at this
        exact (Nat.div_eq_zero_iff_lt (by positivity)).mp this
      simp only [lift, bind_ok]
      have hd0b : d0.val < 2 ^ 64 := by scalar_tac
      have hu0b : u0.val < 2 ^ 64 := by scalar_tac
      have hd1b : d1.val < 2 ^ 64 := by scalar_tac
      step as ⟨i2, hi2⟩
      step as ⟨i3, hi3, _⟩
      have hsz : U128.size = 2 ^ 128 := by simp [U128.size, U128.numBits]
      rw [hsz] at hi3
      have hi5 : (i3 ||| core.convert.num.FromU128U64.from u0).val = r'.val * 2 ^ 64 + u0.val := by
        rw [UScalar.val_or, hi3, core.convert.num.FromU128U64.from_val_eq]
        exact pair_val _ _ hr hu0b
      rw [core.convert.num.FromU128U64.from_val_eq] at hi2
      split
      · rename_i hgt
        have hgt' : r'.val * 2 ^ 64 + u0.val < q'.val * d0.val := by
          rw [← hi5, ← hi2]; exact hgt
        have hq1 : 1 ≤ q'.val := by
          rcases Nat.eq_zero_or_pos q'.val with h0 | h0
          · rw [h0] at hgt'; omega
          · exact h0
        step as ⟨q1, hq1v⟩
        step as ⟨rem1, hrem1⟩
        have heq : q1.val * d1.val + rem1.val = num := by
          rw [hq1v, hrem1, core.convert.num.FromU128U64.from_val_eq, ← hn']
          have : q'.val = (q'.val - 1) + 1 := by omega
          conv_rhs => rw [this]
          ring_nf
        have hP1 : P q1.val := by
          rw [hq1v]
          exact hdec _ hP' (by
            by_contra hc; push Not at hc
            have := hkey.mp hc; omega)
        split_ands <;> first | exact heq | exact hP1 | omega
      · rename_i hle'
        simp only [WP.spec_ok]
        refine ⟨hkey.mpr ?_, hP', hle⟩
        rw [← hi5, ← hi2]
        exact Nat.le_of_not_lt hle'
    · rename_i hi0
      have hr : 2 ^ 64 ≤ r'.val := by
        by_contra hc
        apply hi0
        rw [UScalar.eq_equiv, hi, Nat.shiftRight_eq_div_pow, Nat.div_eq_of_lt (by omega)]
        rfl
      simp only [WP.spec_ok]
      refine ⟨hkey.mpr ?_, hP', hle⟩
      have : q'.val * d0.val < 2 ^ 64 * 2 ^ 64 := Nat.mul_lt_mul'' hq' (by scalar_tac)
      nlinarith
  · exact ⟨hq, hnum, hP, le_refl _⟩

theorem lift_spec {α : Type} (x : α) : lift x ⦃ r => r = x ⦄ := by simp [lift]

theorem wordsNat_take_succ (l : List U64) (i : Nat) (hi : i < l.length) :
    wordsNat (l.take (i + 1)) = wordsNat (l.take i) + 2 ^ (64 * i) * l[i]!.val := by
  rw [List.take_succ, List.getElem?_eq_getElem hi, Option.toList_some, wordsNat_append, wordsNat_cons,
    wordsNat_nil, List.length_take, getElem!_pos l i hi, Nat.min_eq_left hi.le]
  ring

/-- One word of a subtraction with borrow, as two `overflowing_sub`s. -/
theorem sub_word (sw lo bw diff0 diff1 : Nat) (b1 b2 : Bool) (hsw : sw < 2 ^ 64) (hlo : lo < 2 ^ 64)
    (hbw : bw ≤ 1)
    (h1 : if sw < lo then diff0 + lo = sw + 2 ^ 64 ∧ b1 = true else diff0 = sw - lo ∧ b1 = false)
    (h2 : if diff0 < bw then diff1 + bw = diff0 + 2 ^ 64 ∧ b2 = true else diff1 = diff0 - bw ∧ b2 = false) :
    (sw : Int) - lo - bw = diff1 - 2 ^ 64 * (b1 || b2).toNat := by
  split_ifs at h1 h2 <;> obtain ⟨h1, rfl⟩ := h1 <;> obtain ⟨h2, rfl⟩ := h2 <;> simp <;> omega

/-- `mul_word_mod`'s third loop subtracts `q·d` from `s0`'s words, keeping
the carry word of `q·d` and the borrow apart. -/
theorem mul_word_mod_loop2_spec (s0 d : Slice U64) (q : U128) (hq : q.val < 2 ^ 64) (k : Usize)
    (hk : k.val = d.length) (hs0 : s0.length = d.length) (iter : core.ops.range.Range Usize)
    (u : Slice U64) (carry : U64) (borrow : Bool) (hend : iter.end = k) (hik : iter.start.val ≤ k.val)
    (hul : u.length = d.length) (hhi : ∀ p, iter.start.val ≤ p → p < d.length → u.val[p]! = s0.val[p]!)
    (hinv : (wordsNat (s0.val.take iter.start.val) : Int) - q.val * wordsNat (d.val.take iter.start.val) =
      wordsNat (u.val.take iter.start.val) - 2 ^ (64 * iter.start.val) * (carry.val + borrow.toNat)) :
    low.posint.mul_word_mod_loop2 iter u d q carry borrow ⦃ r => r.1.length = d.length ∧
      (wordsNat s0.val : Int) - q.val * wordsNat d.val =
        wordsNat r.1.val - 2 ^ (64 * d.length) * (r.2.1.val + r.2.2.toNat) ⦄ := by
  unfold low.posint.mul_word_mod_loop2
  have hdL : d.length = d.val.length := rfl
  have hs0L : s0.length = s0.val.length := rfl
  apply loop.spec_decr_nat (fun x => k.val - x.1.start.val)
    (fun x : core.ops.range.Range Usize × Slice U64 × U64 × Bool => x.1.end = k ∧
      x.1.start.val ≤ k.val ∧ x.2.1.length = d.length ∧
      (∀ p, x.1.start.val ≤ p → p < d.length → x.2.1.val[p]! = s0.val[p]!) ∧
      (wordsNat (s0.val.take x.1.start.val) : Int) - q.val * wordsNat (d.val.take x.1.start.val) =
        wordsNat (x.2.1.val.take x.1.start.val) - 2 ^ (64 * x.1.start.val) * (x.2.2.1.val + x.2.2.2.toNat))
  · rintro ⟨it, v, c, b⟩ ⟨he, hsk, hvl, hv, hid⟩
    simp only at he hsk hvl hv hid
    have hvL : v.length = v.val.length := rfl
    unfold low.posint.mul_word_mod_loop2.body
    step as ⟨op, iter1, hop, hend1⟩
    cases op with
    | none =>
      have : it.start.val = k.val := by
        split at hop
        · simp at hop
        · rw [he] at *; scalar_tac
      simp only [WP.spec_ok]
      refine ⟨hvl, ?_⟩
      rw [this, hk] at hid
      rw [List.take_of_length_le (by omega), List.take_of_length_le (by omega),
        List.take_of_length_le (by omega)] at hid
      exact hid
    | some i =>
      have hlt : it.start.val < it.end.val := by
        by_contra hc; simp [hc] at hop
      simp only [hlt, ↓reduceIte, Option.some.injEq] at hop
      obtain ⟨rfl, hst⟩ := hop
      rw [he] at hlt
      step as ⟨dw, hdw⟩
      have hdwb : dw.val < 2 ^ 64 := by scalar_tac
      have hcb : c.val < 2 ^ 64 := by scalar_tac
      have hmul : q.val * dw.val < 2 ^ 128 - 2 ^ 64 := by
        have : q.val * dw.val ≤ (2 ^ 64 - 1) * (2 ^ 64 - 1) := Nat.mul_le_mul (by omega) (by omega)
        omega
      step with lift_spec as ⟨i2, hi2⟩
      step as ⟨i3, hi3⟩
      step with lift_spec as ⟨i4, hi4⟩
      step as ⟨product, hprod⟩
      step as ⟨i5, hi5, _⟩
      step with lift_spec as ⟨carry1, hcarry1⟩
      step as ⟨sw, hsw⟩
      step with lift_spec as ⟨lo, hlo⟩
      step with lift_spec as ⟨diff, b1, h1⟩
      step with lift_spec as ⟨i8, hi8⟩
      step with lift_spec as ⟨diff1, b2, h2⟩
      step as ⟨s1, hs1⟩
      have ho1 := core.num.U64.overflowing_sub_eq sw lo
      rw [← h1] at ho1
      have ho2 := core.num.U64.overflowing_sub_eq diff i8
      rw [← h2] at ho2
      simp only [UScalar.size, UScalarTy.numBits] at ho1 ho2
      have hlov : lo.val = product.val % 2 ^ 64 := by rw [hlo, UScalar.cast_val_eq]; rfl
      have hi8v : i8.val = b.toNat := by rw [hi8]; cases b <;> rfl
      rw [hlov] at ho1
      rw [hi8v] at ho2
      have hword := sub_word sw.val (product.val % 2 ^ 64) b.toNat diff.val diff1.val b1 b2 (by scalar_tac)
        (Nat.mod_lt _ (by positivity)) (by cases b <;> simp) ho1 ho2
      have hpv : product.val = q.val * dw.val + c.val := by
        rw [hprod, hi3, hi2, hi4, core.convert.num.FromU128U64.from_val_eq,
          core.convert.num.FromU128U64.from_val_eq]
      have hc1 : carry1.val = product.val / 2 ^ 64 := by
        rw [hcarry1, UScalar.cast_val_eq, hi5]
        show (product.val >>> 64) % 2 ^ 64 = _
        rw [Nat.shiftRight_eq_div_pow]
        apply Nat.mod_eq_of_lt
        rw [Nat.div_lt_iff_lt_mul (by positivity)]
        omega
      have hsw' : sw.val = (s0.val[it.start.val]!).val := by
        rw [hsw, ← getElem!_pos, hv _ (le_refl _) (by omega)]
      have hdw' : dw.val = (d.val[it.start.val]!).val := by rw [hdw, ← getElem!_pos]
      have hs1v : s1.val = v.val.set it.start.val diff1 := by rw [hs1, Slice.set_val_eq]
      have hs1l : s1.length = d.length := by
        show s1.val.length = _; rw [hs1v, List.length_set]; exact hvl
      have hhi1 : ∀ p, iter1.start.val ≤ p → p < d.length → s1.val[p]! = s0.val[p]! := by
        intro p hp1 hp2
        rw [hs1v, getElem!_set_of_lt _ _ _ _ (by omega), ite_eq_right (by omega)]
        exact hv p (by omega) hp2
      have hid1 : (wordsNat (s0.val.take iter1.start.val) : Int) -
          q.val * wordsNat (d.val.take iter1.start.val) =
          wordsNat (s1.val.take iter1.start.val) -
            2 ^ (64 * iter1.start.val) * (carry1.val + (b1 || b2).toNat) := by
        rw [hst, wordsNat_take_succ _ _ (by omega), wordsNat_take_succ _ _ (by omega),
          wordsNat_take_succ _ _ (by rw [hs1v, List.length_set]; omega), hs1v,
          List.take_set_of_le (le_refl _), getElem!_set_of_lt _ _ _ _ (by omega), ite_eq_left rfl,
          ← hsw', ← hdw', hc1, hpv]
        have hdm := Nat.div_add_mod product.val (2 ^ 64)
        rw [hpv] at hdm
        have hX : (2 : Int) ^ (64 * (it.start.val + 1)) = 2 ^ (64 * it.start.val) * 2 ^ 64 := by
          rw [Nat.mul_succ, pow_add]
        push_cast
        rw [hX]
        rw [hpv] at hword
        have hdmI : ((2 ^ 64 * ((q.val * dw.val + c.val) / 2 ^ 64) + (q.val * dw.val + c.val) % 2 ^ 64 : Nat) : Int)
            = q.val * dw.val + c.val := by exact_mod_cast hdm
        push_cast at hdmI hword
        linear_combination hid + 2 ^ (64 * it.start.val) * hword + 2 ^ (64 * it.start.val) * hdmI
      split_ands <;> first | exact hs1l | exact hhi1 | exact hid1 | scalar_tac
  · exact ⟨hend, hik, hul, hhi, hinv⟩

/-- One word of an addition with carry, as two `overflowing_add`s. -/
theorem add_word (x y c sum0 sum1 : Nat) (c1 c2 : Bool) (hx : x < 2 ^ 64) (hy : y < 2 ^ 64) (hc : c ≤ 1)
    (h1 : if x + y > 2 ^ 64 - 1 then sum0 + 2 ^ 64 = x + y ∧ c1 = true else sum0 = x + y ∧ c1 = false)
    (h2 : if sum0 + c > 2 ^ 64 - 1 then sum1 + 2 ^ 64 = sum0 + c ∧ c2 = true else sum1 = sum0 + c ∧ c2 = false) :
    x + y + c = sum1 + 2 ^ 64 * (c1 || c2).toNat := by
  split_ifs at h1 h2 <;> obtain ⟨h1, rfl⟩ := h1 <;> obtain ⟨h2, rfl⟩ := h2 <;> simp <;> omega

/-- `mul_word_mod`'s last loop adds `d` back to `u0`, dropping the carry
out of the top word. -/
theorem mul_word_mod_loop3_spec (u0 d : Slice U64) (k : Usize) (hk : k.val = d.length)
    (hu0 : u0.length = d.length) (iter : core.ops.range.Range Usize) (u : Slice U64) (carry : Bool)
    (hend : iter.end = k) (hik : iter.start.val ≤ k.val) (hul : u.length = d.length)
    (hhi : ∀ p, iter.start.val ≤ p → p < d.length → u.val[p]! = u0.val[p]!)
    (hinv : wordsNat (u.val.take iter.start.val) + 2 ^ (64 * iter.start.val) * carry.toNat =
      wordsNat (u0.val.take iter.start.val) + wordsNat (d.val.take iter.start.val)) :
    low.posint.mul_word_mod_loop3 iter u d carry ⦃ r => r.length = d.length ∧
      wordsNat r.val = (wordsNat u0.val + wordsNat d.val) % 2 ^ (64 * d.length) ⦄ := by
  unfold low.posint.mul_word_mod_loop3
  have hdL : d.length = d.val.length := rfl
  have hu0L : u0.length = u0.val.length := rfl
  apply loop.spec_decr_nat (fun x => k.val - x.1.start.val)
    (fun x : core.ops.range.Range Usize × Slice U64 × Bool => x.1.end = k ∧
      x.1.start.val ≤ k.val ∧ x.2.1.length = d.length ∧
      (∀ p, x.1.start.val ≤ p → p < d.length → x.2.1.val[p]! = u0.val[p]!) ∧
      wordsNat (x.2.1.val.take x.1.start.val) + 2 ^ (64 * x.1.start.val) * x.2.2.toNat =
        wordsNat (u0.val.take x.1.start.val) + wordsNat (d.val.take x.1.start.val))
  · rintro ⟨it, v, c⟩ ⟨he, hsk, hvl, hv, hid⟩
    simp only at he hsk hvl hv hid
    have hvL : v.length = v.val.length := rfl
    unfold low.posint.mul_word_mod_loop3.body
    step as ⟨op, iter1, hop, hend1⟩
    cases op with
    | none =>
      have : it.start.val = k.val := by
        split at hop
        · simp at hop
        · rw [he] at *; scalar_tac
      simp only [WP.spec_ok]
      refine ⟨hvl, ?_⟩
      rw [this, hk] at hid
      rw [List.take_of_length_le (by omega), List.take_of_length_le (by omega),
        List.take_of_length_le (by omega)] at hid
      have hlt := wordsNat_lt' v.val
      rw [← hvL, hvl] at hlt
      rw [← hid, Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt hlt]
    | some i =>
      have hlt : it.start.val < it.end.val := by
        by_contra hc; simp [hc] at hop
      simp only [hlt, ↓reduceIte, Option.some.injEq] at hop
      obtain ⟨rfl, hst⟩ := hop
      rw [he] at hlt
      step as ⟨x, hx⟩
      step as ⟨y, hy⟩
      step with lift_spec as ⟨sum0, c1, h1⟩
      step with lift_spec as ⟨i3, hi3⟩
      step with lift_spec as ⟨sum1, c2, h2⟩
      step as ⟨s1, hs1⟩
      have ho1 := core.num.U64.overflowing_add_eq x y
      rw [← h1] at ho1
      have ho2 := core.num.U64.overflowing_add_eq sum0 i3
      rw [← h2] at ho2
      simp only [UScalar.size, UScalar.max, UScalarTy.numBits] at ho1 ho2
      have hi3v : i3.val = c.toNat := by rw [hi3]; cases c <;> rfl
      rw [hi3v] at ho2
      have hword := add_word x.val y.val c.toNat sum0.val sum1.val c1 c2 (by scalar_tac) (by scalar_tac)
        (by cases c <;> simp) ho1 ho2
      have hx' : x.val = (u0.val[it.start.val]!).val := by
        rw [hx, ← getElem!_pos, hv _ (le_refl _) (by omega)]
      have hy' : y.val = (d.val[it.start.val]!).val := by rw [hy, ← getElem!_pos]
      have hs1v : s1.val = v.val.set it.start.val sum1 := by rw [hs1, Slice.set_val_eq]
      have hs1l : s1.length = d.length := by
        show s1.val.length = _; rw [hs1v, List.length_set]; exact hvl
      have hhi1 : ∀ p, iter1.start.val ≤ p → p < d.length → s1.val[p]! = u0.val[p]! := by
        intro p hp1 hp2
        rw [hs1v, getElem!_set_of_lt _ _ _ _ (by omega), ite_eq_right (by omega)]
        exact hv p (by omega) hp2
      have hid1 : wordsNat (s1.val.take iter1.start.val) + 2 ^ (64 * iter1.start.val) * (c1 || c2).toNat =
          wordsNat (u0.val.take iter1.start.val) + wordsNat (d.val.take iter1.start.val) := by
        rw [hst, wordsNat_take_succ s1.val _ (by rw [hs1v, List.length_set]; omega),
          wordsNat_take_succ u0.val _ (by omega), wordsNat_take_succ d.val _ (by omega), hs1v,
          List.take_set_of_le (le_refl _), getElem!_set_of_lt _ _ _ _ (by omega), ite_eq_left rfl,
          ← hx', ← hy', Nat.mul_succ, pow_add]
        zify at hid hword ⊢
        linear_combination hid - 2 ^ (64 * it.start.val) * hword
      split_ands <;> first | exact hs1l | exact hhi1 | exact hid1 | scalar_tac
  · exact ⟨hend, hik, hul, hhi, hinv⟩

theorem mul_word_mod_loop4_eq (iter : core.ops.range.Range Usize) (u d : Slice U64) (carry : Bool) :
    low.posint.mul_word_mod_loop4 iter u d carry = low.posint.mul_word_mod_loop3 iter u d carry := by
  unfold low.posint.mul_word_mod_loop4 low.posint.mul_word_mod_loop3 low.posint.mul_word_mod_loop4.body
    low.posint.mul_word_mod_loop3.body
  rfl

/-- A number's top word above the rest. -/
theorem wordsNat_top (l : List U64) (k : Nat) (hk : l.length = k + 1) :
    wordsNat l = wordsNat (l.take k) + 2 ^ (64 * k) * (l[k]!).val := by
  rw [← wordsNat_take_succ _ _ (by omega), List.take_of_length_le (by omega)]

/-- The words below the top two, shifted up a word, are the third word
from the top (or zero) above a remainder. -/
theorem wordsNat_third (l : List U64) (k : Nat) (hk : l.length = k + 2) :
    ∃ r, r < 2 ^ (64 * k) ∧ wordsNat (l.take k) * 2 ^ 64 =
      (if 1 ≤ k then (l[k - 1]!).val else 0) * 2 ^ (64 * k) + r := by
  rcases Nat.eq_zero_or_pos k with rfl | hk1
  · exact ⟨0, by norm_num, by simp [wordsNat_nil]⟩
  · obtain ⟨j, rfl⟩ : ∃ j, k = j + 1 := ⟨k - 1, by omega⟩
    refine ⟨wordsNat (l.take j) * 2 ^ 64, ?_, ?_⟩
    · have := wordsNat_lt' (l.take j)
      rw [List.length_take, Nat.min_eq_left (by omega)] at this
      rw [Nat.mul_succ, pow_add]
      exact Nat.mul_lt_mul_of_pos_right this (by positivity)
    · rw [wordsNat_take_succ _ _ (by omega), ite_eq_left (by omega), Nat.add_sub_cancel, Nat.mul_succ, pow_add]
      ring

/-- The arithmetic of one step of algorithm D on `U·B` over `D`, both laid
out by their top words over `S`: the first estimate bounds the quotient
from above, and the refined one meets `knuth_le_succ`'s conditions. -/
theorem knuth_step {B S U D u2 u1 u0 d1 d0 Ut2 Dt2 rN : Nat} (hB : 0 < B) (hu1 : u1 < B) (hu0 : u0 < B)
    (hd1 : 0 < d1) (hd0 : d0 < B) (hU : U = Ut2 + S * u1 + S * B * u2) (hUt2 : Ut2 < S)
    (hD : D = Dt2 + S * d0 + S * B * d1) (hDt2 : Dt2 < S) (hrN : Ut2 * B = u0 * S + rN)
    (hUD : U < D) :
    U * B = ((u2 * B + u1) * B + u0) * S + rN ∧ D = (d1 * B + d0) * S + Dt2 ∧
      U * B / D ≤ (if u2 < d1 then (u2 * B + u1) / d1 else B - 1) ∧ B ≤ d1 * B + d0 ∧
      (u2 * B + u1) * B + u0 < (d1 * B + d0 + 1) * B ∧
      (if u2 < d1 then (u2 * B + u1) / d1 else B - 1) < B ∧
      (if u2 < d1 then (u2 * B + u1) / d1 else B - 1) * d1 ≤ u2 * B + u1 := by
  have hS : 0 < S := by omega
  have hW : U * B = ((u2 * B + u1) * B + u0) * S + rN := by rw [hU]; nlinarith
  have hD' : D = (d1 * B + d0) * S + Dt2 := by rw [hD]; ring
  -- `u2·B + u1` is at most `D2`, as `U < D`.
  have hnum : u2 * B + u1 ≤ d1 * B + d0 := by
    have h1 : (u2 * B + u1) * S ≤ U := by rw [hU]; nlinarith
    have h2 : D < (d1 * B + d0 + 1) * S := by rw [hD']; nlinarith
    have := Nat.lt_of_mul_lt_mul_right (lt_of_le_of_lt h1 (lt_trans hUD h2))
    omega
  have hu2d1 : u2 ≤ d1 := by
    by_contra hc
    push Not at hc
    have : (d1 + 1) * B ≤ u2 * B := Nat.mul_le_mul_right _ hc
    nlinarith
  refine ⟨hW, hD', ?_, by nlinarith, by nlinarith, ?_, ?_⟩
  · have := knuth_q0_ge (B := B) (S := S * B) (T2 := u2 * B + u1) (rU := Ut2 * B) (D := D) (d1 := d1)
      (Nat.mul_lt_mul_of_pos_right hUt2 hB) (by rw [hD']; nlinarith) (by nlinarith) hd1
    have hdiv : (u2 * B + u1) / B = u2 := by
      rw [Nat.add_comm, Nat.add_mul_div_right _ _ hB, Nat.div_eq_of_lt hu1, Nat.zero_add]
    rw [hdiv] at this
    have hE : (u2 * B + u1) * (S * B) + Ut2 * B = U * B := by rw [hU]; ring
    rw [hE] at this
    exact this
  · split
    · rename_i h
      rw [Nat.div_lt_iff_lt_mul hd1]
      nlinarith
    · omega
  · split
    · exact Nat.div_mul_le_self _ _
    · rename_i h
      have : u2 = d1 := by omega
      subst this
      have : (B - 1) * u2 ≤ u2 * B := by
        rw [Nat.sub_mul, Nat.one_mul, Nat.mul_comm]; omega
      omega

/-- `mul_word_mod` replaces `u` with `u·2^64 mod d`, for `u` below `d`, as
wide, of at least two words, `d`'s top word nonzero. -/
theorem mul_word_mod_spec (u d : Slice U64) (hk2 : 2 ≤ d.length) (hu : u.length = d.length)
    (hd1 : 0 < (d.val[d.length - 1]!).val) (hud : wordsNat u.val < wordsNat d.val) :
    low.posint.mul_word_mod u d ⦃ r => r.length = d.length ∧
      wordsNat r.val = wordsNat u.val * 2 ^ 64 % wordsNat d.val ⦄ := by
  have hdL : d.length = d.val.length := rfl
  have huL : u.length = u.val.length := rfl
  unfold low.posint.mul_word_mod
  dsimp only
  split
  · rename_i h0
    have : d.len.val = 0 := by rw [h0]; rfl
    have : d.len.val = d.length := rfl
    omega
  · have hkv : d.len.val = d.length := rfl
    step as ⟨i, hi⟩
    step as ⟨d1, hd1v⟩
    step with word_below_spec d 2#usize (by decide) as ⟨d0, hd0v⟩
    step with word_below_spec u 1#usize (by decide) as ⟨u2, hu2v⟩
    step with word_below_spec u 2#usize (by decide) as ⟨u1, hu1v⟩
    step with word_below_spec u 3#usize (by decide) as ⟨u0, hu0v⟩
    rw [hkv] at hi
    have hd1' : d1 = d.val[d.length - 1]! := by rw [hd1v, ← getElem!_pos, hi]
    rw [ite_eq_left hk2] at hd0v
    rw [ite_eq_left (by omega)] at hu2v hu1v
    step with mul_word_mod_loop0_spec u d.len (by rw [hkv, hu]) { start := 1#usize, «end» := d.len } u rfl
      (by show 1 ≤ 1; omega) (by show 1 ≤ d.len.val; omega) rfl (fun p hp => by
        rw [ite_eq_right (by show ¬ d.len.val - 1 < p; omega)]) as ⟨u3, hu3l, hu3⟩
    step as ⟨s, hs⟩
    have hu3L : u3.length = u3.val.length := rfl
    have hsv : s.val = 0#u64 :: u.val.take (d.length - 1) := by
      have hsl : s.val.length = d.length := by
        rw [hs, Slice.set_val_eq, List.length_set, ← hu3L, hu3l, hu]
      apply List.ext_getElem
      · rw [hsl, List.length_cons, List.length_take]; omega
      · intro p h1 h2
        rw [← getElem!_pos, ← getElem!_pos, hs, Slice.set_val_eq, getElem!_set_of_lt _ _ _ _ (by omega)]
        cases p with
        | zero => simp
        | succ q =>
          rw [ite_eq_right (by simp), hu3 (q + 1) (by omega), ite_eq_left (by omega)]
          simp only [List.getElem!_cons_succ, Nat.add_sub_cancel]
          rw [List.getElem!_take_of_lt _ _ _ (by omega)]
    -- `W = u·2^64` is `u2` above `s`.
    have hUtop := wordsNat_top u.val (d.length - 1) (by omega)
    have hsN : wordsNat s.val = wordsNat (u.val.take (d.length - 1)) * 2 ^ 64 := by
      rw [hsv, wordsNat_cons]; simp; ring
    step with lift_spec as ⟨i1, hi1⟩
    step as ⟨i2, hi2, _⟩
    step with lift_spec as ⟨i3, hi3⟩
    step with lift_spec as ⟨num, hnum⟩
    have hsz : U128.size = 2 ^ 128 := by simp [U128.size, U128.numBits]
    rw [hsz] at hi2
    have hu2b : u2.val < 2 ^ 64 := by scalar_tac
    have hu1b : u1.val < 2 ^ 64 := by scalar_tac
    have hd1b : d1.val < 2 ^ 64 := by scalar_tac
    have hnumv : num.val = u2.val * 2 ^ 64 + u1.val := by
      rw [hnum, UScalar.val_or, hi2, hi1, hi3, core.convert.num.FromU128U64.from_val_eq,
        core.convert.num.FromU128U64.from_val_eq]
      exact pair_val _ _ hu2b hu1b
    have hd1p : 0 < d1.val := by rw [hd1']; exact hd1
    apply WP.spec_bind (Pₘ := fun q : U128 =>
      q.val = if u2.val < d1.val then num.val / d1.val else 2 ^ 64 - 1)
    · split
      · rename_i hlt
        step with lift_spec as ⟨i4, hi4⟩
        step as ⟨q, hq⟩
        rw [ite_eq_left (by scalar_tac), hq, hi4, core.convert.num.FromU128U64.from_val_eq]
      · rename_i hlt
        simp only [WP.spec_ok]
        rw [ite_eq_right (by scalar_tac), core.convert.num.FromU128U64.from_val_eq]
        rfl
    intro q hq
    -- Lay `u` and `d` out by their top words over `S = 2^(64(k-2))`.
    have hu2' : u2.val = (u.val[d.length - 1]!).val := by rw [hu2v, hu]
    have hu1' : u1.val = (u.val[d.length - 2]!).val := by rw [hu1v, hu]
    have hd0' : d0.val = (d.val[d.length - 2]!).val := by rw [hd0v]
    have hd1'' : d1.val = (d.val[d.length - 1]!).val := by rw [hd1']
    have hlay : ∀ (l : List U64), l.length = d.length →
        wordsNat l = wordsNat (l.take (d.length - 2)) + 2 ^ (64 * (d.length - 2)) * (l[d.length - 2]!).val +
          2 ^ (64 * (d.length - 2)) * 2 ^ 64 * (l[d.length - 1]!).val := by
      intro l hl
      have h1 := wordsNat_top l (d.length - 1) (by omega)
      have h2 := wordsNat_take_succ l (d.length - 2) (by omega)
      rw [show d.length - 2 + 1 = d.length - 1 by omega] at h2
      rw [h1, h2, show 64 * (d.length - 1) = 64 * (d.length - 2) + 64 by omega, pow_add]
    have hU := hlay u.val (by omega)
    have hD := hlay d.val (by omega)
    rw [← hu2', ← hu1'] at hU
    rw [← hd1'', ← hd0'] at hD
    have hUt2 := wordsNat_lt' (u.val.take (d.length - 2))
    have hDt2 := wordsNat_lt' (d.val.take (d.length - 2))
    rw [List.length_take, Nat.min_eq_left (by omega)] at hUt2 hDt2
    obtain ⟨rN, hrN, hrNe⟩ := wordsNat_third u.val (d.length - 2) (by omega)
    have hu0' : (if 1 ≤ d.length - 2 then (u.val[d.length - 2 - 1]!).val else 0) = u0.val := by
      rw [hu0v, hu]
      by_cases h3 : 3 ≤ d.length
      · rw [ite_eq_left (by omega), ite_eq_left h3, show d.length - 2 - 1 = d.length - 3 by omega]
      · rw [ite_eq_right (by omega), ite_eq_right h3]; rfl
    rw [hu0'] at hrNe
    have hu0b : u0.val < 2 ^ 64 := by scalar_tac
    have hd0b : d0.val < 2 ^ 64 := by scalar_tac
    obtain ⟨hW, hD2, hq0, hBD2, hT, hq0B, hq0d1⟩ := knuth_step (B := 2 ^ 64) (by positivity) hu1b hu0b
      hd1p hd0b hU hUt2 hD hDt2 hrNe hud
    rw [← hnumv] at hW hq0 hT hq0B hq0d1
    rw [← hq] at hq0 hq0B hq0d1
    step with lift_spec as ⟨i4, hi4⟩
    step as ⟨i5, hi5⟩
    rw [hi4, core.convert.num.FromU128U64.from_val_eq] at hi5
    step as ⟨rem, hrem⟩
    have hDpos : 0 < wordsNat d.val := by omega
    step with mul_word_mod_loop1_spec d1 d0 u0 num.val (num.val * 2 ^ 64 + u0.val) (d1.val * 2 ^ 64 + d0.val)
      hd1p rfl rfl (fun x => wordsNat u.val * 2 ^ 64 / wordsNat d.val ≤ x)
      (fun x _ hlt => by
        have := knuth_gt (rD := wordsNat (d.val.take (d.length - 2))) hrN x hlt
        rw [← hW, ← hD2] at this
        show _ ≤ x - 1
        omega)
      q rem hq0B (by rw [hrem, hi5]; omega) hq0 as ⟨q1, hq1T, hq1P, hq1le⟩
    have hq1up : q1.val ≤ wordsNat u.val * 2 ^ 64 / wordsNat d.val + 1 := by
      have := knuth_le_succ (S := 2 ^ (64 * (d.length - 2))) (rN := rN) hDt2 (by positivity) hBD2 hT q1.val hq1T
      rwa [← hW, ← hD2] at this
    have hsl : s.length = d.length := by
      show s.val.length = _; rw [hsv, List.length_cons, List.length_take]; omega
    step with mul_word_mod_loop2_spec s d q1 (by omega) d.len hkv hsl { start := 0#usize, «end» := d.len } s
      0#u64 false rfl (by show 0 ≤ d.len.val; omega) hsl (fun _ _ _ => rfl) (by simp [wordsNat_nil])
      as ⟨u4, carry, borrow, hu4l, hsub⟩
    -- `W - q1·D` is `u4` above `u2 - carry - borrow`.
    have hWs : wordsNat u.val * 2 ^ 64 = wordsNat s.val + 2 ^ (64 * d.length) * u2.val := by
      rw [hsN, hUtop, ← hu2', show 64 * d.length = 64 * (d.length - 1) + 64 by omega, pow_add]
      ring
    have hu4L : u4.length = u4.val.length := rfl
    have hlow := wordsNat_lt' u4.val
    rw [← hu4L, hu4l] at hlow
    have hDK := wordsNat_lt' d.val
    rw [← hdL] at hDK
    have hms := msub_result (U := wordsNat u.val * 2 ^ 64) (q := q1.val) (low := wordsNat u4.val)
      (u2 := u2.val) (cy := carry.val) (bw := borrow.toNat) hDpos hDK.le hlow (by cases borrow <;> simp)
      hq1P hq1up (by rw [hWs]; push_cast; linear_combination hsub)
    have haddback (hc : u2.val < carry.val ∨ (u2.val = carry.val ∧ borrow.toNat = 1)) :
        low.posint.mul_word_mod_loop3 { start := 0#usize, «end» := d.len } u4 d false ⦃ r =>
          r.length = d.length ∧ wordsNat r.val = wordsNat u.val * 2 ^ 64 % wordsNat d.val ⦄ := by
      obtain ⟨hK, hres⟩ := hms.2 hc
      step with mul_word_mod_loop3_spec u4 d d.len hkv hu4l { start := 0#usize, «end» := d.len } u4 false rfl
        (by show 0 ≤ d.len.val; omega) hu4l (fun _ _ _ => rfl) (by simp [wordsNat_nil]) as ⟨r, hrl, hrv⟩
      refine ⟨hrl, ?_⟩
      rw [hrv, ← hres, Nat.mod_eq_sub_mod hK, Nat.mod_eq_of_lt (by omega)]
    have hlt' : u2 < carry ↔ u2.val < carry.val := Iff.rfl
    have heq' : u2 = carry ↔ u2.val = carry.val := UScalar.eq_equiv u2 carry
    split
    · rename_i hlt
      exact haddback (Or.inl (hlt'.mp hlt))
    · rename_i hge
      split
      · rename_i heq
        split
        · rename_i hb
          rw [mul_word_mod_loop4_eq]
          exact haddback (Or.inr ⟨heq'.mp heq, by rw [hb]; rfl⟩)
        · rename_i hb
          simp only [WP.spec_ok]
          refine ⟨hu4l, hms.1 ?_⟩
          rintro (h | ⟨-, h⟩)
          · exact hge (hlt'.mpr h)
          · cases borrow
            · simp at h
            · exact hb rfl
      · rename_i hne
        simp only [WP.spec_ok]
        refine ⟨hu4l, hms.1 ?_⟩
        rintro (h | ⟨h, -⟩)
        · exact hge (hlt'.mpr h)
        · exact hne (heq'.mpr h)

end rind.x86_64
