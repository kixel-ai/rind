import Rind.N256Prime
import Mathlib.Algebra.Group.MinimalAxioms
import Mathlib.Algebra.Group.Int.Defs
import Mathlib.Tactic.LinearCombination
import Mathlib.Tactic.Abel

/-!
# Integer multiples of P-256's points

ECDSA verification adds signed multiples of two points in its own Rust, so its
result is u₁G + u₂Q by the group's laws, which `Rind.P256Group` proves of
`p256Add` from Mathlib's group: `P256Laws` collects those the proofs use. They
also need that a finite point's multiples below n are finite, which follows
from the group's order, n; that is `P256Order`, a hypothesis of the theorems
that need it.
-/

noncomputable section

namespace rind.spec

/-- Every finite point of the curve has order n, as HOL Light's
`P256_GROUP_ELEMENT_ORDER` proves from the group's size; the proofs here do not
count the curve's points,
https://github.com/jrh13/hol-light/blob/217dd32e798d98926d3ab81ed3dfcdf435831e1f/EC/nistp256.ml#L166 -/
def P256Order : Prop :=
  ∀ P, p256OnCurve P → P ≠ none → ∀ k, 0 < k → k < n256 → p256Pow P k ≠ none

/-- The facts of `p256_group` that ECDSA verification's Rust relies on: the
curve's points form an abelian group under `p256Add`, with infinity its
identity and `p256Neg` its inverse; `p256Pow` is repeated `p256Add`; and every
finite point has order n. `P256Laws.of_order` proves all but the last. -/
structure P256Laws : Prop where
  mul_none : ∀ P, p256OnCurve P → p256Add none P = P
  mul_comm : ∀ P Q, p256OnCurve P → p256OnCurve Q → p256Add P Q = p256Add Q P
  mul_assoc : ∀ P Q R, p256OnCurve P → p256OnCurve Q → p256OnCurve R →
    p256Add (p256Add P Q) R = p256Add P (p256Add Q R)
  mul_onCurve : ∀ P Q, p256OnCurve P → p256OnCurve Q → p256OnCurve (p256Add P Q)
  mul_neg : ∀ P, p256OnCurve P → p256Add P (p256Neg P) = none
  pow_zero : ∀ P, p256Pow P 0 = none
  pow_succ : ∀ P k, p256Pow P (k + 1) = p256Add P (p256Pow P k)
  order : ∀ P, p256OnCurve P → P ≠ none → ∀ k, 0 < k → k < n256 → p256Pow P k ≠ none

theorem p256_pos : 0 < p256 := p256_prime.pos

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
def twin (G Q : P256Point) (a b : Int) : P256Point := p256Add (p256ZPow G a) (p256ZPow Q b)

namespace P256Laws

variable (h : P256Laws)
include h

/-- The abelian group of the curve's points that `h` gives. -/
@[reducible] def group : AddCommGroup P256Curve :=
  letI : Add P256Curve := ⟨fun P Q => ⟨p256Add P.1 Q.1, h.mul_onCurve _ _ P.2 Q.2⟩⟩
  letI : Neg P256Curve := ⟨fun P => ⟨p256Neg P.1, p256Neg_onCurve _ P.2⟩⟩
  letI : Zero P256Curve := ⟨⟨none, trivial⟩⟩
  { AddGroup.ofLeftAxioms
      (fun a b c => Subtype.ext (h.mul_assoc _ _ _ a.2 b.2 c.2))
      (fun a => Subtype.ext (by change p256Add none a.1 = a.1; exact h.mul_none _ a.2))
      (fun a => Subtype.ext (by
        change p256Add (p256Neg a.1) a.1 = none
        rw [h.mul_comm _ _ (p256Neg_onCurve _ a.2) a.2]
        exact h.mul_neg _ a.2)) with
    add_comm := fun a b => Subtype.ext (h.mul_comm _ _ a.2 b.2) }

/-- `p256Pow` is the group's multiple. -/
theorem pow_eq_nsmul (P : P256Curve) (k : Nat) :
    letI := h.group
    p256Pow P.1 k = (k • P).1 := by
  let := h.group
  induction k with
  | zero => rw [h.pow_zero, zero_smul]; rfl
  | succ k ih =>
    rw [h.pow_succ, succ_nsmul, add_comm]
    exact congrArg (p256Add P.1) ih

theorem zpow_eq_zsmul (P : P256Curve) (z : Int) :
    letI := h.group
    p256ZPow P.1 z = (z • P).1 := by
  let := h.group
  cases z with
  | ofNat k => simp only [p256ZPow, Int.ofNat_eq_natCast, natCast_zsmul]; exact h.pow_eq_nsmul P k
  | negSucc k =>
    simp only [p256ZPow, negSucc_zsmul]
    exact congrArg p256Neg (h.pow_eq_nsmul P (k + 1))

theorem zpow_onCurve (P : P256Point) (hP : p256OnCurve P) (z : Int) : p256OnCurve (p256ZPow P z) := by
  rw [h.zpow_eq_zsmul ⟨P, hP⟩]; exact Subtype.property _

omit h in
theorem zpow_natCast (P : P256Point) (k : Nat) : p256ZPow P k = p256Pow P k := rfl

theorem mul_zpow (P : P256Point) (hP : p256OnCurve P) (a b : Int) :
    p256Add (p256ZPow P a) (p256ZPow P b) = p256ZPow P (a + b) := by
  let := h.group
  rw [h.zpow_eq_zsmul ⟨P, hP⟩, h.zpow_eq_zsmul ⟨P, hP⟩, h.zpow_eq_zsmul ⟨P, hP⟩, add_zsmul]
  rfl

