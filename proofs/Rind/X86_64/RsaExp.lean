import Rind.X86_64.RsaGather
import Rind.X86_64.RsaPublic
open Aeneas Aeneas.Std Result rind.spec rind.spec.rsa

/-!
# RSA's fixed-window exponentiation on x86_64

`low::x86_64::mont_exp` raises `x` to `e` in the Montgomery domain by a
5-bit fixed window over a table of the 32 powers of `x`, gathering each
window's entry by reading every row. With BMI2 and ADX at 16 and 32 words,
the width RSA-2048's and RSA-4096's primes take, it squares and multiplies by
rind's Montgomery products, which `MontProducts` states, and gathers by
`Rind.X86_64.RsaGather`'s proven gather; `mont_exp_by_spec` proves that path.
aws-lc's `bn_power5` runs every other width that is a multiple of eight, and
no proof covers it.
-/

namespace rind.x86_64

/-! ## `bits`, a window of the exponent -/

/-- `W / 2^(64q)` is word `q` plus `2^64` times the words above it. -/
theorem wordsNat_div_word (l : List U64) (q : Nat) (hq : q < l.length) :
    wordsNat l / 2 ^ (64 * q) = l[q].val + 2 ^ 64 * wordsNat (l.drop (q + 1)) := by
  have h := wordsNat_take_drop l q
  have hlt := wordsNat_lt' (l.take q)
  have hlen : (l.take q).length = q := by simp only [List.length_take]; omega
  rw [hlen] at h hlt
  rw [List.drop_eq_getElem_cons hq, wordsNat_cons] at h
  rw [h, Nat.add_mul_div_left _ _ (by positivity), Nat.div_eq_of_lt hlt, zero_add]

/-- A window of `w ≤ 64` bits from bit `s` of a word `a` and the value `T`
above it. -/
theorem window_eq (a T s w : Nat) (hs : s ≤ 64) (hw : w ≤ 64) :
    (a + 2 ^ 64 * T) / 2 ^ s % 2 ^ w = (a / 2 ^ s + 2 ^ (64 - s) * (T % 2 ^ s)) % 2 ^ w := by
  have h64 : (2 : Nat) ^ 64 = 2 ^ s * 2 ^ (64 - s) := by rw [← pow_add]; congr 1; omega
  have h64w : (2 : Nat) ^ 64 = 2 ^ w * 2 ^ (64 - w) := by rw [← pow_add]; congr 1; omega
  have hT := Nat.mod_add_div T (2 ^ s)
  calc (a + 2 ^ 64 * T) / 2 ^ s % 2 ^ w
      = (a / 2 ^ s + 2 ^ (64 - s) * T) % 2 ^ w := by
        rw [h64, mul_assoc, Nat.add_mul_div_left _ _ (by positivity)]
    _ = (a / 2 ^ s + 2 ^ (64 - s) * (T % 2 ^ s) + 2 ^ w * (2 ^ (64 - w) * (T / 2 ^ s))) % 2 ^ w := by
        congr 1
        conv_lhs => rw [← hT]
        rw [mul_add, ← mul_assoc, mul_comm (2 ^ (64 - s)) (2 ^ s), ← h64, h64w]
        ring
    _ = _ := Nat.add_mul_mod_self_left _ _ _

