import Rind.Ed25519Group
open rind.edwards

/-!
# edwards25519's extended coordinates and dalek's formulas

curve25519-dalek's AVX2 backend holds a point in extended coordinates
`(X, Y, Z, T)`, `Z` times `(x, y, 1, xy)`, and the point it adds as cached
coordinates, a nonzero multiple of `(y - x, y + x, 2, 2dxy)`. Its doubling and
addition are Hisil, Wong, Carter, and Dawson's formulas for `a = -1`
(`dbl-2008-hwcd` and `add-2008-hwcd-3`), as dalek's `double` and `add`
arrange them over four lanes. These prove each gives the coordinates of the
group's sum, whose denominators completeness keeps nonzero.
-/

namespace rind.spec

/-- The field of edwards25519's coordinates. -/
abbrev Fp := ZMod p25519

/-- `(X, Y, Z, T)` are extended coordinates of `P`: `Z` times `(x, y, 1, xy)`,
for `Z ≠ 0`. -/
def IsExtended (P : Point dF) (X Y Z T : Fp) : Prop :=
  Z ≠ 0 ∧ X = Z * P.1.1 ∧ Y = Z * P.1.2 ∧ T = Z * (P.1.1 * P.1.2)

/-- `(A, B, C, D)` are cached coordinates of `P`: `μ` times
`(y - x, y + x, 2, 2dxy)`, for `μ ≠ 0`. -/
def IsCached (P : Point dF) (A B C D : Fp) : Prop :=
  ∃ μ : Fp, μ ≠ 0 ∧ A = μ * (P.1.2 - P.1.1) ∧ B = μ * (P.1.2 + P.1.1) ∧ C = 2 * μ ∧
    D = 2 * dF * μ * (P.1.1 * P.1.2)

theorem fp_two_ne_zero : (2 : Fp) ≠ 0 := Complete.two_ne_zero (d := dF)

theorem isExtended_zero : IsExtended 0 0 1 1 0 := by
  simp [IsExtended]

/-- The affine coordinates of extended ones. -/
theorem IsExtended.coords {P : Point dF} {X Y Z T : Fp} (h : IsExtended P X Y Z T) :
    P.1 = (X * Z⁻¹, Y * Z⁻¹) := by
  obtain ⟨hZ, hX, hY, -⟩ := h
  rw [hX, hY]
  ext <;> field_simp

