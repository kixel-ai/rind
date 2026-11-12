import Rind.Ed25519
import Rind.Edwards
import Rind.P256Group
import Mathlib.Tactic.NormNum.LegendreSymbol
open rind.edwards

/-!
# edwards25519's group law

`edMul` and `edPow`, HOL Light's `group_mul edwards25519_group` and
`group_pow edwards25519_group`, are the addition and multiples of
`Rind.Edwards`'s group of points on the curve over `ZMod p25519`, for `d` the
curve's: `edMul_ofPoint` and `edPow_ofPoint`. So their laws, such as
`edPow P (m + n) = edMul (edPow P m) (edPow P n)`, are that group's, which no
axiom states.

The group needs `ZMod p25519` to be a field, so `p25519` is proven prime by a
Pratt certificate, as `Rind.P256Group` proves `p256`'s, and complete
addition needs `d` to be a non-square, which the kernel checks by its
Legendre symbol.
-/

namespace rind.spec

/-! ## `p25519` is prime -/

theorem prime_8574133 : Nat.Prime 8574133 := by norm_num

theorem prime_1919519569386763 : Nat.Prime 1919519569386763 :=
  prime_of_lucas 2 [(2, 1), (3, 1), (7, 1), (19, 1), (47, 2), (127, 1), (8574133, 1)]
    (by decide +kernel) ⟨by norm_num, by norm_num, by norm_num, by norm_num, by norm_num, by norm_num,
      prime_8574133, trivial⟩