theorem bits_spec (e : Slice U64) (lsb width : Usize) (hw1 : 1 ≤ width.val) (hw : width.val ≤ 5)
    (hin : lsb.val + width.val ≤ 64 * e.length) :
    low.x86_64.mont_exp.bits e lsb width ⦃ r =>
      r.val = wordsNat e.val / 2 ^ lsb.val % 2 ^ width.val ⦄ := by
  unfold low.x86_64.mont_exp.bits
  step*
  have hq : word.val < e.val.length := by simp only [Slice.length] at hin; omega
  have hW : wordsNat e.val / 2 ^ lsb.val = (wordsNat e.val / 2 ^ (64 * word.val)) / 2 ^ shift.val := by
    rw [Nat.div_div_eq_div_mul, ← pow_add]; congr 2; omega
  rw [hW, wordsNat_div_word _ _ hq, window_eq _ _ _ _ (by omega) (by omega)]
  have hs64 : shift.val < 64 := by omega
  have ha : i.val < 2 ^ 64 := by scalar_tac
  have hbits : bits.val = i.val / 2 ^ shift.val := by rw [bits_post, Nat.shiftRight_eq_div_pow]
  -- The mask `(1 << width) - 1` keeps the window's `width` bits.
  have hsz : U64.size = 2 ^ 64 := by simp [U64.size, U64.numBits]
  have h32 : 2 ^ width.val < 2 ^ 64 :=
    lt_of_le_of_lt (Nat.pow_le_pow_right (by norm_num) hw) (by norm_num)
  have hmask : ∀ x : U64, (do
      let m ← 1#u64 <<< width
      let m1 ← m - 1#u64
      ok (x &&& m1)) ⦃ r => r.val = x.val % 2 ^ width.val ⦄ := by
    intro x
    step as ⟨m, hm1, _⟩
    have hm : m.val = 2 ^ width.val := by
      rw [hm1, Nat.one_shiftLeft, hsz, Nat.mod_eq_of_lt h32]
    step as ⟨m1, hm1v, _⟩
    · rw [hm]; exact Nat.one_le_two_pow
    · rw [UScalar.val_and, hm1v, hm, Nat.and_two_pow_sub_one_eq_mod]
  have hT : ∀ q (hq : q < e.val.length), wordsNat (e.val.drop q) % 2 ^ shift.val =
      (e.val[q]'hq).val % 2 ^ shift.val := by
    intro q hq
    rw [List.drop_eq_getElem_cons hq, wordsNat_cons]
    have h64 : (2 : Nat) ^ 64 = 2 ^ shift.val * 2 ^ (64 - shift.val) := by
      rw [← pow_add]; congr 1; omega
    rw [h64, mul_assoc, Nat.add_mul_mod_self_left]
  split
  · rename_i hgt
    have hgt' : 64 < shift.val + width.val := by rw [← i1_post]; scalar_tac
    have hq1 : word.val + 1 < e.val.length := by simp only [Slice.length] at hin; omega
    step as ⟨j, hj⟩
    step as ⟨b, hb⟩
    step as ⟨t, ht, _⟩
    step as ⟨y, hy, _⟩
    apply WP.spec_mono (hmask (bits ||| y))
    intro r hr
    rw [hr, UScalar.val_or, hbits, hy, ht, hb, Nat.shiftLeft_eq, i_post, hsz]
    have hjw : j.val = word.val + 1 := hj
    simp only [hjw]
    have h64 : (2 : Nat) ^ 64 = 2 ^ (64 - shift.val) * 2 ^ shift.val := by
      rw [← pow_add]; congr 1; omega
    rw [h64, mul_comm _ (2 ^ (64 - shift.val)), Nat.mul_mod_mul_left, hT _ hq1]
    have ha' : (e.val[word.val]'hq).val / 2 ^ shift.val < 2 ^ (64 - shift.val) := by
      rw [Nat.div_lt_iff_lt_mul (by positivity), ← pow_add,
        show 64 - shift.val + shift.val = 64 by omega]
      scalar_tac
    rw [Nat.lor_comm, mul_comm (2 ^ (64 - shift.val)), ← Nat.shiftLeft_eq,
      ← Nat.shiftLeft_add_eq_or_of_lt ha', Nat.shiftLeft_eq, Nat.add_comm, mul_comm]
  · rename_i hle
    have hle' : shift.val + width.val ≤ 64 := by rw [← i1_post]; scalar_tac
    simp only [bind_ok]
    apply WP.spec_mono (hmask bits)
    intro r hr
    rw [hr, hbits]
    have h : (2 : Nat) ^ (64 - shift.val) = 2 ^ width.val * 2 ^ (64 - shift.val - width.val) := by
      rw [← pow_add]; congr 1; omega
    rw [h, mul_assoc, Nat.add_mul_mod_self_left, i_post]

/-! ## The table of powers -/

/-- Row `j` of `mont_exp`'s table of rows of `k` words. -/
def rowOf (l : List U64) (k j : Nat) : List U64 := (l.drop (j * k)).take k

/-- `a` stands for `C^t` in the Montgomery domain modulo `M` with `R`: it is
below `M`, and `C^t·R` modulo `M`. -/
def MontPow (M R C t : Nat) (a : List U64) : Prop :=
  wordsNat a < M ∧ wordsNat a ≡ C ^ t * R [MOD M]

theorem rowOf_append_left (a b : List U64) (k j : Nat) (h : j * k + k ≤ a.length) :
    rowOf (a ++ b) k j = rowOf a k j := by
  simp only [rowOf, List.drop_append, List.take_append]
  rw [List.length_drop, show k - (a.length - j * k) = 0 by omega, List.take_zero, List.append_nil]

theorem rowOf_take (l : List U64) (k j n : Nat) (h : j * k + k ≤ n) :
    rowOf (l.take n) k j = rowOf l k j := by
  simp only [rowOf, List.drop_take, List.take_take]
  rw [Nat.min_eq_left (by omega)]

theorem rowOf_at (a b : List U64) (k i : Nat) (ha : a.length = i * k) :
    rowOf (a ++ b) k i = b.take k := by
  rw [rowOf, List.drop_append, ha, List.drop_eq_nil_of_le (show a.length ≤ i * k by omega), List.nil_append,
    Nat.sub_self, List.drop_zero]

theorem rowOf_length (l : List U64) (k j : Nat) (h : j * k + k ≤ l.length) :
    (rowOf l k j).length = k := by
  simp only [rowOf, List.length_take, List.length_drop]; omega

section table
variable (x m : Slice U64) (n0 : U64) (C : Nat)

theorem mont_exp_by_loop0_spec (k w : Usize) (hP : MontProducts m.length) (hk : k.val = m.length)
    (hw : w.val = k.val) (hk2 : 2 ≤ k.val) (hodd : wordsNat m.val % 2 = 1)
    (hn0 : (wordsNat m.val * n0.val + 1) % 2 ^ 64 = 0) (hxl : x.length = k.val)
    (hx : MontPow (wordsNat m.val) (2 ^ (64 * k.val)) C 1 x.val)
    (iter : core.ops.range.Range Usize) (powers : Slice U64)
    (hpl : powers.length = 32 * k.val) (hs : 2 ≤ iter.start.val) (hse : iter.start.val ≤ 32)
    (he : iter.end.val = 32)
    (hrows : ∀ j < iter.start.val,
      MontPow (wordsNat m.val) (2 ^ (64 * k.val)) C j (rowOf powers.val k.val j)) :
    low.x86_64.mont_exp.mont_exp_by_loop0 iter x m n0 k w powers ⦃ r =>
      r.length = 32 * k.val ∧
        ∀ j < 32, MontPow (wordsNat m.val) (2 ^ (64 * k.val)) C j (rowOf r.val k.val j) ⦄ := by
  unfold low.x86_64.mont_exp.mont_exp_by_loop0
  apply loop.spec_decr_nat (fun st => 32 - st.1.start.val)
    (fun st => 2 ≤ st.1.start.val ∧ st.1.start.val ≤ 32 ∧ st.1.end.val = 32 ∧
      st.2.length = 32 * k.val ∧
      ∀ j < st.1.start.val,
        MontPow (wordsNat m.val) (2 ^ (64 * k.val)) C j (rowOf st.2.val k.val j))
  · rintro ⟨it, pw⟩ ⟨hs, hse, he, hpl, hrows⟩
    simp only at hs hse he hpl hrows ⊢
    unfold low.x86_64.mont_exp.mont_exp_by_loop0.body
    by_cases hlt : it.start.val < it.end.val
    · step with core.iter.range.IteratorRange.next_Usize_some_spec as ⟨o, it', ho', hst, hen⟩
      subst ho'
      simp only
      set i := it.start with hi
      set M := wordsNat m.val
      set R := 2 ^ (64 * k.val)
      have hR : Nat.Coprime R M := coprime_two_pow_odd hodd _
      have hkm : m.val.length = k.val := hk.symm
      have hpl' : pw.val.length = 32 * k.val := hpl
      have hiw : i.val * w.val ≤ 32 * k.val := by rw [hw]; exact Nat.mul_le_mul_right _ (by omega)
      have hmax : 32 * k.val ≤ Usize.max := by rw [← hpl]; exact pw.property
      step as ⟨i1, hi1⟩
      step as ⟨dn, rs, back, hd1, hd2, hd3, hd4, hback⟩
      step as ⟨i2, hi2⟩
      have hik : i1.val = i.val * k.val := by rw [hi1, hw]
      have hrest : k.val ≤ rs.length := by
        rw [hd2]; simp only [Slice.length] at hpl ⊢
        have : (i.val + 1) * k.val ≤ 32 * k.val := Nat.mul_le_mul_right _ (by omega)
        rw [Nat.succ_mul] at this; omega
      -- The new row `i`, of `k` words, and the rows below it, as they were.
      have hnew : ∀ s3 : Slice U64, s3.length = k.val → ∀ sback : Slice U64 → Slice U64,
          (∀ s', (sback s').val = rs.val.setSlice! 0 s'.val) →
          MontPow M R C i.val s3.val →
          (back (dn, sback s3)).length = 32 * k.val ∧
            ∀ j < it'.start.val, MontPow M R C j (rowOf (back (dn, sback s3)).val k.val j) := by
        intro s3 hs3 sback hsback hpow
        have hsl : (sback s3).length = pw.length - i1.val := by
          simp only [Slice.length, hsback, List.length_setSlice!]; exact hd2
        obtain ⟨hbv, hbl⟩ := hback dn (sback s3) hd1 hsl
        refine ⟨by rw [hbl, hpl], fun j hj => ?_⟩
        rw [hbv]
        by_cases hji : j < i.val
        · rw [rowOf_append_left _ _ _ _ (by
            rw [hd3, List.length_take, hik, hpl']
            have : (j + 1) * k.val ≤ i.val * k.val := Nat.mul_le_mul_right _ (by omega)
            rw [Nat.succ_mul] at this; omega)]
          rw [hd3, hik, rowOf_take _ _ _ _ (by
            have : (j + 1) * k.val ≤ i.val * k.val := Nat.mul_le_mul_right _ (by omega)
            rw [Nat.succ_mul] at this; omega)]
          exact hrows j hji
        · have hj : j = i.val := by omega
          subst hj
          have hs3' : s3.val.length = k.val := hs3
          rw [rowOf_at _ _ _ _ (by rw [hd3, List.length_take, hik, hpl']; omega), hsback,
            ← hs3', take_setSlice_zero _ _ (by rw [hs3']; exact hrest)]
          exact hpow
      split
      · -- An even power squares its half.
        rename_i h0
        have hev : i.val % 2 = 0 := by rw [← hi2]; exact h0
        step as ⟨sz, sback, hsz1, hsz2, hsback⟩
        step as ⟨i3, hi3⟩
        have hhalf : i3.val * k.val + k.val ≤ i.val * k.val := by
          rw [hi3]
          have : (i.val / 2 + 1) * k.val ≤ i.val * k.val := Nat.mul_le_mul_right _ (by omega)
          rw [Nat.succ_mul] at this; omega
        have hi3w : i3.val * w.val ≤ 32 * k.val := by rw [hw]; omega
        step as ⟨i4, hi4⟩
        have hi4d : i4.val ≤ dn.length := by rw [hi4, hw, hd1, hik]; omega
        step as ⟨s1, hs1v, hs1l⟩
        have hks1 : k.val ≤ s1.length := by rw [hs1l, hd1, hi4, hik, hw]; omega
        step as ⟨s2, hs2v, hs2l⟩
        have hs2 : s2.val = rowOf pw.val k.val (i.val / 2) := by
          have e1 : s1.val = dn.val.drop i4.val := hs1v
          rw [hs2v, List.slice_zero_j, e1, hd3, show i4.val = i.val / 2 * k.val by rw [hi4, hw, hi3]]
          have h2 : (i.val / 2 + 1) * k.val ≤ i.val * k.val := Nat.mul_le_mul_right _ (by omega)
          rw [Nat.succ_mul] at h2
          exact rowOf_take pw.val k.val (i.val / 2) i1.val (by rw [hik]; omega)
        have hhp := hrows (i.val / 2) (by omega)
        rw [← hs2] at hhp
        have hs2l' : s2.val.length = m.val.length := by rw [hkm]; exact hs2l
        have hargs : MontArgs s2.val s2.val m.val n0 :=
          ⟨hs2l', hs2l', by omega, hodd, hn0, hhp.1, hhp.1⟩
        step with hP.2 sz s2 m n0 rfl (by rw [hsz2, hk]) hargs as ⟨s3, hs3⟩
        obtain ⟨hs3l, hs3N, hs3v⟩ := hs3
        rw [hkm] at hs3v hs3l
        have hpow : MontPow M R C i.val s3.val := ⟨hs3N, by
          have := mont_exp_sqr hR hhp.2 hs3v
          rwa [show 2 * (i.val / 2) = i.val by omega] at this⟩
        obtain ⟨hl, hr⟩ := hnew s3 hs3l sback hsback hpow
        exact ⟨by omega, by omega, by rw [hen]; exact he, hl, hr, by omega⟩
      · -- An odd one multiplies the one below it by `x`.
        rename_i h0
        have h0' : i2.val ≠ 0 := h0
        have hodd' : i.val % 2 = 1 := by omega
        step as ⟨sz, sback, hsz1, hsz2, hsback⟩
        step as ⟨i3, hi3⟩
        have hi3w : i3.val * w.val ≤ 32 * k.val := by
          rw [hw, hi3]; exact Nat.mul_le_mul_right _ (by omega)
        step as ⟨i4, hi4⟩
        have hprev : i4.val + k.val ≤ i.val * k.val := by
          rw [hi4, hw, hi3]
          have : (i.val - 1 + 1) * k.val ≤ i.val * k.val := Nat.mul_le_mul_right _ (by omega)
          rw [Nat.succ_mul] at this; omega
        have hi4d : i4.val ≤ dn.length := by rw [hd1, hik]; omega
        step as ⟨s1, hs1v, hs1l⟩
        have hks1 : k.val ≤ s1.length := by rw [hs1l, hd1, hik]; omega
        step as ⟨s2, hs2v, hs2l⟩
        have hs2 : s2.val = rowOf pw.val k.val (i.val - 1) := by
          have e1 : s1.val = dn.val.drop i4.val := hs1v
          rw [hs2v, List.slice_zero_j, e1, hd3, show i4.val = (i.val - 1) * k.val by rw [hi4, hw, hi3]]
          exact rowOf_take pw.val k.val (i.val - 1) i1.val (by rw [hik, hi4, hw, hi3] at *; omega)
        have hhp := hrows (i.val - 1) (by omega)
        rw [← hs2] at hhp
        have hs2l' : s2.val.length = m.val.length := by rw [hkm]; exact hs2l
        have hxl' : x.val.length = m.val.length := by rw [hkm]; exact hxl
        have hargs : MontArgs s2.val x.val m.val n0 :=
          ⟨hs2l', hxl', by omega, hodd, hn0, hhp.1, hx.1⟩
        step with hP.1 sz s2 x m n0 rfl (by rw [hsz2, hk]) hargs as ⟨s3, hs3⟩
        obtain ⟨hs3l, hs3N, hs3v⟩ := hs3
        rw [hkm] at hs3v hs3l
        have hpow : MontPow M R C i.val s3.val := ⟨hs3N, by
          have := mont_exp_mul hR hhp.2 (by simpa using hx.2) hs3v
          rwa [show i.val - 1 + 1 = i.val by omega] at this⟩
        obtain ⟨hl, hr⟩ := hnew s3 hs3l sback hsback hpow
        exact ⟨by omega, by omega, by rw [hen]; exact he, hl, hr, by omega⟩
    · step with core.iter.range.IteratorRange.next_Usize_none_spec as ⟨o, it', ho', hit⟩
      subst ho'
      simp only [WP.spec_ok]
      exact ⟨hpl, fun j hj => hrows j (by omega)⟩
  · exact ⟨hs, hse, he, hpl, hrows⟩

end table

/-- Multiplying `C^a` by `C^b` in the Montgomery domain gives `C^(a+b)`. -/
theorem mont_exp_add {N R A B P C a b : Nat} (hR : Nat.Coprime R N) (hA : A ≡ C ^ a * R [MOD N])
    (hB : B ≡ C ^ b * R [MOD N]) (hP : P * R ≡ A * B [MOD N]) : P ≡ C ^ (a + b) * R [MOD N] := by
  apply mont_cancel hR
  refine hP.trans ((hA.mul hB).trans (by unfold Nat.ModEq; congr 1; ring))

section window
variable (e m : Slice U64) (n0 : U64) (C : Nat)

/-- `mont_exp_by`'s five squarings: from `C^(t·2^s)`, after `s` of them,
`C^(32t)`. -/
theorem mont_exp_by_loop2_loop0_spec (hP : MontProducts m.length) (hk2 : 2 ≤ m.length)
    (hodd : wordsNat m.val % 2 = 1) (hn0 : (wordsNat m.val * n0.val + 1) % 2 ^ 64 = 0) (t : Nat)
    (iter : core.ops.range.Range Usize) (z spare : Slice U64) (hs : iter.start.val ≤ 5)
    (he : iter.end.val = 5) (hz : z.length = m.length) (hsp : spare.length = m.length)
    (hpow : MontPow (wordsNat m.val) (2 ^ (64 * m.length)) C (t * 2 ^ iter.start.val) z.val) :
    low.x86_64.mont_exp.mont_exp_by_loop2_loop0 iter z m n0 spare ⦃ r =>
      r.1.length = m.length ∧ r.2.length = m.length ∧
        MontPow (wordsNat m.val) (2 ^ (64 * m.length)) C (t * 32) r.1.val ⦄ := by
  unfold low.x86_64.mont_exp.mont_exp_by_loop2_loop0
  apply loop.spec_decr_nat (fun st => 5 - st.1.start.val)
    (fun st => st.1.start.val ≤ 5 ∧ st.1.end.val = 5 ∧ st.2.1.length = m.length ∧
      st.2.2.length = m.length ∧
      MontPow (wordsNat m.val) (2 ^ (64 * m.length)) C (t * 2 ^ st.1.start.val) st.2.1.val)
  · rintro ⟨it, z, sp⟩ ⟨hs, he, hz, hsp, hpow⟩
    simp only at hs he hz hsp hpow ⊢
    unfold low.x86_64.mont_exp.mont_exp_by_loop2_loop0.body
    have hR : Nat.Coprime (2 ^ (64 * m.length)) (wordsNat m.val) := coprime_two_pow_odd hodd _
    by_cases hlt : it.start.val < it.end.val
    · step with core.iter.range.IteratorRange.next_Usize_some_spec as ⟨o, it', ho', hst, hen⟩
      subst ho'
      simp only
      have hzl : z.val.length = m.val.length := hz
      have hargs : MontArgs z.val z.val m.val n0 := ⟨hzl, hzl, hk2, hodd, hn0, hpow.1, hpow.1⟩
      step with hP.2 sp z m n0 rfl hsp hargs as ⟨s3, hs3⟩
      obtain ⟨hs3l, hs3N, hs3v⟩ := hs3
      step as ⟨z1, hz1⟩
      subst hz1
      refine ⟨by omega, by rw [hen]; exact he, hs3l, hs3l, ⟨hs3N, ?_⟩, by omega⟩
      have := mont_exp_sqr hR hpow.2 hs3v
      rwa [hst, pow_succ, ← mul_assoc, mul_comm _ 2]
    · step with core.iter.range.IteratorRange.next_Usize_none_spec as ⟨o, it', ho', hit⟩
      subst ho'
      simp only [WP.spec_ok]
      have h5 : it.start.val = 5 := by omega
      rw [h5] at hpow
      exact ⟨hz, hsp, hpow⟩
  · exact ⟨hs, he, hz, hsp, hpow⟩

/-- `mont_exp_by`'s windows below the top one: from `C^(e / 2^lsb)`, each
squares five times and multiplies by its window's power, gathered from the
table, until `lsb` reaches zero, leaving `C^e`. -/
theorem mont_exp_by_loop2_spec (havx : ∃ t, low.x86_64.cpu.HaveAvx2.check = ok t)
    (hP : MontProducts m.length) (k : Usize) (hk : k.val = m.length) (hk2 : 2 ≤ k.val)
    (hk4 : k.val % 4 = 0) (hkb : k.val < 2 ^ 60)
    (hodd : wordsNat m.val % 2 = 1) (hn0 : (wordsNat m.val * n0.val + 1) % 2 ^ 64 = 0)
    (powers : Slice U64) (hpl : powers.length = 32 * k.val)
    (hrows : ∀ j < 32, MontPow (wordsNat m.val) (2 ^ (64 * k.val)) C j (rowOf powers.val k.val j))
    (z spare term : Slice U64) (lsb : Usize) (hz : z.length = k.val) (hsp : spare.length = k.val)
    (ht : term.length = k.val) (hlsb : lsb.val % 5 = 0) (hle : lsb.val ≤ 64 * e.length)
    (hpow : MontPow (wordsNat m.val) (2 ^ (64 * k.val)) C (wordsNat e.val / 2 ^ lsb.val) z.val) :
    low.x86_64.mont_exp.mont_exp_by_loop2 z e m n0 k powers spare term lsb ⦃ r =>
      r.1.length = k.val ∧
        MontPow (wordsNat m.val) (2 ^ (64 * k.val)) C (wordsNat e.val) r.1.val ⦄ := by
  unfold low.x86_64.mont_exp.mont_exp_by_loop2
  apply loop.spec_decr_nat (fun st => st.2.2.2.val)
    (fun st => st.1.length = k.val ∧ st.2.1.length = k.val ∧ st.2.2.1.length = k.val ∧
      st.2.2.2.val % 5 = 0 ∧ st.2.2.2.val ≤ 64 * e.length ∧
      MontPow (wordsNat m.val) (2 ^ (64 * k.val)) C (wordsNat e.val / 2 ^ st.2.2.2.val) st.1.val)
  · rintro ⟨z, sp, tm, lsb⟩ ⟨hz, hsp, ht, hlsb, hle, hpow⟩
    simp only at hz hsp ht hlsb hle hpow ⊢
    unfold low.x86_64.mont_exp.mont_exp_by_loop2.body
    have hR : Nat.Coprime (2 ^ (64 * k.val)) (wordsNat m.val) := coprime_two_pow_odd hodd _
    have hkm : m.val.length = k.val := hk.symm
    split
    · rename_i hpos
      have hpos' : 0 < lsb.val := by simpa using hpos
      have h5 : 5 ≤ lsb.val := by omega
      step as ⟨lsb1, hlsb1⟩
      have hpow' : MontPow (wordsNat m.val) (2 ^ (64 * m.length)) C
          (wordsNat e.val / 2 ^ lsb.val * 2 ^ (0#usize : Usize).val) z.val := by
        rw [← hk]; simpa using hpow
      step with mont_exp_by_loop2_loop0_spec m n0 C hP (by omega) hodd hn0 (wordsNat e.val / 2 ^ lsb.val)
        { start := 0#usize, «end» := 5#usize } z sp (by simp) (by simp) (by rw [hz, hk])
        (by rw [hsp, hk]) hpow' as ⟨z1, sp1, hz1, hsp1, hpow1⟩
      have h5v : (5#usize : Usize).val = 5 := rfl
      step with bits_spec e lsb1 5#usize (by simp) (by simp) (by rw [h5v]; omega) as ⟨b, hb⟩
      have hb32 : b.val < 32 := by rw [hb]; exact Nat.mod_lt _ (by norm_num)
      step with gather_spec havx tm powers b (by rw [ht]; exact hk4) (by rw [ht]; exact hpl) hb32
        (by rw [ht]; exact hkb) as ⟨tm1, htm1⟩
      have htm1l : tm1.val.length = k.val := by
        rw [htm1, List.length_take, List.length_drop, ht]
        have : b.val * k.val ≤ 31 * k.val := Nat.mul_le_mul_right _ (by omega)
        have hpl' : powers.val.length = 32 * k.val := hpl
        omega
      step as ⟨s, hsv, hsl⟩
      have hs : s.val = rowOf powers.val k.val b.val := by
        rw [hsv, List.slice_zero_j, htm1, ht, List.take_take, Nat.min_self]; rfl
      have hrow := hrows b.val hb32
      rw [← hs] at hrow
      have hz1l : z1.val.length = m.val.length := by rw [hkm]; simp only [Slice.length] at hz1; omega
      have hsl' : s.val.length = m.val.length := by rw [hkm]; exact hsl
      have hargs : MontArgs z1.val s.val m.val n0 :=
        ⟨hz1l, hsl', by omega, hodd, hn0, hpow1.1, hrow.1⟩
      step with hP.1 sp1 z1 s m n0 rfl hsp1 hargs as ⟨s3, hs3⟩
      obtain ⟨hs3l, hs3N, hs3v⟩ := hs3
      step as ⟨z2, hz2⟩
      subst hz2
      rw [hkm] at hs3v hs3l
      rw [← hk] at hpow1
      have hexp : wordsNat e.val / 2 ^ lsb1.val =
          wordsNat e.val / 2 ^ lsb.val * 32 + b.val := by
        rw [hb, show lsb.val = lsb1.val + 5 by omega, pow_add, ← Nat.div_div_eq_div_mul,
          show (2 : Nat) ^ 5 = 32 by rfl]
        have := Nat.div_add_mod (wordsNat e.val / 2 ^ lsb1.val) 32
        omega
      refine ⟨hs3l, hs3l, htm1l, by omega, by omega, ⟨hs3N, ?_⟩, by omega⟩
      rw [hexp]
      exact mont_exp_add hR hpow1.2 hrow.2 hs3v
    · rename_i h0
      have h0' : lsb.val = 0 := by simp at h0; omega
      simp only [WP.spec_ok]
      rw [h0', pow_zero, Nat.div_one] at hpow
      exact ⟨hz, hpow⟩
  · exact ⟨hz, hsp, ht, hlsb, hle, hpow⟩

end window

end rind.x86_64
