import Rind.Aarch64.P256
import Rind.P256Group
open Aeneas Aeneas.Std Result rind.spec

/-!
# aarch64 P-256 ECDSA, proven from rind's signature API to s2n-bignum's contracts
-/

namespace rind.aarch64

namespace P256

/-! ## Scalars mod n, `mid::p256::Scalar` -/

/-- HOL Light's `inverse_mod n_256 (2 EXP 256)`. -/
def n256RInv : Nat :=
  43790243014242295660885426880012836369732278457577312309071968676491870960761

theorem n256RInv_spec : 2 ^ 256 * n256RInv % n256 = 1 % n256 := by
  simp only [n256RInv, n256]; decide

theorem n256_lt : n256 < 2 ^ 256 := by unfold n256; decide

theorem n256_odd : n256 % 2 = 1 := by unfold n256; decide

theorem CURVE_ORDER_val : wordsNat mid.p256.CURVE_ORDER.val = n256 := by
  simp only [mid.p256.CURVE_ORDER, Array.make, wordsNat, n256]; decide

/-- `CURVE_ORDER_MM`, 2⁵¹² mod n, the Montgomery form of 2²⁵⁶. -/
def n256MM : Nat := 46533765739406314298121036767150998762426774378559716911348521029833835802274

theorem n256MM_spec : n256MM < n256 ∧ n256RInv * n256MM % n256 = 2 ^ 256 % n256 := by
  unfold n256MM n256RInv n256; decide

theorem CURVE_ORDER_MM_val : wordsNat mid.p256.CURVE_ORDER_MM.val = n256MM := by
  simp only [mid.p256.CURVE_ORDER_MM, Array.make, wordsNat, n256MM]; decide

/-- The number a scalar's limbs encode. -/
abbrev scNat (s : mid.p256.Scalar) : Nat := wordsNat s.val