/-- dalek's `add` of extended and cached coordinates, `add-2008-hwcd-3`. -/
theorem IsExtended.add {P Q : Point dF} {X Y Z T A B C D : Fp} (hP : IsExtended P X Y Z T)
    (hQ : IsCached Q A B C D) :
    let a := (Y - X) * A
    let b := (Y + X) * B
    let d := Z * C
    let c := T * D
    IsExtended (P + Q) ((b - a) * (d - c)) ((d + c) * (b + a)) ((d - c) * (d + c))
      ((b - a) * (b + a)) := by
  obtain ⟨hZ, rfl, rfl, rfl⟩ := hP
  obtain ⟨μ, hμ, rfl, rfl, rfl, rfl⟩ := hQ
  simp only [IsExtended, Point.val_add]
  obtain ⟨⟨x1, y1⟩, h1⟩ := P
  obtain ⟨⟨x2, y2⟩, h2⟩ := Q
  have hp := one_add_ne_zero h1 h2
  have hm := one_sub_ne_zero h1 h2
  simp only [rind.edwards.add] at *
  refine ⟨?_, ?_, ?_, ?_⟩
  · have : (Z * (2 * μ) - Z * (x1 * y1) * (2 * dF * μ * (x2 * y2))) *
        (Z * (2 * μ) + Z * (x1 * y1) * (2 * dF * μ * (x2 * y2))) =
        (2 * Z * μ) ^ 2 * ((1 - dF * x1 * x2 * y1 * y2) * (1 + dF * x1 * x2 * y1 * y2)) := by ring
    rw [this]
    exact mul_ne_zero (pow_ne_zero 2 (mul_ne_zero (mul_ne_zero fp_two_ne_zero hZ) hμ))
      (mul_ne_zero hm hp)
  · rw [mul_div_assoc', eq_div_iff hp]
    ring
  · rw [mul_div_assoc', eq_div_iff hm]
    ring
  · rw [div_mul_div_comm, mul_div_assoc', eq_div_iff (mul_ne_zero hp hm)]
    ring

/-- dalek's `double`, `dbl-2008-hwcd` with its terms negated: with `S1 = X²`,
`S2 = Y²`, `S3 = Z²`, and `S4 = (X + Y)²`, the lanes `(S1 + S2, S1 - S2,
2S3 + S1 - S2, S1 + S2 - S4)` multiply to the double's coordinates. -/
theorem IsExtended.double {P : Point dF} {X Y Z T : Fp} (hP : IsExtended P X Y Z T) :
    let a := X ^ 2 + Y ^ 2
    let b := X ^ 2 - Y ^ 2
    let c := 2 * Z ^ 2 + X ^ 2 - Y ^ 2
    let d := X ^ 2 + Y ^ 2 - (X + Y) ^ 2
    IsExtended (P + P) (c * d) (a * b) (c * b) (a * d) := by
  obtain ⟨hZ, rfl, rfl, -⟩ := hP
  simp only [IsExtended, Point.val_add]
  obtain ⟨⟨x, y⟩, h⟩ := P
  have hp := one_add_ne_zero h h
  have hm := one_sub_ne_zero h h
  have hc : -x ^ 2 + y ^ 2 = 1 + dF * x ^ 2 * y ^ 2 := h
  simp only [rind.edwards.add] at *
  refine ⟨?_, ?_, ?_, ?_⟩
  · have e : (2 * Z ^ 2 + (Z * x) ^ 2 - (Z * y) ^ 2) * ((Z * x) ^ 2 - (Z * y) ^ 2) =
        -(Z ^ 2) ^ 2 * ((1 - dF * x * x * y * y) * (1 + dF * x * x * y * y)) := by
      linear_combination (Z ^ 4 * (-x ^ 2 + y ^ 2 - 1 + dF * x * x * y * y)) * hc
    rw [e]
    exact mul_ne_zero (neg_ne_zero.mpr (pow_ne_zero 2 (pow_ne_zero 2 hZ))) (mul_ne_zero hm hp)
  · rw [mul_div_assoc', eq_div_iff hp]
    linear_combination (2 * Z ^ 2 * x * y * (2 * Z ^ 2 + (Z * x) ^ 2 - (Z * y) ^ 2)) * hc
  · rw [mul_div_assoc', eq_div_iff hm]
    linear_combination (((Z * x) ^ 2 - (Z * y) ^ 2) * Z ^ 2 * (y * y + x * x)) * hc
  · rw [div_mul_div_comm, mul_div_assoc', eq_div_iff (mul_ne_zero hp hm)]
    linear_combination
      (-(Z ^ 4) * (x * y + y * x) * (y * y + x * x) * (-x ^ 2 + y ^ 2 - 1 + dF * x * x * y * y)) * hc

/-- dalek's `Cached::from`: `(Y - X, Y + X, Z, T)` scaled by `121666` in the
first two lanes, `2 · 121666` and `2 · 121665` in the last, then the last
negated, since `121666 d = -121665`. -/
theorem IsExtended.cached {P : Point dF} {X Y Z T : Fp} (hP : IsExtended P X Y Z T) :
    IsCached P (121666 * (Y - X)) (121666 * (Y + X)) (2 * 121666 * Z) (-(2 * 121665 * T)) := by
  obtain ⟨hZ, rfl, rfl, rfl⟩ := hP
  have hd : (121666 : Fp) * dF = -121665 := by
    simp only [dF]
    decide +kernel
  refine ⟨121666 * Z, mul_ne_zero ?_ hZ, by ring, by ring, by ring, ?_⟩
  · rw [show (121666 : Fp) = ((121666 : ℕ) : Fp) by norm_num, Ne, ZMod.natCast_eq_zero_iff]
    decide +kernel
  · linear_combination (-2 * Z * (P.1.1 * P.1.2)) * hd

/-- dalek's `Cached::neg`: the first two lanes swapped and the last negated. -/
theorem IsCached.neg {P : Point dF} {A B C D : Fp} (h : IsCached P A B C D) :
    IsCached (-P) B A C (-D) := by
  obtain ⟨μ, hμ, rfl, rfl, rfl, rfl⟩ := h
  exact ⟨μ, hμ, by simp only [Point.val_neg]; ring, by simp only [Point.val_neg]; ring, rfl,
    by simp only [Point.val_neg]; ring⟩

end rind.spec
