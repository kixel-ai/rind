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
    rw [if_pos hle', hr, ← getElem!_pos]
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
          rw [getElem!_set_of_lt _ _ _ _ (by omega), if_pos rfl, hw, ← getElem!_pos, hv _ (by omega),
            if_neg (by scalar_tac), if_pos (by scalar_tac), hi1]
        · rw [getElem!_set_of_lt _ _ _ _ (by omega), if_neg hpi, hv p hp]
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

end rind.x86_64
