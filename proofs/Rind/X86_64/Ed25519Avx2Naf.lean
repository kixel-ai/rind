import Rind.X86_64.Funs
import Rind.Bytes
import Mathlib.Tactic.LinearCombination
open Aeneas Aeneas.Std Result rind.spec

/-!
# The AVX2 double multiplication's non-adjacent forms

`non_adjacent_form_spec` proves that `non_adjacent_form` recodes a scalar
below 2^255 as 256 signed digits that sum to it, each zero or odd and below
2^(w-1) in magnitude, for the widths 5 and 8 that `double_base` asks for.

The loop keeps `pos`, the next digit's position, and `carry`, which one more
2^pos stands for: the digits so far plus `carry · 2^pos` are the scalar's low
`pos` bits. A carry needs a set bit at or above `pos`, so with the scalar
below 2^255 none is left once `pos` passes 255.
-/

namespace rind.x86_64.avx2

/-- The integer that 256 signed digits name: `∑ dⱼ 2^j`. -/
def nafSum (naf : List I8) : Int := ∑ j ∈ Finset.range 256, (naf[j]!).val * 2 ^ j

/-- A digit of a width-`w` NAF: zero, or odd and below 2^(w-1) in magnitude. -/
def nafDigit (w : Nat) (d : Int) : Prop := d = 0 ∨ (d % 2 = 1 ∧ -2 ^ (w - 1) < d ∧ d < 2 ^ (w - 1))

/-- The loop's state, for the scalar `X`: digits at and above `pos` are still
zero, those below are digits, and they and `carry` name `X`'s low `pos` bits. -/
def NafInv (w X : Nat) (naf : List I8) (pos c : Nat) : Prop :=
  naf.length = 256 ∧ pos ≤ 255 + w ∧ c ≤ 1 ∧ (c = 1 → pos ≤ 255) ∧
    (∀ j, pos ≤ j → j < 256 → (naf[j]!).val = 0) ∧ (∀ j < 256, nafDigit w (naf[j]!).val) ∧
    nafSum naf + c * 2 ^ pos = ((X % 2 ^ pos : Nat) : Int)

