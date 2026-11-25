import Rind.Ed25519
import Rind.Pratt
import Mathlib.GroupTheory.OrderOfElement
import Mathlib.Data.Int.GCD
open Aeneas Aeneas.Std rind.spec

/-!
# edwards25519's group law

`Rind.Ed25519` leaves the group's multiplication and power opaque. The half-
size check of Ed25519 verification, `mid::half_size`, rests on the group being
abelian of order `8L`, so each axiom here restates one of HOL Light's theorems
about `edwards25519_group` in `EC/edwards25519.ml` and the group theory of
`Library/grouptheory.ml`, at
https://github.com/jrh13/hol-light/blob/217dd32e798d98926d3ab81ed3dfcdf435831e1f,
or s2n-bignum's about its encoding. From them, `half_size_iff` proves the
check's argument, which `mid/half_size.rs`'s module doc gives: for
`u ≡ v k (mod 8L)` with `v` odd and below `L`, `[v S mod L]B - [v]R - [u]A` is
the identity exactly when `R = [S]B - [k]A`.
-/

namespace rind.spec

/-! ## `p` and `L` are prime, by Pratt certificates -/

namespace ed25519

theorem prime_14741173 : Nat.Prime 14741173 :=
  prime_of_lucas 2 [(2, 2), (3, 2), (409477, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, trivial⟩

theorem prime_58964693 : Nat.Prime 58964693 :=
  prime_of_lucas 2 [(2, 2), (14741173, 1)] (by decide +kernel)
    ⟨by norm_num, prime_14741173, trivial⟩

theorem prime_3044861653679985063343 : Nat.Prime 3044861653679985063343 :=
  prime_of_lucas 5 [(2, 1), (3, 1), (11, 1), (30703, 1), (82163, 1), (132667, 1), (137849, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, by norm_num, by norm_num, by norm_num, by norm_num, trivial⟩

theorem prime_198211423230930754013084525763697 : Nat.Prime 198211423230930754013084525763697 :=
  prime_of_lucas 5 [(2, 4), (3, 1), (23, 1), (58964693, 1), (3044861653679985063343, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, prime_58964693, prime_3044861653679985063343, trivial⟩

theorem prime_292386187 : Nat.Prime 292386187 :=
  prime_of_lucas 2 [(2, 1), (3, 4), (307, 1), (5879, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, by norm_num, trivial⟩

theorem prime_213441916511 : Nat.Prime 213441916511 :=
  prime_of_lucas 13 [(2, 1), (5, 1), (73, 1), (292386187, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, prime_292386187, trivial⟩

theorem prime_1224481 : Nat.Prime 1224481 :=
  prime_of_lucas 13 [(2, 5), (3, 1), (5, 1), (2551, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, by norm_num, trivial⟩

theorem prime_1257559732178653 : Nat.Prime 1257559732178653 :=
  prime_of_lucas 2 [(2, 2), (3, 1), (7, 1), (23, 1), (531581, 1), (1224481, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, by norm_num, by norm_num, prime_1224481, trivial⟩

theorem prime_4434155615661930479 : Nat.Prime 4434155615661930479 :=
  prime_of_lucas 17 [(2, 1), (41, 1), (43, 1), (1257559732178653, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, prime_1257559732178653, trivial⟩

theorem prime_172054593956031949258510691 : Nat.Prime 172054593956031949258510691 :=
  prime_of_lucas 2 [(2, 1), (5, 1), (1361, 1), (2851, 1), (4434155615661930479, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, by norm_num, prime_4434155615661930479, trivial⟩

theorem prime_19757330305831588566944191468367130476339 :
    Nat.Prime 19757330305831588566944191468367130476339 :=
  prime_of_lucas 2 [(2, 1), (269, 1), (213441916511, 1), (172054593956031949258510691, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, prime_213441916511, prime_172054593956031949258510691, trivial⟩

theorem prime_276602624281642239937218680557139826668747 :
    Nat.Prime 276602624281642239937218680557139826668747 :=
  prime_of_lucas 2 [(2, 1), (7, 1), (19757330305831588566944191468367130476339, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, prime_19757330305831588566944191468367130476339, trivial⟩

theorem prime_1923133 : Nat.Prime 1923133 :=
  prime_of_lucas 2 [(2, 2), (3, 1), (43, 1), (3727, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, by norm_num, trivial⟩

theorem prime_31757755568855353 : Nat.Prime 31757755568855353 :=
  prime_of_lucas 10 [(2, 3), (3, 1), (31, 1), (107, 1), (223, 1), (4153, 1), (430751, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, by norm_num, by norm_num, by norm_num, by norm_num, trivial⟩

theorem prime_2773320623 : Nat.Prime 2773320623 :=
  prime_of_lucas 5 [(2, 1), (2437, 1), (569003, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, trivial⟩

theorem prime_72106336199 : Nat.Prime 72106336199 :=
  prime_of_lucas 7 [(2, 1), (13, 1), (2773320623, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, prime_2773320623, trivial⟩

theorem prime_8574133 : Nat.Prime 8574133 :=
  prime_of_lucas 2 [(2, 2), (3, 1), (7, 1), (103, 1), (991, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, by norm_num, by norm_num, trivial⟩

theorem prime_1919519569386763 : Nat.Prime 1919519569386763 :=
  prime_of_lucas 2 [(2, 1), (3, 1), (7, 1), (19, 1), (47, 2), (127, 1), (8574133, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, by norm_num, by norm_num, by norm_num, prime_8574133, trivial⟩

theorem prime_75445702479781427272750846543864801 : Nat.Prime 75445702479781427272750846543864801 :=
  prime_of_lucas 7 [(2, 5), (3, 2), (5, 2), (75707, 1), (72106336199, 1), (1919519569386763, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, by norm_num, prime_72106336199, prime_1919519569386763, trivial⟩

theorem prime_74058212732561358302231226437062788676166966415465897661863160754340907 : Nat.Prime 74058212732561358302231226437062788676166966415465897661863160754340907 :=
  prime_of_lucas 2 [(2, 1), (3, 1), (353, 1), (57467, 1), (132049, 1), (1923133, 1), (31757755568855353, 1), (75445702479781427272750846543864801, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, by norm_num, by norm_num, prime_1923133, prime_31757755568855353, prime_75445702479781427272750846543864801, trivial⟩

end ed25519

open ed25519 in
/-- `PRIME_N25519`, here by a Pratt certificate rather than an axiom. -/
theorem n25519_prime : Nat.Prime n25519 :=
  prime_of_lucas 2 [(2, 2), (3, 1), (11, 1), (198211423230930754013084525763697, 1),
      (276602624281642239937218680557139826668747, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, prime_198211423230930754013084525763697,
      prime_276602624281642239937218680557139826668747, trivial⟩

open ed25519 in
/-- `PRIME_P25519`, here by a Pratt certificate rather than an axiom. -/
theorem p25519_prime : Nat.Prime p25519 :=
  prime_of_lucas 2 [(2, 2), (3, 1), (65147, 1), (74058212732561358302231226437062788676166966415465897661863160754340907, 1)] (by decide +kernel)
    ⟨by norm_num, by norm_num, by norm_num, prime_74058212732561358302231226437062788676166966415465897661863160754340907, trivial⟩

/-! ## The group -/

/-- `edwards_0`, which `EDWARDS25519_GROUP` shows is
`group_id edwards25519_group`. -/
def edId : EdPoint := (0, 1)

theorem edOnCurve_id : edOnCurve edId := by
  simp only [edOnCurve, edId, p25519]; norm_num

/-- `GENERATOR_IN_GROUP_CARRIER_EDWARDS25519`, here by computation. -/
theorem edOnCurve_B : edOnCurve edB := by
  simp only [edOnCurve, edB, p25519, e25519, d25519]; norm_num

/-- The negation of a point of the group is in the group. -/
theorem edOnCurve_neg (P : EdPoint) (h : edOnCurve P) : edOnCurve (edNeg P) := by
  obtain ⟨x, y⟩ := P
  obtain ⟨-, -, hy0, hy1, he⟩ := h
  have hq : (-x) % (p25519 : Int) ≡ -x [ZMOD p25519] := Int.mod_modEq _ _
  have hq2 : ((-x) % (p25519 : Int)) ^ 2 ≡ x ^ 2 [ZMOD p25519] := by
    simpa [neg_sq] using hq.pow 2
  refine ⟨Int.emod_nonneg _ (by decide), Int.emod_lt_of_pos _ (by decide), hy0, hy1, ?_⟩
  show e25519 * ((-x) % (p25519 : Int)) ^ 2 + y ^ 2 ≡
    1 + d25519 * ((-x) % (p25519 : Int)) ^ 2 * y ^ 2 [ZMOD p25519]
  calc _ ≡ e25519 * x ^ 2 + y ^ 2 [ZMOD p25519] := (hq2.mul_left _).add_right _
    _ ≡ 1 + d25519 * x ^ 2 * y ^ 2 [ZMOD p25519] := he
    _ ≡ _ [ZMOD p25519] := ((hq2.symm.mul_left _).mul_right _).add_left _

/-- `GROUP_MUL`: the group is closed under its multiplication, `edwards_add`
by `EDWARDS25519_GROUP`. -/
axiom edOnCurve_mul {P Q : EdPoint} : edOnCurve P → edOnCurve Q → edOnCurve (edMul P Q)

/-- `GROUP_MUL_ASSOC`. -/
axiom edMul_assoc {P Q R : EdPoint} : edOnCurve P → edOnCurve Q → edOnCurve R →
  edMul P (edMul Q R) = edMul (edMul P Q) R

/-- `ABELIAN_EDWARDS25519_GROUP`. -/
axiom edMul_comm {P Q : EdPoint} : edOnCurve P → edOnCurve Q → edMul P Q = edMul Q P

/-- `GROUP_MUL_LID`, with `EDWARDS25519_GROUP`'s identity `edwards_0`. -/
axiom edMul_id {P : EdPoint} : edOnCurve P → edMul edId P = P

/-- `GROUP_MUL_LINV`, with `EDWARDS25519_GROUP`'s inverse `edwards_neg`. -/
axiom edMul_neg {P : EdPoint} : edOnCurve P → edMul (edNeg P) P = edId

/-- `group_pow`'s definition, `group_pow G x 0 = group_id G`. -/
axiom edPow_zero (P : EdPoint) : edPow P 0 = edId

/-- `group_pow`'s definition,
`group_pow G x (SUC n) = group_mul G x (group_pow G x n)`. -/
axiom edPow_succ (P : EdPoint) (n : Nat) : edPow P (n + 1) = edMul P (edPow P n)

/-- `SIZE_EDWARDS25519_GROUP`: the group has `8L` points. -/
axiom edCard : Nat.card {P : EdPoint // edOnCurve P} = 8 * n25519

/-- `GROUP_ELEMENT_ORDER_EDWARDS25519_E25519`, with `GROUP_POW_ELEMENT_ORDER`:
the base point has order `L`. -/
axiom edPow_B_order : edPow edB n25519 = edId

/-- `ED25519_ENCODE_INJECTIVE`, s2n-bignum's, in
`x86/proofs/edwards25519_decode.ml` at its revision 3f01260f: two points of
the group with one encoding are the same point. -/
axiom edEncode_inj {P Q : EdPoint} : edOnCurve P → edOnCurve Q → edEncode P = edEncode Q → P = Q

/-- `edwards25519_group` as a Lean group. -/
abbrev EdG := {P : EdPoint // edOnCurve P}

noncomputable instance : CommGroup EdG where
  mul a b := ⟨edMul a.1 b.1, edOnCurve_mul a.2 b.2⟩
  mul_assoc a b c := Subtype.ext (edMul_assoc a.2 b.2 c.2).symm
  one := ⟨edId, edOnCurve_id⟩
  one_mul a := Subtype.ext (edMul_id a.2)
  mul_one a := Subtype.ext ((edMul_comm a.2 edOnCurve_id).trans (edMul_id a.2))
  inv a := ⟨edNeg a.1, edOnCurve_neg _ a.2⟩
  inv_mul_cancel a := Subtype.ext (edMul_neg a.2)
  mul_comm a b := Subtype.ext (edMul_comm a.2 b.2)

@[simp] theorem EdG.mul_val (a b : EdG) : (a * b).1 = edMul a.1 b.1 := rfl
@[simp] theorem EdG.one_val : (1 : EdG).1 = edId := rfl
@[simp] theorem EdG.inv_val (a : EdG) : a⁻¹.1 = edNeg a.1 := rfl

theorem EdG.pow_val (a : EdG) (n : Nat) : (a ^ n).1 = edPow a.1 n := by
  induction n with
  | zero => rw [pow_zero, edPow_zero]; rfl
  | succ n ih => rw [pow_succ', edPow_succ, EdG.mul_val, ih]

/-- The group's power stays in the group. -/
theorem edOnCurve_pow {P : EdPoint} (h : edOnCurve P) (n : Nat) : edOnCurve (edPow P n) := by
  rw [← EdG.pow_val ⟨P, h⟩ n]; exact (⟨P, h⟩ ^ n : EdG).2

theorem EdG.pow_exponent (a : EdG) : a ^ (8 * n25519) = 1 := by
  rw [← edCard]; exact pow_card_eq_one'

/-- Raising to a power prime to `8L` keeps every point but the identity off
the identity. -/
theorem EdG.pow_eq_one_iff (x : EdG) {v : Nat} (hv : Nat.Coprime v (8 * n25519)) :
    x ^ v = 1 ↔ x = 1 := by
  refine ⟨fun h => ?_, fun h => by rw [h, one_pow]⟩
  have h1 : orderOf x ∣ v := orderOf_dvd_of_pow_eq_one h
  have h2 : orderOf x ∣ 8 * n25519 := orderOf_dvd_of_pow_eq_one x.pow_exponent
  have : orderOf x = 1 := Nat.eq_one_of_dvd_one (hv ▸ Nat.dvd_gcd h1 h2)
  exact orderOf_eq_one_iff.mp this

theorem coprime_8n (v : Nat) (hv : v % 2 = 1) (h0 : 0 < v) (hvL : v < n25519) :
    Nat.Coprime v (8 * n25519) := by
  refine Nat.Coprime.mul_right ?_ ?_
  · rw [show (8 : Nat) = 2 ^ 3 from rfl]
    exact Nat.Coprime.pow_right _ ((Nat.coprime_comm.mp ((Nat.prime_two.coprime_iff_not_dvd).mpr (by omega))))
  · exact Nat.Coprime.symm ((n25519_prime.coprime_iff_not_dvd).mpr (fun hd => by
      have := Nat.le_of_dvd h0 hd; omega))

/-- `half_size_iff`'s `[|u|]` of `A` or of its negation, as a power of `A`
by `-u`. -/
theorem EdG.signed_pow (a : EdG) (neg : Bool) (m : Nat) :
    (if neg then a else a⁻¹) ^ m = a ^ (-(if neg then -(m : Int) else m)) := by
  cases neg <;> simp [zpow_neg, inv_pow]

/-- The half-size check's argument: for `u ≡ v k (mod 8L)`, `u` given by its
sign and magnitude, with `v` odd and below `L`, the multiple
`[v S mod L]B + [v](-R) + [|u|]A'`, with `A'` either `A`, for `u` negative, or
`-A`, is the identity exactly when `R = [S]B - [k]A`, whatever torsion `A`
and `R` carry. -/
theorem half_size_iff (A R : EdPoint) (hA : edOnCurve A) (hR : edOnCurve R) (S k v m : Nat)
    (neg : Bool) (hu : (if neg then -(m : Int) else m) ≡ v * k [ZMOD 8 * n25519])
    (hv : v % 2 = 1) (hvL : v < n25519) :
    edMul (edMul (edPow edB (v * S % n25519)) (edPow (edNeg R) v)) (edPow (if neg then A else edNeg A) m) = edId ↔
      R = edMul (edPow (edNeg A) k) (edPow edB S) := by
  set a : EdG := ⟨A, hA⟩
  set r : EdG := ⟨R, hR⟩
  set b : EdG := ⟨edB, edOnCurve_B⟩
  have hb : b ^ n25519 = 1 := Subtype.ext (by rw [EdG.pow_val]; exact edPow_B_order)
  have hA' : (if neg then A else edNeg A) = (if neg then a else a⁻¹).1 := by cases neg <;> rfl
  have hlhs : edMul (edMul (edPow edB (v * S % n25519)) (edPow (edNeg R) v))
      (edPow (if neg then A else edNeg A) m) =
      (b ^ (v * S % n25519) * r⁻¹ ^ v * (if neg then a else a⁻¹) ^ m).1 := by
    rw [hA', EdG.mul_val, EdG.mul_val, EdG.pow_val, EdG.pow_val, EdG.pow_val]; rfl
  have hrhs : edMul (edPow (edNeg A) k) (edPow edB S) = (a⁻¹ ^ k * b ^ S).1 := by
    rw [EdG.mul_val, EdG.pow_val, EdG.pow_val]; rfl
  -- [v S mod L]B = [v S]B, as B has order L.
  have hbS : b ^ (v * S % n25519) = b ^ (v * S) := by
    conv_rhs => rw [← Nat.mod_add_div (v * S) n25519, pow_add, pow_mul, hb, one_pow, mul_one]
  -- [-u]A = [-v k]A, as every point has order dividing 8L.
  have hau : (if neg then a else a⁻¹) ^ m = a ^ (-((v * k : Nat) : Int)) := by
    rw [EdG.signed_pow, zpow_eq_zpow_iff_modEq]
    have hd : (orderOf a : Int) ∣ 8 * n25519 := by
      exact_mod_cast orderOf_dvd_of_pow_eq_one a.pow_exponent
    exact (Int.ModEq.neg (hu.trans (by push_cast; rfl))).of_dvd hd
  have hx : b ^ (v * S % n25519) * r⁻¹ ^ v * (if neg then a else a⁻¹) ^ m =
      (b ^ S * (a⁻¹ ^ k) * r⁻¹) ^ v := by
    rw [hbS, hau, zpow_neg, zpow_natCast]
    simp only [mul_pow, inv_pow, ← pow_mul]
    rw [mul_comm S v, mul_comm k v, mul_right_comm]
  have hco := coprime_8n v hv (by omega) hvL
  rw [hlhs, hrhs, hx, ← EdG.one_val]
  constructor
  · intro h
    have h1 := (EdG.pow_eq_one_iff _ hco).mp (Subtype.ext h)
    have : r = a⁻¹ ^ k * b ^ S := by
      rw [mul_comm (a⁻¹ ^ k)]; exact (mul_inv_eq_one.mp h1).symm
    exact congrArg Subtype.val this
  · intro h
    have hr : r = a⁻¹ ^ k * b ^ S := Subtype.ext h
    rw [hr, mul_comm (a⁻¹ ^ k), mul_inv_cancel, one_pow]

end rind.spec