theorem neg_zpow (P : P256Point) (hP : p256OnCurve P) (a : Int) :
    p256Neg (p256ZPow P a) = p256ZPow P (-a) := by
  let := h.group
  rw [h.zpow_eq_zsmul ⟨P, hP⟩, h.zpow_eq_zsmul ⟨P, hP⟩, neg_zsmul]
  rfl

theorem twin_zero (G Q : P256Point) (hG : p256OnCurve G) (hQ : p256OnCurve Q) :
    twin G Q 0 0 = none := by
  let := h.group
  unfold twin
  rw [h.zpow_eq_zsmul ⟨G, hG⟩, h.zpow_eq_zsmul ⟨Q, hQ⟩, zero_smul, zero_smul]
  exact h.mul_none none trivial

theorem twin_onCurve (G Q : P256Point) (hG : p256OnCurve G) (hQ : p256OnCurve Q) (a b : Int) :
    p256OnCurve (twin G Q a b) :=
  h.mul_onCurve _ _ (h.zpow_onCurve G hG a) (h.zpow_onCurve Q hQ b)

theorem twin_double (G Q : P256Point) (hG : p256OnCurve G) (hQ : p256OnCurve Q) (a b : Int) :
    p256Add (twin G Q a b) (twin G Q a b) = twin G Q (2 * a) (2 * b) := by
  let := h.group
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
    p256Add (twin G Q a b) (p256ZPow G d) = twin G Q (a + d) b := by
  let := h.group
  unfold twin
  rw [h.zpow_eq_zsmul ⟨G, hG⟩, h.zpow_eq_zsmul ⟨Q, hQ⟩, h.zpow_eq_zsmul ⟨G, hG⟩,
    h.zpow_eq_zsmul ⟨G, hG⟩]
  change ((_ + _) + _ : P256Curve).1 = (_ + _ : P256Curve).1
  rw [add_zsmul]
  congr 1
  abel

theorem twin_add_right (G Q : P256Point) (hG : p256OnCurve G) (hQ : p256OnCurve Q) (a b d : Int) :
    p256Add (twin G Q a b) (p256ZPow Q d) = twin G Q a (b + d) := by
  let := h.group
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
  let := h.group
  have hpos : 0 < z.natAbs := Int.natAbs_pos.mpr hz0
  rcases Int.natAbs_eq z with hz' | hz'
  · rw [hz', P256Laws.zpow_natCast]; exact h.order P hP hne _ hpos hz
  · rw [hz', ← h.neg_zpow P hP, P256Laws.zpow_natCast]
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
  let := h.group
  rw [h.zpow_eq_zsmul ⟨P, hP⟩, zero_smul]; rfl

theorem zpow_one (P : P256Point) (hP : p256OnCurve P) : p256ZPow P 1 = P := by
  let := h.group
  rw [h.zpow_eq_zsmul ⟨P, hP⟩, one_zsmul]

end P256Laws

theorem onCurve_fromM (X : p256Curve.Point) : p256OnCurve (fromM X) := by
  match X with
  | .zero => trivial
  | .some x y h =>
    refine ⟨ZMod.val_lt x, ZMod.val_lt y, ?_⟩
    have he := h.1
    rw [WeierstrassCurve.Affine.equation_iff] at he
    simp only [p256Curve, WeierstrassCurve.toAffine] at he
    rw [← ZMod.natCast_eq_natCast_iff']
    push_cast [Nat.cast_sub (show 3 ≤ p256 by simp [p256])]
    rw [ZMod.natCast_self, ZMod.natCast_val, ZMod.natCast_val]
    simp only [ZMod.cast_id', id]
    linear_combination he

theorem neg_fromM (X : p256Curve.Point) : p256Neg (fromM X) = fromM (-X) := by
  match X with
  | .zero => rfl
  | .some x y h =>
    simp only [fromM, WeierstrassCurve.Affine.Point.neg_some, p256Neg, negY_eq, Option.some.injEq,
      Prod.mk.injEq, true_and]
    have h1 := natCast_neg_mod y.val
    rw [ZMod.natCast_val, ZMod.cast_id', id] at h1
    rw [← h1, ZMod.val_natCast, Nat.mod_eq_of_lt (Nat.mod_lt _ p256_pos)]

theorem exists_fromM (P : P256Point) (hP : p256OnCurve P) : ∃ X, fromM X = P := by
  match P, hP with
  | none, _ => exact ⟨0, rfl⟩
  | some (x, y), h => exact fromM_of_onCurve h

/-- The group's laws, proven from Mathlib's group, with its order. -/
theorem P256Laws.of_order (h : P256Order) : P256Laws where
  mul_none P _ := by cases P <;> rfl
  mul_comm P Q hP hQ := by
    obtain ⟨X, rfl⟩ := exists_fromM P hP
    obtain ⟨Y, rfl⟩ := exists_fromM Q hQ
    rw [fromM_add, fromM_add, add_comm]
  mul_assoc P Q R hP hQ hR := by
    obtain ⟨X, rfl⟩ := exists_fromM P hP
    obtain ⟨Y, rfl⟩ := exists_fromM Q hQ
    obtain ⟨Z, rfl⟩ := exists_fromM R hR
    rw [fromM_add, fromM_add, fromM_add, fromM_add, add_assoc]
  mul_onCurve P Q hP hQ := by
    obtain ⟨X, rfl⟩ := exists_fromM P hP
    obtain ⟨Y, rfl⟩ := exists_fromM Q hQ
    rw [fromM_add]; exact onCurve_fromM _
  mul_neg P hP := by
    obtain ⟨X, rfl⟩ := exists_fromM P hP
    rw [neg_fromM, fromM_add, add_neg_cancel]; rfl
  pow_zero _ := rfl
  pow_succ _ _ := rfl
  order := h

end rind.spec

end
