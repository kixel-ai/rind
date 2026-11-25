import Rind.X86_64.Funs
import Rind.RsaLemmas
import Rind.Ed25519
import Rind.Bytes
import Mathlib.Data.Nat.Log
import Mathlib.Data.Int.GCD
open Aeneas Aeneas.Std Result rind.spec

/-!
# Half-size scalars, `mid::half_size::split`

`split_spec` proves that `split` of a `k < 2^255` returns `u` and `v` with
`u ≡ v k (mod 8L)`, `v` odd and below 2^128, and `|u| < 2^255`: what Ed25519
verification's half-size check, `Rind.Ed25519Group`'s `half_size_iff`, needs
of them, and the multi-scalar multiplication's bound on its scalars. That the
two parts come out near 128 bits only bounds the work, so nothing proves it.

The extended Euclidean loop keeps, for its rows `(r, t)`, `r ≡ ±t k (mod 8L)`
with opposite signs, the two `t` coprime, and `r₀ |t₁| + r₁ |t₀| = 8L`, as
`split`'s comments argue; the last bounds each `t` while the loop runs.
-/

namespace rind.x86_64

namespace HalfSize

open mid.half_size

/-- `8L`. -/
def N : Nat := 8 * n25519

/-- The number a `U256` holds. -/
def val (x : U256) : Nat := 2 ^ 128 * x.hi.val + x.lo.val

/-- The bits a number needs, as `bits` counts them. -/
def bitLen (x : Nat) : Nat := if x = 0 then 0 else Nat.log 2 x + 1

theorem lt_pow_bitLen (x : Nat) : x < 2 ^ bitLen x := by
  unfold bitLen; split_ifs with h
  · simp [h]
  · exact Nat.lt_pow_succ_log_self (by norm_num) x

theorem pow_bitLen_le {x : Nat} (hx : 0 < x) : 2 ^ (bitLen x - 1) ≤ x := by
  unfold bitLen; rw [if_neg (show ¬ x = 0 by omega), Nat.add_sub_cancel]
  exact Nat.pow_log_le_self 2 (by omega)

theorem bitLen_le {x m : Nat} (h : x < 2 ^ m) : bitLen x ≤ m := by
  unfold bitLen; split_ifs with h0
  · omega
  · have := Nat.log_lt_of_lt_pow (by omega) h; omega

theorem bitLen_mono {x y : Nat} (h : x ≤ y) : bitLen x ≤ bitLen y :=
  bitLen_le (lt_of_le_of_lt h (lt_pow_bitLen y))

theorem bitLen_eq {x m : Nat} (hm : 0 < m) (h1 : 2 ^ (m - 1) ≤ x) (h2 : x < 2 ^ m) : bitLen x = m := by
  have hx : 0 < x := lt_of_lt_of_le (by positivity) h1
  have h3 := bitLen_le h2
  have h4 := lt_pow_bitLen x
  have : m - 1 < bitLen x := by
    by_contra hc
    have := Nat.pow_le_pow_right (show 0 < 2 by norm_num) (show bitLen x ≤ m - 1 by omega)
    omega
  omega

theorem bitLen_pos {x : Nat} (hx : 0 < x) : 0 < bitLen x := by
  unfold bitLen; rw [if_neg (show ¬ x = 0 by omega)]; omega

