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

/-! ## Field elements, `mid::p256::FieldElement` -/

@[step]
theorem array_eq_spec (a b : Std.Array U64 4#usize) :
    core.array.equality.PartialEqArray.eq core.cmp.PartialEqU64 a b ⦃ r => r ↔ a.val = b.val ⦄ := by
  have : core.array.equality.PartialEqArray.eq core.cmp.PartialEqU64 a b =
      core.slice.cmp.PartialEqSlice.eq core.cmp.PartialEqU64 a.to_slice b.to_slice := by
    simp [core.array.equality.PartialEqArray.eq, core.slice.cmp.PartialEqSlice.eq, Array.val_to_slice]
  rw [this]
  apply WP.spec_mono (core.slice.cmp.PartialEqSlice.eq_homo_spec _ _ _ (fun x y => by simp [liftFun2]))
  intro r hr
  rw [hr, Slice.eq_iff, Array.val_to_slice, Array.val_to_slice]

theorem wordsNat_inj4 (a b : List U64) (ha : a.length = 4) (hb : b.length = 4)
    (h : wordsNat a = wordsNat b) : a = b := by
  match a, ha, b, hb with
  | [a0, a1, a2, a3], _, [b0, b1, b2, b3], _ =>
    have := a0.hBounds; have := a1.hBounds; have := a2.hBounds; have := a3.hBounds
    have := b0.hBounds; have := b1.hBounds; have := b2.hBounds; have := b3.hBounds
    simp only [UScalarTy.numBits] at *
    simp only [wordsNat, List.map_cons, List.map_nil, Nat.ofDigits_cons, Nat.ofDigits_nil] at h
    have e0 : a0.val = b0.val := by omega
    have e1 : a1.val = b1.val := by omega
    have e2 : a2.val = b2.val := by omega
    have e3 : a3.val = b3.val := by omega
    simp [UScalar.eq_of_val_eq e0, UScalar.eq_of_val_eq e1, UScalar.eq_of_val_eq e2,
      UScalar.eq_of_val_eq e3]

@[step]
theorem fe_public_eq_spec (a b : mid.p256.FieldElement) :
    mid.p256.FieldElement.public_eq a b ⦃ r => r ↔ feNat a = feNat b ⦄ := by
  unfold mid.p256.FieldElement.public_eq
  apply WP.spec_mono (array_eq_spec a b)
  intro r hr
  rw [hr]
  exact ⟨fun h => by simp [feNat, h], fun h => wordsNat_inj4 _ _ a.property b.property h⟩

@[step]
theorem fe_inv_spec (a : mid.p256.FieldElement) :
    mid.p256.FieldElement.inv a ⦃ r => feNat r < p256 ∧
      (feNat a % p256 ≠ 0 → feNat a * feNat r % p256 = 1) ∧ (feNat a % p256 = 0 → feNat r = 0) ⦄ := by
  unfold mid.p256.FieldElement.inv mid.p256.FieldElement.Insts.CoreDefaultDefault.default
    core.default.DefaultArray.default
  step*

@[step]
theorem fe_negate_spec (a : mid.p256.FieldElement) (ha : feNat a ≤ p256) :
    mid.p256.FieldElement.negate_mod_p a ⦃ r => feNat r = (p256 - feNat a) % p256 ⦄ := by
  unfold mid.p256.FieldElement.negate_mod_p mid.p256.FieldElement.Insts.CoreDefaultDefault.default
    core.default.DefaultArray.default
  step*

/-- A number's value as a field element in Montgomery form: it times 2⁻²⁵⁶. -/
abbrev dec (x : Nat) : ZMod p256 := (p256RInv : ZMod p256) * x

theorem R_mul_RInv : ((2 ^ 256 : Nat) : ZMod p256) * (p256RInv : ZMod p256) = 1 := by
  have := congrArg (fun n : Nat => (n : ZMod p256)) p256RInv_spec.2
  simpa only [Nat.cast_mul, ZMod.natCast_mod, Nat.cast_one] using this

theorem RInv_ne_zero : (p256RInv : ZMod p256) ≠ 0 := fun h => by
  have := R_mul_RInv; rw [h, mul_zero] at this; exact zero_ne_one this

theorem cast_mod_p (x : Nat) : ((x % p256 : Nat) : ZMod p256) = x := ZMod.natCast_mod _ _

/-- Numbers below p are equal when their values are. -/
theorem eq_of_dec (x y : Nat) (hx : x < p256) (hy : y < p256) : x = y ↔ dec x = dec y := by
  constructor
  · intro h; rw [h]
  · intro h
    have h' : (x : ZMod p256) = y := mul_left_cancel₀ RInv_ne_zero h
    rw [ZMod.natCast_eq_natCast_iff', Nat.mod_eq_of_lt hx, Nat.mod_eq_of_lt hy] at h'
    exact h'

theorem dec_mont_mul (a b : Nat) : dec (p256RInv * a * b % p256) = dec a * dec b := by
  simp only [dec, cast_mod_p, Nat.cast_mul]; ring

theorem dec_mont_sqr (a : Nat) : dec (p256RInv * a ^ 2 % p256) = dec a ^ 2 := by
  simp only [dec, cast_mod_p, Nat.cast_mul, Nat.cast_pow]; ring

theorem val_dec (x : Nat) : p256RInv * x % p256 = (dec x).val := by
  rw [dec, ← Nat.cast_mul, ZMod.val_natCast]

theorem ofJacobian_dec (x y z : Nat) :
    p256OfJacobian (p256RInv * x % p256) (p256RInv * y % p256) (p256RInv * z % p256) =
      if dec z = 0 then none
      else some ((dec x * (dec z ^ 2)⁻¹).val, (dec y * (dec z ^ 3)⁻¹).val) := by
  unfold p256OfJacobian
  simp only [val_dec, ZMod.natCast_val, ZMod.cast_id', id, ZMod.val_eq_zero]

/-- `pt` holds `P` in Jacobian Montgomery form, as s2n-bignum's routines read it. -/
def jrep (P : P256Point) (pt : mid.p256.JacobianMontPoint) : Prop :=
  p256Represents P (tripleNat pt.xyz.val)

@[step]
theorem jac_x_spec (pt : mid.p256.JacobianMontPoint) :
    mid.p256.JacobianMontPoint.x pt ⦃ fe => fe.val = (pt.xyz.val.drop 0).take 4 ⦄ := by
  unfold mid.p256.JacobianMontPoint.x
  have hl : (pt.xyz.val).length = 12 := pt.xyz.property
  step*
  · simp [mid.p256.JacobianMontPoint.X]
  · simp [mid.p256.JacobianMontPoint.X]
  · rcases r with a | _
    · exact ⟨a, rfl⟩
    · exact absurd (by simp [s_post1, mid.p256.JacobianMontPoint.X]) r_post
  · subst r_post
    obtain ⟨ha, -⟩ := r_post
    simp [ha, s_post, mid.p256.JacobianMontPoint.X, List.slice]

@[step]
theorem jac_y_spec (pt : mid.p256.JacobianMontPoint) :
    mid.p256.JacobianMontPoint.y pt ⦃ fe => fe.val = (pt.xyz.val.drop 4).take 4 ⦄ := by
  unfold mid.p256.JacobianMontPoint.y
  have hl : (pt.xyz.val).length = 12 := pt.xyz.property
  step*
  · simp [mid.p256.JacobianMontPoint.Y]
  · simp [mid.p256.JacobianMontPoint.Y]
  · rcases r with a | _
    · exact ⟨a, rfl⟩
    · exact absurd (by simp [s_post1, mid.p256.JacobianMontPoint.Y]) r_post
  · subst r_post
    obtain ⟨ha, -⟩ := r_post
    simp [ha, s_post, mid.p256.JacobianMontPoint.Y, List.slice]

@[step]
theorem jac_z_spec (pt : mid.p256.JacobianMontPoint) :
    mid.p256.JacobianMontPoint.z pt ⦃ fe => fe.val = (pt.xyz.val.drop 8).take 4 ⦄ := by
  unfold mid.p256.JacobianMontPoint.z
  have hl : (pt.xyz.val).length = 12 := pt.xyz.property
  step*
  · simp [mid.p256.JacobianMontPoint.Z]
  · simp [mid.p256.JacobianMontPoint.Z]
  · rcases r with a | _
    · exact ⟨a, rfl⟩
    · exact absurd (by simp [s_post1, mid.p256.JacobianMontPoint.Z]) r_post
  · subst r_post
    obtain ⟨ha, -⟩ := r_post
    simp [ha, s_post, mid.p256.JacobianMontPoint.Z, List.slice]

theorem tripleNat_eq (pt : mid.p256.JacobianMontPoint) (fx fy fz : mid.p256.FieldElement)
    (hx : fx.val = (pt.xyz.val.drop 0).take 4) (hy : fy.val = (pt.xyz.val.drop 4).take 4)
    (hz : fz.val = (pt.xyz.val.drop 8).take 4) :
    tripleNat pt.xyz.val = (feNat fx, feNat fy, feNat fz) := by
  simp only [tripleNat, feNat, hx, hy, hz, List.drop_zero, List.drop_drop]

theorem jrep_iff (P : P256Point) (pt : mid.p256.JacobianMontPoint) (fx fy fz : mid.p256.FieldElement)
    (hx : fx.val = (pt.xyz.val.drop 0).take 4) (hy : fy.val = (pt.xyz.val.drop 4).take 4)
    (hz : fz.val = (pt.xyz.val.drop 8).take 4) :
    jrep P pt ↔ feNat fx < p256 ∧ feNat fy < p256 ∧ feNat fz < p256 ∧
      P = if dec (feNat fz) = 0 then none
        else some ((dec (feNat fx) * (dec (feNat fz) ^ 2)⁻¹).val,
          (dec (feNat fy) * (dec (feNat fz) ^ 3)⁻¹).val) := by
  rw [jrep, tripleNat_eq pt fx fy fz hx hy hz, p256Represents]
  simp only [ofJacobian_dec, eq_comm (a := P)]

@[step]
theorem infinity_spec : mid.p256.JacobianMontPoint.infinity ⦃ pt => jrep none pt ⦄ := by
  unfold mid.p256.JacobianMontPoint.infinity
  simp only [WP.spec_ok, jrep, p256Represents, tripleNat, Array.make]
  refine ⟨by simp [wordsNat, Nat.ofDigits, p256], by simp [wordsNat, Nat.ofDigits, p256],
    by simp [wordsNat, Nat.ofDigits, p256], ?_⟩
  simp [wordsNat, Nat.ofDigits, p256OfJacobian]

@[step]
theorem is_infinity_spec (pt : mid.p256.JacobianMontPoint) (P : P256Point) (h : jrep P pt) :
    mid.p256.JacobianMontPoint.public_is_infinity pt ⦃ b => b ↔ P = none ⦄ := by
  unfold mid.p256.JacobianMontPoint.public_is_infinity mid.p256.FieldElement.Insts.CoreDefaultDefault.default
    core.default.DefaultArray.default
  step as ⟨fz, hfz⟩
  step as ⟨b, hb⟩
  have hz : (tripleNat pt.xyz.val).2.2 = feNat fz := by simp [tripleNat, feNat, hfz]
  obtain ⟨-, -, hzp, hP⟩ := h
  rw [ofJacobian_dec] at hP
  rw [hz] at hzp hP
  have h0 : feNat (Array.repeat 4#usize core.default.DefaultU64.default) = 0 := by
    simp [feNat, wordsNat, Array.repeat, Nat.ofDigits, core.default.DefaultU64.default]
  rw [hb, h0, ← hP]
  constructor
  · intro hz0; rw [hz0]; simp
  · intro hn
    by_contra hz0
    have : dec (feNat fz) ≠ 0 := fun hd => hz0 ((eq_of_dec _ 0 hzp p256_pos).mpr (by rw [hd]; simp))
    simp [this] at hn

end P256

end rind.aarch64
