import Rind.Prime
import Mathlib.Algebra.Group.MinimalAxioms
import Mathlib.Algebra.Group.Int.Defs
import Mathlib.Tactic.LinearCombination
import Mathlib.Tactic.Abel

/-!
# P-256's group laws, as the ECDSA verification theorems assume them

ECDSA verification adds multiples of two points in its own Rust, so its
result is u₁G + u₂Q only by the group's laws, which `p256Mul` and `p256Pow`,
opaque, do not give. `P256Group` states them; HOL Light proves each of
`p256_group`, and the theorems that need them take it as a hypothesis.
-/

namespace rind.spec

/-- The facts of `p256_group` that ECDSA verification's Rust relies on: the
curve's points form an abelian group under `p256Mul` (`ABELIAN_P256_GROUP`),
with infinity its identity and `p256Neg` its inverse (`P256_GROUP`);
`p256Pow` is repeated `p256Mul` (`group_pow`'s definition); and every finite
point has order n (`P256_GROUP_ELEMENT_ORDER`),
https://github.com/jrh13/hol-light/blob/217dd32e798d98926d3ab81ed3dfcdf435831e1f/EC/nistp256.ml#L82 -/
structure P256Group : Prop where
  mul_none : ∀ P, p256OnCurve P → p256Mul none P = P
  mul_comm : ∀ P Q, p256OnCurve P → p256OnCurve Q → p256Mul P Q = p256Mul Q P
  mul_assoc : ∀ P Q R, p256OnCurve P → p256OnCurve Q → p256OnCurve R →
    p256Mul (p256Mul P Q) R = p256Mul P (p256Mul Q R)
  mul_onCurve : ∀ P Q, p256OnCurve P → p256OnCurve Q → p256OnCurve (p256Mul P Q)
  mul_neg : ∀ P, p256OnCurve P → p256Mul P (p256Neg P) = none
  pow_zero : ∀ P, p256Pow P 0 = none
  pow_succ : ∀ P k, p256Pow P (k + 1) = p256Mul P (p256Pow P k)
  order : ∀ P, p256OnCurve P → P ≠ none → ∀ k, 0 < k → k < n256 → p256Pow P k ≠ none

instance : Fact (Nat.Prime p256) := ⟨prime_p256⟩

theorem p256_pos : 0 < p256 := prime_p256.pos

theorem natCast_neg_mod (y : Nat) : (((p256 - y % p256) % p256 : Nat) : ZMod p256) = -(y : ZMod p256) := by
  have hy : y % p256 < p256 := Nat.mod_lt _ p256_pos
  rw [ZMod.natCast_mod, Nat.cast_sub hy.le, ZMod.natCast_self, zero_sub, ZMod.natCast_mod]

theorem p256Neg_onCurve (P : P256Point) (h : p256OnCurve P) : p256OnCurve (p256Neg P) := by
  match P, h with
  | none, _ => trivial
  | some (x, y), ⟨hx, hy, he⟩ =>
    refine ⟨hx, Nat.mod_lt _ p256_pos, ?_⟩
    rw [← ZMod.natCast_eq_natCast_iff'] at he ⊢
    push_cast at he ⊢
    rw [natCast_neg_mod, neg_sq, he]

/-- `P` multiplied by the integer `z`, as `p256_group`'s `group_zpow`. -/
def p256ZPow (P : P256Point) : Int → P256Point
  | .ofNat k => p256Pow P k
  | .negSucc k => p256Neg (p256Pow P (k + 1))

/-- The curve's points. -/
abbrev P256Curve := {P : P256Point // p256OnCurve P}

/-- `a`G + `b`Q. -/
def twin (G Q : P256Point) (a b : Int) : P256Point := p256Mul (p256ZPow G a) (p256ZPow Q b)

namespace P256Group

variable (h : P256Group)
include h

/-- The abelian group of the curve's points that `h` gives. -/
@[reducible] def group : AddCommGroup P256Curve :=
  letI : Add P256Curve := ⟨fun P Q => ⟨p256Mul P.1 Q.1, h.mul_onCurve _ _ P.2 Q.2⟩⟩
  letI : Neg P256Curve := ⟨fun P => ⟨p256Neg P.1, p256Neg_onCurve _ P.2⟩⟩
  letI : Zero P256Curve := ⟨⟨none, trivial⟩⟩
  { AddGroup.ofLeftAxioms
      (fun a b c => Subtype.ext (h.mul_assoc _ _ _ a.2 b.2 c.2))
      (fun a => Subtype.ext (h.mul_none _ a.2))
      (fun a => Subtype.ext (by
        change p256Mul (p256Neg a.1) a.1 = none
        rw [h.mul_comm _ _ (p256Neg_onCurve _ a.2) a.2]
        exact h.mul_neg _ a.2)) with
    add_comm := fun a b => Subtype.ext (h.mul_comm _ _ a.2 b.2) }

/-- `p256Pow` is the group's multiple. -/
theorem pow_eq_nsmul (P : P256Curve) (k : Nat) :
    letI := h.group
    p256Pow P.1 k = (k • P).1 := by
  letI := h.group
  induction k with
  | zero => rw [h.pow_zero, zero_smul]; rfl
  | succ k ih =>
    rw [h.pow_succ, succ_nsmul, add_comm]
    exact congrArg (p256Mul P.1) ih

theorem zpow_eq_zsmul (P : P256Curve) (z : Int) :
    letI := h.group
    p256ZPow P.1 z = (z • P).1 := by
  letI := h.group
  cases z with
  | ofNat k => simp only [p256ZPow, Int.ofNat_eq_natCast, natCast_zsmul]; exact h.pow_eq_nsmul P k
  | negSucc k =>
    simp only [p256ZPow, negSucc_zsmul]
    exact congrArg p256Neg (h.pow_eq_nsmul P (k + 1))

theorem zpow_onCurve (P : P256Point) (hP : p256OnCurve P) (z : Int) : p256OnCurve (p256ZPow P z) := by
  rw [h.zpow_eq_zsmul ⟨P, hP⟩]; exact Subtype.property _

theorem zpow_natCast (P : P256Point) (k : Nat) : p256ZPow P k = p256Pow P k := rfl

theorem mul_zpow (P : P256Point) (hP : p256OnCurve P) (a b : Int) :
    p256Mul (p256ZPow P a) (p256ZPow P b) = p256ZPow P (a + b) := by
  letI := h.group
  rw [h.zpow_eq_zsmul ⟨P, hP⟩, h.zpow_eq_zsmul ⟨P, hP⟩, h.zpow_eq_zsmul ⟨P, hP⟩, add_zsmul]
  rfl

theorem neg_zpow (P : P256Point) (hP : p256OnCurve P) (a : Int) :
    p256Neg (p256ZPow P a) = p256ZPow P (-a) := by
  letI := h.group
  rw [h.zpow_eq_zsmul ⟨P, hP⟩, h.zpow_eq_zsmul ⟨P, hP⟩, neg_zsmul]
  rfl

theorem twin_zero (G Q : P256Point) (hG : p256OnCurve G) (hQ : p256OnCurve Q) :
    twin G Q 0 0 = none := by
  letI := h.group
  unfold twin
  rw [h.zpow_eq_zsmul ⟨G, hG⟩, h.zpow_eq_zsmul ⟨Q, hQ⟩, zero_smul, zero_smul]
  exact h.mul_none none trivial

theorem twin_onCurve (G Q : P256Point) (hG : p256OnCurve G) (hQ : p256OnCurve Q) (a b : Int) :
    p256OnCurve (twin G Q a b) :=
  h.mul_onCurve _ _ (h.zpow_onCurve G hG a) (h.zpow_onCurve Q hQ b)

theorem twin_double (G Q : P256Point) (hG : p256OnCurve G) (hQ : p256OnCurve Q) (a b : Int) :
    p256Mul (twin G Q a b) (twin G Q a b) = twin G Q (2 * a) (2 * b) := by
  letI := h.group
  have e : ∀ c d, twin G Q c d = ((c • (⟨G, hG⟩ : P256Curve)) + d • (⟨Q, hQ⟩ : P256Curve)).1 := by
    intro c d
    unfold twin
    rw [h.zpow_eq_zsmul ⟨G, hG⟩, h.zpow_eq_zsmul ⟨Q, hQ⟩]
    rfl
  rw [e, e, mul_zsmul, mul_zsmul]
  change ((_ + _) + (_ + _) : P256Curve).1 = _
  congr 1
  simp only [two_zsmul]
  abel

theorem twin_add_left (G Q : P256Point) (hG : p256OnCurve G) (hQ : p256OnCurve Q) (a b d : Int) :
    p256Mul (twin G Q a b) (p256ZPow G d) = twin G Q (a + d) b := by
  letI := h.group
  unfold twin
  rw [h.zpow_eq_zsmul ⟨G, hG⟩, h.zpow_eq_zsmul ⟨Q, hQ⟩, h.zpow_eq_zsmul ⟨G, hG⟩,
    h.zpow_eq_zsmul ⟨G, hG⟩]
  change ((_ + _) + _ : P256Curve).1 = (_ + _ : P256Curve).1
  rw [add_zsmul]
  congr 1
  abel

theorem twin_add_right (G Q : P256Point) (hG : p256OnCurve G) (hQ : p256OnCurve Q) (a b d : Int) :
    p256Mul (twin G Q a b) (p256ZPow Q d) = twin G Q a (b + d) := by
  letI := h.group
  unfold twin
  rw [h.zpow_eq_zsmul ⟨G, hG⟩, h.zpow_eq_zsmul ⟨Q, hQ⟩, h.zpow_eq_zsmul ⟨Q, hQ⟩,
    h.zpow_eq_zsmul ⟨Q, hQ⟩]
  change ((_ + _) + _ : P256Curve).1 = (_ + _ : P256Curve).1
  rw [add_zsmul]
  congr 1
  abel

/-- A finite point's multiples are finite below its order, n. -/
theorem zpow_ne_none (P : P256Point) (hP : p256OnCurve P) (hne : P ≠ none) (z : Int)
    (hz0 : z ≠ 0) (hz : z.natAbs < n256) : p256ZPow P z ≠ none := by
  letI := h.group
  have hpos : 0 < z.natAbs := Int.natAbs_pos.mpr hz0
  rcases Int.natAbs_eq z with hz' | hz'
  · rw [hz', h.zpow_natCast]; exact h.order P hP hne _ hpos hz
  · rw [hz', ← h.neg_zpow P hP, h.zpow_natCast]
    intro hn
    apply h.order P hP hne _ hpos hz
    have := congrArg p256Neg hn
    match hq : p256Pow P z.natAbs with
    | none => rfl
    | some _ => rw [hq] at hn; simp [p256Neg] at hn

/-- Distinct multiples of a finite point are distinct when they differ by less
than its order. -/
theorem zpow_ne (P : P256Point) (hP : p256OnCurve P) (hne : P ≠ none) (a b : Int) (hab : a ≠ b)
    (hn : (a - b).natAbs < n256) : p256ZPow P a ≠ p256ZPow P b := by
  intro heq
  apply h.zpow_ne_none P hP hne (a - b) (sub_ne_zero.mpr hab) hn
  rw [sub_eq_add_neg, ← h.mul_zpow P hP, heq, h.mul_zpow P hP, add_neg_cancel]
  letI := h.group
  rw [h.zpow_eq_zsmul ⟨P, hP⟩, zero_smul]; rfl

theorem zpow_one (P : P256Point) (hP : p256OnCurve P) : p256ZPow P 1 = P := by
  letI := h.group
  rw [h.zpow_eq_zsmul ⟨P, hP⟩, one_zsmul]

end P256Group

end rind.spec