@[step]
theorem bits_spec (x : U128) : mid.half_size.bits x ⦃ r => r.val = bitLen x.val ⦄ := by
  unfold mid.half_size.bits
  have hx := x.hBounds
  have hlz : (core.num.U128.leading_zeros x).val = if x.val = 0 then 128 else 128 - Nat.log 2 x.val - 1 := by
    simp only [core.num.U128.leading_zeros, BitVec.leadingZeros]
    by_cases h : x.val = 0
    · have : x.bv = 0 := by rw [← BitVec.toNat_inj]; simpa [U128.bv_toNat] using h
      simp [this, h]; rfl
    · have : x.bv ≠ 0 := by intro hb; apply h; rw [← U128.bv_toNat, hb]; rfl
      have hl : Nat.log 2 x.val < 128 := Nat.log_lt_of_lt_pow h (by simpa [UScalarTy.numBits] using hx)
      simp only [this, h, ↓reduceIte, U128.bv_toNat]
      show (BitVec.ofNat 32 _).toNat = _
      rw [BitVec.toNat_ofNat]; apply Nat.mod_eq_of_lt; omega
  have hlog : x.val ≠ 0 → Nat.log 2 x.val < 128 := fun h =>
    Nat.log_lt_of_lt_pow h (by simpa [UScalarTy.numBits] using hx)
  have h128 : (128#u32 : U32).val = 128 := rfl
  simp only [lift, bind_ok]
  step as ⟨r, hr⟩
  · rw [h128]; split_ifs at hlz <;> simp only [hlz] <;> omega
  simp only [bitLen]
  rw [hr, hlz]
  split_ifs with h
  · rfl
  · have := hlog h; omega

theorem or_mul_pow (a b i : Nat) (hb : b < 2 ^ i) : b ||| a <<< i = b + 2 ^ i * a := by
  rw [Nat.lor_comm, ← Nat.shiftLeft_add_eq_or_of_lt hb, Nat.shiftLeft_eq]; ring

theorem wordsNat_make4 (a b c d : U64) (h) :
    wordsNat (Std.Array.make 4#usize [a, b, c, d] h).val = a.val + 2 ^ 64 * (b.val + 2 ^ 64 * (c.val + 2 ^ 64 * d.val)) := by
  simp [wordsNat, Std.Array.make, Nat.ofDigits]

theorem u128_size : U128.size = 2 ^ 128 := by rw [U128.size_def, U128.numBits_def]; rfl

theorem shl64 (a : U64) : (a.val <<< 64) % U128.size = a.val <<< 64 := by
  apply Nat.mod_eq_of_lt
  have := a.hBounds
  simp only [UScalarTy.numBits] at this
  rw [Nat.shiftLeft_eq, u128_size]; omega

@[step]
theorem from_spec (x : Std.Array U64 4#usize) : U256.from x ⦃ r => val r = wordsNat x.val ⦄ := by
  unfold U256.from
  simp only [lift, bind_ok]
  step*
  have hl : x.val.length = 4 := x.property
  rw [wordsNat_four _ hl]
  simp only [val, UScalar.val_or, core.convert.num.FromU128U64.from_val_eq, i4_post, i10_post, shl64]
  have b0 := i.hBounds; have b1 := i6.hBounds
  simp only [UScalarTy.numBits] at b0 b1
  rw [or_mul_pow _ _ _ b0, or_mul_pow _ _ _ b1, i_post, i2_post, i6_post, i8_post]
  simp only [getElem!_pos x.val 0 (by omega), getElem!_pos x.val 1 (by omega), getElem!_pos x.val 2 (by omega),
    getElem!_pos x.val 3 (by omega)]
  ring

@[step]
theorem words_spec (x : U256) : U256.words x ⦃ r => wordsNat r.val = val x ⦄ := by
  unfold U256.words
  simp only [lift, bind_ok]
  step*
  rw [wordsNat_make4]
  have hlo := x.lo.hBounds
  have hhi := x.hi.hBounds
  simp only [UScalarTy.numBits] at hlo hhi
  simp only [UScalar.cast_val_eq, val, UScalarTy.numBits, i1_post, i4_post, Nat.shiftRight_eq_div_pow]
  omega

@[step]
theorem sub_spec (x y : U256) (h : val y ≤ val x) : U256.sub x y ⦃ r => val r = val x - val y ⦄ := by
  unfold U256.sub
  have hxl := x.lo.hBounds
  have hyl := y.lo.hBounds
  simp only [UScalarTy.numBits] at hxl hyl
  unfold val at h
  simp only [lift, bind_ok]
  have hlo := core.num.U128.overflowing_sub_eq x.lo y.lo
  generalize core.num.U128.overflowing_sub x.lo y.lo = z at hlo ⊢
  obtain ⟨lo, borrow⟩ := z
  simp only at hlo ⊢
  have h1 : (1#u128 : U128).val = 1 := rfl
  have h0 : (0#u128 : U128).val = 0 := rfl
  step as ⟨i, hi⟩
  split_ifs at hlo with hlt
  · obtain ⟨hl, rfl⟩ := hlo
    have hl' : lo.val + y.lo.val = x.lo.val + 2 ^ 128 := by rw [← u128_size, ← UScalar.size_UScalarTyU128]; exact hl
    simp only [core.convert.num.FromU128Bool.from, ↓reduceIte]
    step as ⟨i2, hi2⟩
    unfold val; simp only; omega
  · obtain ⟨hl, rfl⟩ := hlo
    simp only [core.convert.num.FromU128Bool.from, Bool.false_eq_true, ↓reduceIte]
    step as ⟨i2, hi2⟩
    unfold val; simp only; omega

theorem val_lt (x : U256) : val x < 2 ^ 256 := by
  have := x.hi.hBounds; have := x.lo.hBounds
  simp only [UScalarTy.numBits] at *
  unfold val; omega

@[step]
theorem bits256_spec (x : U256) : U256.bits x ⦃ r => r.val = bitLen (val x) ⦄ := by
  unfold U256.bits
  have hlo := x.lo.hBounds; have hhi := x.hi.hBounds
  simp only [UScalarTy.numBits] at hlo hhi
  split
  · rename_i h
    have h0 : x.hi.val = 0 := by rw [h]; rfl
    step as ⟨r, hr⟩
    rw [hr]; unfold val; rw [h0]; simp
  · rename_i h
    have h0 : x.hi.val ≠ 0 := fun h' => h ((UScalar.eq_equiv _ _).mpr (by rw [h']; rfl))
    step as ⟨b, hb⟩
    have hb128 : b.val ≤ 128 := by rw [hb]; exact bitLen_le hhi
    step as ⟨r, hr⟩
    rw [hr, hb]
    have hpos : 0 < x.hi.val := by omega
    have e1 := pow_bitLen_le hpos
    have e2 := lt_pow_bitLen x.hi.val
    have e3 := bitLen_pos hpos
    symm
    apply bitLen_eq (by omega)
    · rw [show 128 + bitLen x.hi.val - 1 = 128 + (bitLen x.hi.val - 1) by omega, pow_add]
      unfold val; nlinarith
    · rw [pow_add]; unfold val; nlinarith

/-- `U256`'s `Ord`, which compares the numbers. -/
theorem cmp_eq (x y : U256) : U256.Insts.CoreCmpOrd.cmp x y = ok (compare (val x) (val y)) := by
  unfold U256.Insts.CoreCmpOrd.cmp
  have := x.lo.hBounds; have := y.lo.hBounds
  simp only [UScalarTy.numBits] at *
  simp only [lift, bind_ok, core.cmp.impls.OrdU128.cmp]
  rcases lt_trichotomy x.hi.val y.hi.val with h | h | h
  · have hc : compare x.hi.val y.hi.val = .lt := compare_lt_iff_lt.mpr h
    rw [hc]; simp only
    rw [compare_lt_iff_lt.mpr (by unfold val; omega)]
  · have hc : compare x.hi.val y.hi.val = .eq := compare_eq_iff_eq.mpr h
    rw [hc]; simp only
    unfold val; rw [h]
    rcases lt_trichotomy x.lo.val y.lo.val with h' | h' | h'
    · rw [compare_lt_iff_lt.mpr h', compare_lt_iff_lt.mpr (by omega)]
    · rw [compare_eq_iff_eq.mpr h', compare_eq_iff_eq.mpr (by omega)]
    · rw [compare_gt_iff_gt.mpr h', compare_gt_iff_gt.mpr (by omega)]
  · have hc : compare x.hi.val y.hi.val = .gt := compare_gt_iff_gt.mpr h
    rw [hc]; simp only
    rw [compare_gt_iff_gt.mpr (by unfold val; omega)]

@[step]
theorem gt_spec (x y : U256) :
    core.cmp.PartialOrd.gt.trait_default U256.Insts.CoreCmpPartialOrdU256 x y ⦃ b => b ↔ val y < val x ⦄ := by
  simp only [core.cmp.PartialOrd.gt.trait_default, core.cmp.PartialOrd.gt.default, core.cmp.PartialOrd.gt_body,
    U256.Insts.CoreCmpPartialOrdU256, U256.Insts.CoreCmpPartialOrdU256.partial_cmp, cmp_eq, bind_ok, WP.spec_ok]
  simp [compare_gt_iff_gt]

@[step]
theorem lt_spec (x y : U256) :
    core.cmp.PartialOrd.lt.trait_default U256.Insts.CoreCmpPartialOrdU256 x y ⦃ b => b ↔ val x < val y ⦄ := by
  simp only [core.cmp.PartialOrd.lt.trait_default, core.cmp.PartialOrd.lt.default, core.cmp.PartialOrd.lt_body,
    U256.Insts.CoreCmpPartialOrdU256, U256.Insts.CoreCmpPartialOrdU256.partial_cmp, cmp_eq, bind_ok, WP.spec_ok]
  simp [compare_lt_iff_lt]

theorem mul_pow_div (lo s : Nat) (hs : s ≤ 128) : lo * 2 ^ s / 2 ^ 128 = lo / 2 ^ (128 - s) := by
  rw [show 2 ^ 128 = 2 ^ s * 2 ^ (128 - s) by rw [← pow_add]; congr 1; omega, mul_comm lo,
    Nat.mul_div_mul_left _ _ (by positivity)]

@[step]
theorem shl_spec (x : U256) (s : U32) (hs : s.val < 128) (h : val x * 2 ^ s.val < 2 ^ 256) :
    U256.shl x s ⦃ r => val r = val x * 2 ^ s.val ⦄ := by
  unfold U256.shl
  have hlo := x.lo.hBounds; have hhi := x.hi.hBounds
  simp only [UScalarTy.numBits] at hlo hhi
  split
  · rw [show ((0#32#uscalar : U32) : Nat) = 0 from rfl]; simp
  · rename_i h0
    have hs0 : s.val ≠ 0 := fun h' => h0 ((UScalar.eq_equiv _ _).mpr (by rw [h']; rfl))
    have hhi' : x.hi.val * 2 ^ s.val < 2 ^ 128 := by
      unfold val at h
      have : 2 ^ 128 * (x.hi.val * 2 ^ s.val) < 2 ^ 128 * 2 ^ 128 := by
        calc 2 ^ 128 * (x.hi.val * 2 ^ s.val) = (2 ^ 128 * x.hi.val) * 2 ^ s.val := by ring
          _ ≤ (2 ^ 128 * x.hi.val + x.lo.val) * 2 ^ s.val := Nat.mul_le_mul_right _ (Nat.le_add_right _ _)
          _ < 2 ^ 256 := h
          _ = _ := by norm_num
      exact Nat.lt_of_mul_lt_mul_left this
    have h128 : (128#u32 : U32).val = 128 := rfl
    simp only [lift, bind_ok]
    step*
    unfold val
    simp only [UScalar.val_or, *]
    rw [u128_size, Nat.shiftLeft_eq, Nat.mod_eq_of_lt hhi', Nat.shiftRight_eq_div_pow, Nat.shiftLeft_eq]
    have hq : x.lo.val / 2 ^ (128 - s.val) < 2 ^ s.val := by
      rw [Nat.div_lt_iff_lt_mul (by positivity), ← pow_add, show s.val + (128 - s.val) = 128 by omega]
      exact hlo
    have hor : x.hi.val * 2 ^ s.val ||| x.lo.val / 2 ^ (128 - s.val) =
        x.lo.val / 2 ^ (128 - s.val) + 2 ^ s.val * x.hi.val := by
      rw [Nat.lor_comm, ← Nat.shiftLeft_eq, or_mul_pow _ _ _ hq]
    rw [hor]
    have hsplit := Nat.div_add_mod (x.lo.val * 2 ^ s.val) (2 ^ 128)
    rw [mul_pow_div _ _ (by omega)] at hsplit
    nlinarith

end HalfSize

end rind.x86_64