theorem repeat_length4 : (Array.repeat 4#usize core.default.DefaultU64.default).val.length = 4 := by
  simp [Array.repeat]

/-- A result written through a scalar's slice is the scalar with its limbs. -/
theorem from_slice4 (s s4 : Slice U64) (hs : s.val = (Array.repeat 4#usize core.default.DefaultU64.default).val)
    (h : s4.length = s.length) :
    ((Array.repeat 4#usize core.default.DefaultU64.default).from_slice s4).val = s4.val := by
  apply Array.from_slice_val
  rw [show s4.val.length = s4.length from rfl, h, Slice.length, hs, repeat_length4]; rfl

theorem slice_length4 (s : Slice U64) (hs : s.val = (Array.repeat 4#usize core.default.DefaultU64.default).val) :
    s.length = 4 := by
  rw [Slice.length, hs, repeat_length4]

theorem mul_lt_mont (a b : Nat) (ha : a < n256) (hb : b < n256) : a * b ≤ 2 ^ 256 * n256 :=
  le_of_lt (lt_of_lt_of_le (Nat.mul_lt_mul'' ha hb) (Nat.mul_le_mul_right _ (le_of_lt n256_lt)))

@[step]
theorem scalar_mont_mul_spec (a b : mid.p256.Scalar) (ha : scNat a < n256) (hb : scNat b < n256) :
    mid.p256.Scalar.mont_mul a b ⦃ r => scNat r = n256RInv * scNat a * scNat b % n256 ⦄ := by
  unfold mid.p256.Scalar.mont_mul mid.p256.Scalar.Insts.CoreDefaultDefault.default
    core.default.DefaultArray.default
  step*
  rw [to_slice_mut_back_post, scNat, from_slice4 s s4 s_post s4_post]
  rw [slice_length4 s s_post, s1_post, s2_post, s3_post] at s4_post1
  simp only [Array.val_to_slice, CURVE_ORDER_val] at s4_post1
  exact s4_post1 n256_odd (mul_lt_mont _ _ ha hb) n256RInv n256RInv_spec

@[step]
theorem scalar_as_mont_spec (a : mid.p256.Scalar) (ha : scNat a < n256) :
    mid.p256.Scalar.as_mont a ⦃ r => scNat r = 2 ^ 256 * scNat a % n256 ⦄ := by
  unfold mid.p256.Scalar.as_mont mid.p256.Scalar.Insts.CoreDefaultDefault.default
    core.default.DefaultArray.default
  step*
  rw [to_slice_mut_back_post, scNat, from_slice4 s s4 s_post s4_post]
  rw [slice_length4 s s_post, s1_post, s2_post, s3_post] at s4_post1
  simp only [Array.val_to_slice, CURVE_ORDER_val, CURVE_ORDER_MM_val] at s4_post1
  rw [s4_post1 n256_odd (mul_lt_mont _ _ ha n256MM_spec.1) n256RInv n256RInv_spec,
    show n256RInv * wordsNat a.val * n256MM = wordsNat a.val * (n256RInv * n256MM) by ring,
    Nat.mul_mod, n256MM_spec.2, ← Nat.mul_mod, Nat.mul_comm (wordsNat a.val)]

@[step]
theorem scalar_demont_spec (a : mid.p256.Scalar) :
    mid.p256.Scalar.demont a ⦃ r => scNat r = n256RInv * scNat a % n256 ⦄ := by
  unfold mid.p256.Scalar.demont mid.p256.Scalar.Insts.CoreDefaultDefault.default
    core.default.DefaultArray.default
  step*
  rw [to_slice_mut_back_post, scNat, from_slice4 s s3 s_post s3_post]
  rw [slice_length4 s s_post, s1_post, s2_post] at s3_post1
  simp only [Array.val_to_slice, CURVE_ORDER_val] at s3_post1
  exact s3_post1 n256_odd n256RInv n256RInv_spec

@[step]
theorem scalar_add_spec (a b : mid.p256.Scalar) (ha : scNat a < n256) (hb : scNat b < n256) :
    mid.p256.Scalar.add a b ⦃ r => scNat r = (scNat a + scNat b) % n256 ⦄ := by
  unfold mid.p256.Scalar.add mid.p256.Scalar.Insts.CoreDefaultDefault.default
    core.default.DefaultArray.default
  step*
  · simpa [s1_post, s3_post, CURVE_ORDER_val] using ha
  · simpa [s2_post, s3_post, CURVE_ORDER_val] using hb
  · rw [to_slice_mut_back_post, scNat, from_slice4 s s4 s_post s4_post]
    simpa [s1_post, s2_post, s3_post, CURVE_ORDER_val] using s4_post1

@[step]
theorem scalar_inv_spec (a : mid.p256.Scalar) (ha0 : 0 < scNat a) (ha : scNat a < n256) :
    mid.p256.Scalar.inv a ⦃ r => scNat r < n256 ∧ scNat a * scNat r % n256 = 1 ⦄ := by
  unfold mid.p256.Scalar.inv mid.p256.Scalar.Insts.CoreDefaultDefault.default
    core.default.DefaultArray.default
  step*
  rw [to_slice_mut_back_post, scNat, from_slice4 s s4 s_post s4_post]
  rw [s1_post, s2_post] at s4_post1
  simp only [Array.val_to_slice, CURVE_ORDER_val] at s4_post1
  exact s4_post1 ((prime_n256.coprime_iff_not_dvd.mpr (Nat.not_dvd_of_pos_of_lt ha0 ha)).symm)
    n256_odd (by unfold n256; decide)

instance : Fact (Nat.Prime n256) := ⟨prime_n256⟩

theorem n256_pos : 0 < n256 := prime_n256.pos

/-- A number below n is the value of its residue. -/
theorem val_of_eq (x : Nat) (z : ZMod n256) (hx : x < n256) (h : (x : ZMod n256) = z) : x = z.val := by
  rw [← h, ZMod.val_natCast, Nat.mod_eq_of_lt hx]

theorem RInv_mul : ((2 ^ 256 : Nat) : ZMod n256) * (n256RInv : ZMod n256) = 1 := by
  have := congrArg (fun x : Nat => (x : ZMod n256)) n256RInv_spec
  simpa [Nat.cast_mul] using this

/-- `raw_ecdsa_sign`: (e + rd)/k mod n. -/
theorem raw_ecdsa_sign_spec (d k : mid.p256.StaticPrivateKey) (e r : mid.p256.Scalar)
    (hd : scNat d.scalar < n256) (hk0 : 0 < scNat k.scalar) (hk : scNat k.scalar < n256)
    (he : scNat e < n256) (hr : scNat r < n256) :
    mid.p256.StaticPrivateKey.raw_ecdsa_sign d k e r ⦃ s =>
      scNat s = (((scNat e + scNat r * scNat d.scalar : Nat) : ZMod n256) *
        (scNat k.scalar : ZMod n256)⁻¹).val ⦄ := by
  unfold mid.p256.StaticPrivateKey.raw_ecdsa_sign low.ct.into_public
  have hlt : ∀ x, x % n256 < n256 := fun x => Nat.mod_lt _ n256_pos
  step as ⟨a, ha⟩
  step as ⟨b, hb⟩
  step with scalar_mont_mul_spec a b (by rw [ha]; exact hlt _) (by rw [hb]; exact hlt _) as ⟨c, hc⟩
  step as ⟨c1, hc1⟩
  step with scalar_add_spec c1 e (by rw [hc1]; exact hlt _) he as ⟨c2, hc2⟩
  step with scalar_as_mont_spec c2 (by rw [hc2]; exact hlt _) as ⟨l, hl⟩
  step with scalar_inv_spec k.scalar hk0 hk as ⟨ki, hki, hkk⟩
  step with scalar_mont_mul_spec ki l hki (by rw [hl]; exact hlt _) as ⟨s6, hs6⟩
  apply val_of_eq _ _ (by rw [hs6]; exact hlt _)
  have hk' : (scNat k.scalar : ZMod n256) ≠ 0 := by
    rw [Ne, ZMod.natCast_eq_zero_iff]; exact Nat.not_dvd_of_pos_of_lt hk0 hk
  have hkk' : (scNat k.scalar : ZMod n256) * (scNat ki : ZMod n256) = 1 := by
    have := congrArg (fun x : Nat => (x : ZMod n256)) hkk
    simpa [Nat.cast_mul] using this
  have hkinv : (scNat ki : ZMod n256) = (scNat k.scalar : ZMod n256)⁻¹ := by
    exact (inv_eq_of_mul_eq_one_right hkk').symm
  simp only [scNat] at *
  rw [hs6, hl, hc2, hc1, hc, ha, hb]
  push_cast [ZMod.natCast_mod]
  rw [hkinv]
  have hR := RInv_mul
  push_cast at hR
  set t : ZMod n256 := (2 ^ 256 : ZMod n256) * (n256RInv : ZMod n256)
  linear_combination (scNat k.scalar : ZMod n256)⁻¹ *
    ((t ^ 2 + t + 1) * (scNat d.scalar : ZMod n256) * (scNat r : ZMod n256) + (scNat e : ZMod n256)) * hR

end P256

end rind.aarch64