theorem nafSum_set (naf : List I8) (pos : Nat) (hpos : pos < naf.length) (h256 : pos < 256)
    (h0 : (naf[pos]!).val = 0) (d : I8) : nafSum (naf.set pos d) = nafSum naf + d.val * 2 ^ pos := by
  unfold nafSum
  have e : ∀ j ∈ Finset.range 256, ((naf.set pos d)[j]!).val * 2 ^ j =
      (naf[j]!).val * 2 ^ j + if j = pos then d.val * 2 ^ pos else 0 := by
    intro j _
    by_cases hj : j = pos
    · subst hj
      rw [getElem!_pos naf j hpos] at h0
      simp [h0, hpos]
    · simp [hj]
  rw [Finset.sum_congr rfl e, Finset.sum_add_distrib, Finset.sum_ite_eq']
  simp [h256]

theorem mod_two_pow_add (X p k : Nat) : X % 2 ^ (p + k) = X % 2 ^ p + 2 ^ p * (X / 2 ^ p % 2 ^ k) := by
  rw [pow_add, Nat.mod_mul]

/-- A scalar below 2^255 with `2^m` at most its bits from `p` up has `p + m < 255`. -/
theorem lt_of_bits (X p m : Nat) (hX : X < 2 ^ 255) (h : 2 ^ m ≤ X / 2 ^ p) : p + m < 255 := by
  rw [Nat.le_div_iff_mul_le (by positivity), ← pow_add] at h
  have := lt_of_le_of_lt h hX
  rw [Nat.pow_lt_pow_iff_right (by norm_num)] at this
  omega

/-- An even window: the carry was the bit at `pos`, so it carries on to the next. -/
theorem nafInv_even (w X : Nat) (naf : List I8) (p c : Nat) (hw : 2 ≤ w) (hX : X < 2 ^ 255)
    (h : NafInv w X naf p c) (hp : p < 256) (hW : (c + X / 2 ^ p % 2 ^ w) % 2 = 0) :
    NafInv w X naf (p + 1) c := by
  obtain ⟨hl, hpw, hc, hc1, hz, hd, hs⟩ := h
  have hb : X / 2 ^ p % 2 ^ w % 2 = X / 2 ^ p % 2 :=
    Nat.mod_mod_of_dvd _ (dvd_pow_self 2 (by omega))
  have hbit : X / 2 ^ p % 2 = c := by omega
  refine ⟨hl, by omega, hc, fun h1 => ?_, fun j hj hj' => hz j (by omega) hj', hd, ?_⟩
  · have := lt_of_bits X p 0 hX (by rw [pow_zero]; have := Nat.mod_le (X / 2 ^ p) 2; omega)
    omega
  · rw [mod_two_pow_add, pow_one, hbit, pow_succ]
    push_cast at hs ⊢
    linear_combination hs

/-- An odd window below 2^(w-1): its digit, with no carry. -/
theorem nafInv_small (w X : Nat) (naf : List I8) (p c : Nat) (hw : 2 ≤ w)
    (h : NafInv w X naf p c) (hp : p < 256) (hW : (c + X / 2 ^ p % 2 ^ w) % 2 = 1)
    (hlt : c + X / 2 ^ p % 2 ^ w < 2 ^ (w - 1)) (d : I8) (hd : d.val = ((c + X / 2 ^ p % 2 ^ w : Nat) : Int)) :
    NafInv w X (naf.set p d) (p + w) 0 := by
  obtain ⟨hl, hpw, hc, hc1, hz, hdig, hs⟩ := h
  have hp' : p < naf.length := by omega
  have hnaf : ∀ j, (naf.set p d)[j]! = if j = p then d else naf[j]! := by
    intro j
    by_cases hj : j = p
    · subst hj; simp [hp']
    · simp [hj, Ne.symm hj]
  refine ⟨by simp [hl], by omega, by omega, by omega, fun j hj hj' => ?_, fun j hj => ?_, ?_⟩
  · rw [hnaf, ite_eq_right_iff.mpr (fun h => absurd h (by omega))]; exact hz j (by omega) hj'
  · rw [hnaf]
    split_ifs
    · right
      rw [hd, show ((2 : Int) ^ (w - 1)) = ((2 ^ (w - 1) : Nat) : Int) by norm_cast]
      omega
    · exact hdig j hj
  · rw [nafSum_set _ _ hp' hp (hz p le_rfl hp), hd, mod_two_pow_add]
    push_cast at hs ⊢
    linear_combination hs

/-- An odd window from 2^(w-1): its digit less 2^w, carrying one. -/
theorem nafInv_big (w X : Nat) (naf : List I8) (p c : Nat) (hw : 2 ≤ w) (hX : X < 2 ^ 255)
    (h : NafInv w X naf p c) (hp : p < 256) (hW : (c + X / 2 ^ p % 2 ^ w) % 2 = 1)
    (hge : 2 ^ (w - 1) ≤ c + X / 2 ^ p % 2 ^ w) (d : I8)
    (hd : d.val = ((c + X / 2 ^ p % 2 ^ w : Nat) : Int) - 2 ^ w) :
    NafInv w X (naf.set p d) (p + w) 1 := by
  obtain ⟨hl, hpw, hc, hc1, hz, hdig, hs⟩ := h
  have hp' : p < naf.length := by omega
  have hnaf : ∀ j, (naf.set p d)[j]! = if j = p then d else naf[j]! := by
    intro j
    by_cases hj : j = p
    · subst hj; simp [hp']
    · simp [hj, Ne.symm hj]
  have h2w : (2 : Nat) ^ w = 2 * 2 ^ (w - 1) := by rw [← pow_succ']; congr 1; omega
  have hB : X / 2 ^ p % 2 ^ w < 2 ^ w := Nat.mod_lt _ (by positivity)
  -- The window is odd, so its bits are at least 2^(w-1), and so is the scalar from `p`.
  have he : 2 ^ (w - 1) % 2 = 0 := by
    rw [show w - 1 = (w - 2) + 1 by omega, pow_succ]; simp
  have hB' : 2 ^ (w - 1) ≤ X / 2 ^ p % 2 ^ w := by
    have : 2 ≤ 2 ^ (w - 1) := by
      calc 2 = 2 ^ 1 := by norm_num
        _ ≤ 2 ^ (w - 1) := Nat.pow_le_pow_right (by norm_num) (by omega)
    omega
  have htop := lt_of_bits X p (w - 1) hX (le_trans hB' (Nat.mod_le _ _))
  refine ⟨by simp [hl], by omega, le_rfl, fun _ => by omega, fun j hj hj' => ?_, fun j hj => ?_, ?_⟩
  · rw [hnaf, ite_eq_right_iff.mpr (fun h => absurd h (by omega))]; exact hz j (by omega) hj'
  · rw [hnaf]
    split_ifs
    · right
      rw [hd, show ((2 : Int) ^ (w - 1)) = ((2 ^ (w - 1) : Nat) : Int) by norm_cast,
        show ((2 : Int) ^ w) = ((2 ^ w : Nat) : Int) by norm_cast]
      generalize X / 2 ^ p % 2 ^ w = B at hB hB' hge hW ⊢
      generalize 2 ^ w = A at h2w hB ⊢
      generalize 2 ^ (w - 1) = H at h2w hB' hge he ⊢
      omega
    · exact hdig j hj
  · rw [nafSum_set _ _ hp' hp (hz p le_rfl hp), hd, mod_two_pow_add, pow_add]
    push_cast at hs ⊢
    linear_combination hs

/-- Past bit 255, no carry is left, and the digits name the scalar. -/
theorem nafInv_done (w X : Nat) (naf : List I8) (p c : Nat) (hX : X < 2 ^ 255)
    (h : NafInv w X naf p c) (hp : 256 ≤ p) :
    nafSum naf = X ∧ ∀ j < 256, nafDigit w (naf[j]!).val := by
  obtain ⟨hl, hpw, hc, hc1, hz, hdig, hs⟩ := h
  have hc0 : c = 0 := by omega
  have hXp : X % 2 ^ p = X :=
    Nat.mod_eq_of_lt (lt_of_lt_of_le hX (Nat.pow_le_pow_right (by norm_num) (by omega)))
  rw [hc0, hXp] at hs
  simp only [Nat.cast_zero, zero_mul, add_zero] at hs
  exact ⟨hs, hdig⟩

/-! ## The window -/

/-- Bits `b` to `b + w` of `a + 2^m k` are `a`'s, for `b + w ≤ m`. -/
theorem div_add_mul_mod (a k b w m : Nat) (hm : b + w ≤ m) :
    (a + 2 ^ m * k) / 2 ^ b % 2 ^ w = a / 2 ^ b % 2 ^ w := by
  rw [show 2 ^ m * k = 2 ^ b * (2 ^ w * (2 ^ (m - b - w) * k)) by
      rw [← mul_assoc, ← mul_assoc, ← pow_add, ← pow_add]; congr 2; omega,
    Nat.add_mul_div_left _ _ (by positivity), Nat.add_mul_mod_self_left]

/-- The scalar's bits from `pos` are those of the two words from `pos / 64`. -/
theorem window_words (x : List U64) (hl : x.length = 5) (pos w : Nat) (hpos : pos < 256) (hw : w ≤ 64) :
    wordsNat x / 2 ^ pos % 2 ^ w =
      ((x[pos / 64]!).val + 2 ^ 64 * (x[pos / 64 + 1]!).val) / 2 ^ (pos % 64) % 2 ^ w := by
  match x, hl with
  | [a, b, c, d, e], _ =>
    have hX : wordsNat [a, b, c, d, e] = a.val + 2 ^ 64 * (b.val + 2 ^ 64 * (c.val + 2 ^ 64 * (d.val +
        2 ^ 64 * e.val))) := by simp [wordsNat, Nat.ofDigits]
    have ha := a.hBounds; have hb := b.hBounds; have hc := c.hBounds
    simp only [UScalarTy.numBits] at ha hb hc
    have hp : pos = 64 * (pos / 64) + pos % 64 := (Nat.div_add_mod pos 64).symm
    have hr : pos % 64 < 64 := Nat.mod_lt _ (by norm_num)
    generalize pos / 64 = q at hp ⊢
    generalize pos % 64 = r at hp hr ⊢
    subst hp
    rw [hX, pow_add, ← Nat.div_div_eq_div_mul]
    rcases (by omega : q = 0 ∨ q = 1 ∨ q = 2 ∨ q = 3) with rfl | rfl | rfl | rfl
    · simp only [Nat.mul_zero, pow_zero, Nat.div_one]
      rw [show a.val + 2 ^ 64 * (b.val + 2 ^ 64 * (c.val + 2 ^ 64 * (d.val + 2 ^ 64 * e.val))) =
        a.val + 2 ^ 64 * b.val + 2 ^ 128 * (c.val + 2 ^ 64 * (d.val + 2 ^ 64 * e.val)) by ring,
        div_add_mul_mod _ _ _ _ _ (by omega)]
      rfl
    · rw [show a.val + 2 ^ 64 * (b.val + 2 ^ 64 * (c.val + 2 ^ 64 * (d.val + 2 ^ 64 * e.val))) =
        a.val + 2 ^ (64 * 1) * (b.val + 2 ^ 64 * c.val + 2 ^ 128 * (d.val + 2 ^ 64 * e.val)) by ring,
        Nat.add_mul_div_left _ _ (by positivity), Nat.div_eq_of_lt (show a.val < 2 ^ (64 * 1) by omega),
        Nat.zero_add,
        div_add_mul_mod _ _ _ _ _ (by omega)]
      rfl
    · rw [show a.val + 2 ^ 64 * (b.val + 2 ^ 64 * (c.val + 2 ^ 64 * (d.val + 2 ^ 64 * e.val))) =
        (a.val + 2 ^ 64 * b.val) + 2 ^ (64 * 2) * (c.val + 2 ^ 64 * d.val + 2 ^ 128 * e.val) by ring,
        Nat.add_mul_div_left _ _ (by positivity),
        Nat.div_eq_of_lt (show a.val + 2 ^ 64 * b.val < 2 ^ (64 * 2) by omega), Nat.zero_add,
        div_add_mul_mod _ _ _ _ _ (by omega)]
      rfl
    · rw [show a.val + 2 ^ 64 * (b.val + 2 ^ 64 * (c.val + 2 ^ 64 * (d.val + 2 ^ 64 * e.val))) =
        (a.val + 2 ^ 64 * b.val + 2 ^ 128 * c.val) + 2 ^ (64 * 3) * (d.val + 2 ^ 64 * e.val) by ring,
        Nat.add_mul_div_left _ _ (by positivity),
        Nat.div_eq_of_lt (show a.val + 2 ^ 64 * b.val + 2 ^ 128 * c.val < 2 ^ (64 * 3) by omega),
        Nat.zero_add]
      rfl

/-- Within one word: bits `b` to `b + w` of a word pair are the low word's. -/
theorem window_lo (a k b w : Nat) (hb : b + w ≤ 64) : (a + 2 ^ 64 * k) / 2 ^ b % 2 ^ w = a / 2 ^ b % 2 ^ w :=
  div_add_mul_mod a k b w 64 hb

/-- Across two words, as the loop joins them: the low word shifted right by `b`,
or the high one shifted left by `64 - b` and truncated. -/
theorem window_hi (a k b w : Nat) (ha : a < 2 ^ 64) (hb0 : 0 < b) (hb : b < 64) (hw : w ≤ 64) :
    (a / 2 ^ b ||| k * 2 ^ (64 - b) % 2 ^ 64) % 2 ^ w = (a + 2 ^ 64 * k) / 2 ^ b % 2 ^ w := by
  have hlo : a / 2 ^ b < 2 ^ (64 - b) := by
    rw [Nat.div_lt_iff_lt_mul (by positivity), ← pow_add]; rwa [show 64 - b + b = 64 by omega]
  have hhi : k * 2 ^ (64 - b) % 2 ^ 64 = (k % 2 ^ b) <<< (64 - b) := by
    rw [Nat.shiftLeft_eq, show (2 : Nat) ^ 64 = 2 ^ b * 2 ^ (64 - b) by rw [← pow_add]; congr 1; omega,
      Nat.mul_mod_mul_right]
  rw [hhi, Nat.lor_comm, ← Nat.shiftLeft_add_eq_or_of_lt hlo, Nat.shiftLeft_eq]
  rw [show 2 ^ 64 * k = 2 ^ b * (2 ^ (64 - b) * k) by
      rw [← mul_assoc, ← pow_add]; congr 2; omega,
    Nat.add_mul_div_left _ _ (by positivity)]
  conv_rhs => rw [← Nat.mod_add_div k (2 ^ b)]
  rw [show a / 2 ^ b + 2 ^ (64 - b) * (k % 2 ^ b + 2 ^ b * (k / 2 ^ b)) =
      k % 2 ^ b * 2 ^ (64 - b) + a / 2 ^ b + 2 ^ w * (2 ^ (64 - w) * (k / 2 ^ b)) by
      rw [← mul_assoc (2 ^ w), ← pow_add, show w + (64 - w) = 64 by omega,
        show (2 : Nat) ^ 64 = 2 ^ (64 - b) * 2 ^ b by rw [← pow_add]; congr 1; omega]
      ring,
    Nat.add_mul_mod_self_left]

/-! ## The loop -/

/-- A small window, as an `i8`. -/
theorem bmod_small (W : Nat) (h : W < 128) : Int.bmod (W : Int) (2 ^ 8) = W := by
  simp only [Int.bmod]
  split_ifs <;> omega

/-- A large window less 2^w, as `i8`s wrapping. -/
theorem bmod_big (W A : Nat) (hA : A = 32 ∨ A = 256) (h1 : A / 2 ≤ W) (h2 : W < A) :
    Int.bmod (Int.bmod (W : Int) (2 ^ 8) - Int.bmod (A : Int) (2 ^ 8)) (2 ^ 8) = (W : Int) - A := by
  rcases hA with rfl | rfl <;> simp only [Int.bmod] <;> split_ifs <;> omega

open low.x86_64.edwards25519_scalarmuldouble_avx2 in
theorem non_adjacent_form_loop_spec (w : Usize) (hw : w.val = 5 ∨ w.val = 8) (x : Std.Array U64 5#usize)
    (hX : wordsNat x.val < 2 ^ 255) (width mask : U64) (hwidth : width.val = 2 ^ w.val)
    (hmask : mask.val = 2 ^ w.val - 1) (naf : Std.Array I8 256#usize) (pos : Usize) (carry : U64)
    (hinv : NafInv w.val (wordsNat x.val) naf.val pos.val carry.val) :
    non_adjacent_form_loop w naf x width mask pos carry ⦃ r =>
      nafSum r.val = wordsNat x.val ∧ ∀ j < 256, nafDigit w.val (r.val[j]!).val ⦄ := by
  unfold non_adjacent_form_loop
  apply loop.spec_decr_nat (fun s => 264 - s.2.1.val)
    (fun s => NafInv w.val (wordsNat x.val) s.1.val s.2.1.val s.2.2.val)
  · rintro ⟨naf, pos, carry⟩ hinv
    simp only at hinv ⊢
    unfold non_adjacent_form_loop.body
    split_ifs with hpos
    · have hp : pos.val < 256 := by scalar_tac
      have hw64 : w.val ≤ 64 := by omega
      step as ⟨word, hword⟩
      step as ⟨bit, hbit⟩
      step as ⟨i, hi, _⟩
      apply WP.spec_bind (Pₘ := fun bb : U64 =>
        bb.val % 2 ^ w.val = wordsNat x.val / 2 ^ pos.val % 2 ^ w.val)
      · rw [window_words x.val (by simp) pos.val w.val hp hw64]
        split_ifs with hlt
        · step*
          have hl : pos.val % 64 + w.val ≤ 64 := by scalar_tac
          rw [bb_post, i1_post, Nat.shiftRight_eq_div_pow, window_lo _ _ _ _ hl, ← hword, ← hbit,
            getElem!_pos x.val word.val (by scalar_tac)]
        · have hb0 : 0 < bit.val := by
            have : ¬ bit.val < i.val := hlt
            omega
          have hb64 : bit.val < 64 := by omega
          step*
          rw [← getElem!_pos x.val word.val (by scalar_tac), hword] at i1_post
          rw [← getElem!_pos x.val i3.val (by scalar_tac), i3_post, hword] at i4_post
          rw [hbit] at i2_post i5_post hb0 hb64
          rw [UScalar.val_or, i2_post, i6_post, i5_post, i1_post, i4_post, Nat.shiftRight_eq_div_pow,
            Nat.shiftLeft_eq, show U64.size = 2 ^ 64 by norm_num [U64.size, U64.numBits],
            window_hi _ _ _ _ (x.val[pos.val / 64]!).hBounds hb0 hb64 hw64]
      · intro bb hbb
        have hc : carry.val ≤ 1 := hinv.2.2.1
        step as ⟨i1, hi1, _⟩
        have hi1v : i1.val = wordsNat x.val / 2 ^ pos.val % 2 ^ w.val := by
          rw [hi1, UScalar.val_and, hmask, Nat.and_two_pow_sub_one_eq_mod, hbb]
        have hw256 : 2 ^ w.val ≤ 256 := by rcases hw with h | h <;> rw [h] <;> norm_num
        have hB : i1.val < 2 ^ w.val := by rw [hi1v]; exact Nat.mod_lt _ (by positivity)
        step as ⟨window, hwindow⟩
        step as ⟨i2, hi2, _⟩
        have hi2v : i2.val = window.val % 2 := by
          rw [hi2, UScalar.val_and, show (1#u64 : U64).val = 1 from rfl, Nat.and_one_is_mod]
        have hW : window.val = carry.val + wordsNat x.val / 2 ^ pos.val % 2 ^ w.val := by
          rw [hwindow, hi1v]
        have hw2 : 2 ≤ w.val := by omega
        split_ifs with h0
        · have hev : (carry.val + wordsNat x.val / 2 ^ pos.val % 2 ^ w.val) % 2 = 0 := by
            have : i2.val = 0 := by rw [h0]; rfl
            omega
          step as ⟨pos1, hpos1⟩
          refine ⟨?_, by omega⟩
          rw [hpos1]
          exact nafInv_even _ _ _ _ _ hw2 hX hinv hp hev
        · have hodd : (carry.val + wordsNat x.val / 2 ^ pos.val % 2 ^ w.val) % 2 = 1 := by
            have : i2.val ≠ 0 := fun h => h0 (by scalar_tac)
            omega
          step as ⟨i3, hi3⟩
          have hi3v : i3.val = 2 ^ (w.val - 1) := by
            rw [hi3, hwidth, show w.val = (w.val - 1) + 1 by omega, pow_succ, Nat.mul_div_cancel _ (by norm_num)]
            rfl
          apply WP.spec_bind (Pₘ := fun r : Std.Array I8 256#usize × U64 =>
            NafInv w.val (wordsNat x.val) r.1.val (pos.val + w.val) r.2.val)
          · split_ifs with hsmall
            · step*
              have hlt' : window.val < 2 ^ (w.val - 1) := by rw [← hi3v]; exact hsmall
              have h128 : 2 ^ (w.val - 1) ≤ 128 := by rcases hw with h | h <;> rw [h] <;> norm_num
              have hd : i4.val = ((carry.val + wordsNat x.val / 2 ^ pos.val % 2 ^ w.val : Nat) : Int) := by
                rw [i4_post, UScalar.hcast_val_eq, ← hW]
                exact bmod_small _ (by omega)
              rw [a_post, Std.Array.set_val_eq]
              exact nafInv_small _ _ _ _ _ hw2 hinv hp hodd (by omega) i4 hd
            · step*
              have hge : 2 ^ (w.val - 1) ≤ window.val := by
                rw [← hi3v]; exact Nat.le_of_not_lt hsmall
              have hA : 2 ^ w.val = 32 ∨ 2 ^ w.val = 256 := by rcases hw with h | h <;> rw [h] <;> norm_num
              have hA2 : 2 ^ w.val / 2 = 2 ^ (w.val - 1) := by
                rw [show w.val = (w.val - 1) + 1 by omega, pow_succ, Nat.mul_div_cancel _ (by norm_num)]
                rfl
              have hWlt : window.val < 2 ^ w.val := by
                have : wordsNat x.val / 2 ^ pos.val % 2 ^ w.val < 2 ^ w.val := Nat.mod_lt _ (by positivity)
                have h2 : (2 ^ w.val) % 2 = 0 := by
                  rw [show w.val = (w.val - 1) + 1 by omega, pow_succ]; simp
                omega
              have hd : i6.val = ((carry.val + wordsNat x.val / 2 ^ pos.val % 2 ^ w.val : Nat) : Int) -
                  2 ^ w.val := by
                rw [i6_post, core.num.I8.wrapping_sub_val_eq, i4_post, i5_post, UScalar.hcast_val_eq,
                  UScalar.hcast_val_eq, ← hW, hwidth]
                have := bmod_big window.val (2 ^ w.val) hA (by omega) hWlt
                push_cast at this
                exact this
              rw [a_post, Std.Array.set_val_eq]
              exact nafInv_big _ _ _ _ _ hw2 hX hinv hp hodd (by omega) i6 hd
          · rintro ⟨naf1, carry1⟩ h1
            step as ⟨pos1, hpos1⟩
            refine ⟨by rw [hpos1]; exact h1, by omega⟩
    · simp only [WP.spec_ok]
      exact nafInv_done _ _ _ _ _ hX hinv (by scalar_tac)
  · exact hinv

/-- `non_adjacent_form` of a scalar below 2^255 recodes it as 256 digits that
sum to it, each zero or odd and below 2^(w-1) in magnitude. -/
@[step]
theorem non_adjacent_form_spec (x : Std.Array U64 4#usize) (w : Usize) (hw : w.val = 5 ∨ w.val = 8)
    (hX : wordsNat x.val < 2 ^ 255) :
    low.x86_64.edwards25519_scalarmuldouble_avx2.non_adjacent_form x w ⦃ naf =>
      nafSum naf.val = wordsNat x.val ∧ ∀ j < 256, nafDigit w.val (naf.val[j]!).val ⦄ := by
  unfold low.x86_64.edwards25519_scalarmuldouble_avx2.non_adjacent_form
  have hwidth : ∀ width : U64, width.val = 1 <<< w.val % U64.size → width.val = 2 ^ w.val := by
    intro width h
    rw [h, Nat.shiftLeft_eq, one_mul]
    rcases hw with h | h <;> rw [h] <;> norm_num [U64.size, U64.numBits]
  step as ⟨i, hi⟩
  step as ⟨i1, hi1⟩
  step as ⟨i2, hi2⟩
  step as ⟨i3, hi3⟩
  step as ⟨width, hwv, _⟩
  · scalar_tac
  replace hwv := hwidth width hwv
  step as ⟨mask, hmask, _⟩
  · rw [hwv]; exact Nat.one_le_two_pow
  have hx5 : wordsNat [i, i1, i2, i3, 0#u64] = wordsNat x.val := by
    rw [wordsNat_four x.val (by simp), hi, hi1, hi2, hi3]
    simp only [wordsNat, Nat.ofDigits, List.map]
    simp [getElem!_pos]
  have hrep : (Std.Array.repeat 256#usize (0#i8 : I8)).val = List.replicate 256 0#i8 :=
    Std.Array.repeat_val _ _
  have h0 : ∀ j : Nat, ((Std.Array.repeat 256#usize (0#i8 : I8)).val[j]!).val = 0 := by
    intro j
    rw [hrep]
    by_cases hj : j < 256
    · rw [getElem!_pos _ _ (by rw [List.length_replicate]; exact hj), List.getElem_replicate]; rfl
    · rw [getElem!_neg _ _ (by rw [List.length_replicate]; exact hj)]; rfl
  apply WP.spec_mono (non_adjacent_form_loop_spec w hw _ (by exact hx5 ▸ hX) width mask
    hwv (by rw [hmask, hwv]) _ _ _ ?_)
  · intro naf h
    exact hx5 ▸ h
  · refine ⟨by rw [hrep, List.length_replicate], by simp, by simp, by simp, fun j _ _ => h0 j, fun j _ => Or.inl (h0 j), ?_⟩
    simp only [nafSum, h0, zero_mul, Finset.sum_const_zero, zero_add]
    simp [hx5]

end rind.x86_64.avx2