theorem prime_2773320623 : Nat.Prime 2773320623 :=
  prime_of_lucas 5 [(2, 1), (2437, 1), (569003, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, trivial⟩

theorem prime_72106336199 : Nat.Prime 72106336199 :=
  prime_of_lucas 7 [(2, 1), (13, 1), (2773320623, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, prime_2773320623, trivial⟩

theorem prime_75445702479781427272750846543864801 :
    Nat.Prime 75445702479781427272750846543864801 :=
  prime_of_lucas 7 [(2, 5), (3, 2), (5, 2), (75707, 1), (72106336199, 1), (1919519569386763, 1)]
    (by decide +kernel) ⟨by norm_num, by norm_num, by norm_num, by norm_num, prime_72106336199,
      prime_1919519569386763, trivial⟩

theorem prime_31757755568855353 : Nat.Prime 31757755568855353 :=
  prime_of_lucas 10 [(2, 3), (3, 1), (31, 1), (107, 1), (223, 1), (4153, 1), (430751, 1)]
    (by decide +kernel) ⟨by norm_num, by norm_num, by norm_num, by norm_num, by norm_num, by norm_num,
      by norm_num, trivial⟩

theorem prime_1923133 : Nat.Prime 1923133 := by norm_num

theorem prime_74058212732561358302231226437062788676166966415465897661863160754340907 :
    Nat.Prime 74058212732561358302231226437062788676166966415465897661863160754340907 :=
  prime_of_lucas 2 [(2, 1), (3, 1), (353, 1), (57467, 1), (132049, 1), (1923133, 1),
      (31757755568855353, 1), (75445702479781427272750846543864801, 1)]
    (by decide +kernel) ⟨by norm_num, by norm_num, by norm_num, by norm_num, by norm_num,
      prime_1923133, prime_31757755568855353, prime_75445702479781427272750846543864801, trivial⟩

theorem p25519_prime : p25519.Prime :=
  prime_of_lucas 2 [(2, 2), (3, 1), (65147, 1),
      (74058212732561358302231226437062788676166966415465897661863160754340907, 1)]
    (by decide +kernel) ⟨by norm_num, by norm_num, by norm_num,
      prime_74058212732561358302231226437062788676166966415465897661863160754340907, trivial⟩

instance : Fact p25519.Prime := ⟨p25519_prime⟩

/-! ## The curve's group -/

/-- The curve's `d`, in the field. -/
abbrev dF : ZMod p25519 := d25519

theorem e25519_eq : (e25519 : ZMod p25519) = -1 := by
  rw [show e25519 = p25519 - 1 by norm_num [e25519, p25519], Nat.cast_sub (by norm_num [p25519]),
    ZMod.natCast_self, Nat.cast_one, zero_sub]

/-- `d` is not a square, by its Legendre symbol. -/
theorem dF_not_square : ¬IsSquare dF := by
  apply (legendreSym.eq_neg_one_iff' p25519).mp
  norm_num [dF, d25519, p25519]

instance : Complete dF where
  two_ne_zero := by
    rw [show (2 : ZMod p25519) = ((2 : ℕ) : ZMod p25519) by norm_num, Ne,
      ZMod.natCast_eq_zero_iff]
    decide +kernel
  neg_one_square := ZMod.exists_sq_eq_neg_one_iff.mpr (by unfold p25519; decide)
  not_square := dF_not_square

/-- The point of the group whose coordinates' values are these. -/
def ofPoint (Q : Point dF) : EdPoint := ((Q.1.1.val : Int), (Q.1.2.val : Int))

theorem cast_ofPoint_fst (Q : Point dF) : ((ofPoint Q).1 : ZMod p25519) = Q.1.1 := by
  simp [ofPoint]

theorem cast_ofPoint_snd (Q : Point dF) : ((ofPoint Q).2 : ZMod p25519) = Q.1.2 := by
  simp [ofPoint]

theorem ofPoint_injective : Function.Injective ofPoint := by
  intro Q R h
  apply Point.ext
  rw [Prod.ext_iff, ← cast_ofPoint_fst Q, ← cast_ofPoint_snd Q, ← cast_ofPoint_fst R,
    ← cast_ofPoint_snd R, h]
  exact ⟨rfl, rfl⟩

theorem onCurve_iff (P : EdPoint) :
    edOnCurve P ↔ 0 ≤ P.1 ∧ P.1 < p25519 ∧ 0 ≤ P.2 ∧ P.2 < p25519 ∧
      OnCurve dF ((P.1 : ZMod p25519), (P.2 : ZMod p25519)) := by
  unfold edOnCurve OnCurve
  rw [← ZMod.intCast_eq_intCast_iff']
  push_cast
  rw [e25519_eq]
  constructor <;> rintro ⟨h0, h1, h2, h3, h4⟩ <;> exact ⟨h0, h1, h2, h3, by linear_combination h4⟩

theorem edOnCurve_ofPoint (Q : Point dF) : edOnCurve (ofPoint Q) := by
  rw [onCurve_iff, cast_ofPoint_fst, cast_ofPoint_snd]
  exact ⟨Int.natCast_nonneg _, Int.ofNat_lt.mpr (ZMod.val_lt Q.1.1), Int.natCast_nonneg _,
    Int.ofNat_lt.mpr (ZMod.val_lt Q.1.2), Q.2⟩

/-- The point of the group a point on the curve names. -/
def toPoint (P : EdPoint) (h : edOnCurve P) : Point dF :=
  ⟨((P.1 : ZMod p25519), (P.2 : ZMod p25519)), ((onCurve_iff P).mp h).2.2.2.2⟩

theorem ofPoint_toPoint (P : EdPoint) (h : edOnCurve P) : ofPoint (toPoint P h) = P := by
  obtain ⟨h0, h1, h2, h3, -⟩ := (onCurve_iff P).mp h
  simp only [ofPoint, toPoint, ZMod.val_intCast, Int.emod_eq_of_lt h0 h1, Int.emod_eq_of_lt h2 h3]

/-- Each point on the curve is one of the group's. -/
theorem exists_ofPoint {P : EdPoint} (h : edOnCurve P) : ∃ Q, ofPoint Q = P :=
  ⟨toPoint P h, ofPoint_toPoint P h⟩

/-- `edMul` is the group's addition. -/
theorem edMul_ofPoint (Q R : Point dF) : edMul (ofPoint Q) (ofPoint R) = ofPoint (Q + R) := by
  simp only [edMul, cast_ofPoint_fst, cast_ofPoint_snd, e25519_eq]
  simp only [ofPoint, Point.val_add, add, div_eq_mul_inv]
  congr 3 <;> ring

/-- `edPow` is the group's multiples. -/
theorem edPow_ofPoint (Q : Point dF) (n : Nat) : edPow (ofPoint Q) n = ofPoint (n • Q) := by
  induction n with
  | zero => simp [edPow, ofPoint, ZMod.val_one]
  | succ n ih => rw [edPow, ih, edMul_ofPoint, succ_nsmul, add_comm]

/-- `edNeg` is the group's negation. -/
theorem edNeg_ofPoint (Q : Point dF) : edNeg (ofPoint Q) = ofPoint (-Q) := by
  simp only [edNeg, ofPoint, Point.val_neg, Prod.mk.injEq, and_true]
  rw [← ZMod.val_intCast]
  push_cast
  simp

end rind.spec
