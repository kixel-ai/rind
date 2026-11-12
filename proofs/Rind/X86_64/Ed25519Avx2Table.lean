import Rind.X86_64.Funs
import Rind.Ed25519Limbs
open Aeneas Aeneas.Std rind.spec rind.edwards

/-!
# The AVX2 double multiplication's table of the base point's odd multiples

`base_odd_multiples_spec` proves that entry `j` of `BASE_ODD_MULTIPLES`, as
Aeneas translates it, holds cached coordinates of `(2j + 1)B`, in limbs each
within its width. The kernel checks every entry: its limbs, that its last lane
is the `2dxy` multiple its first three make, and that the affine point its
first three name is the one before it plus `2B`, by the addition law with
inverses as powers.
-/

namespace rind.x86_64

/-- The 32-bit lanes of entry `j`'s vectors. -/
def entryLanes (j : Nat) : Nat → Nat → Nat := fun v ln =>
  (((low.x86_64.edwards25519_scalarmuldouble_avx2.BASE_ODD_MULTIPLES.val[j]!).val[v]!).val[ln]!).val

/-- The value of field element `k` of entry `j`. -/
def entryValue (j k : Nat) : Nat := limbsValue (limbsOf (entryLanes j) k)

/-- The inverse of `c` mod p, by Fermat's little theorem. -/
def invP (c : Nat) : Nat := powMod p25519 256 c (p25519 - 2)

/-- The affine point whose cached coordinates `(a, b, c, _)` are:
`((b - a) / c, (b + a) / c)`. -/
def cachedPoint (a b c : Nat) : Nat × Nat :=
  ((b + p25519 - a % p25519) * invP c % p25519, (b + a) * invP c % p25519)

/-- The twisted Edwards addition law, mod p. -/
def addNat (P Q : Nat × Nat) : Nat × Nat :=
  let t := d25519 * P.1 * Q.1 * P.2 * Q.2 % p25519
  ((P.1 * Q.2 + P.2 * Q.1) * invP (1 + t) % p25519,
    (P.2 * Q.2 + P.1 * Q.1) * invP (1 + p25519 - t) % p25519)

/-- `B`'s coordinates. -/
def edBNat : Nat × Nat := (edB.1.toNat, edB.2.toNat)

/-- Entry `j`'s affine point. -/
def entryPoint (j : Nat) : Nat × Nat := cachedPoint (entryValue j 0) (entryValue j 1) (entryValue j 2)

/-- Entry `j`'s limbs are within their widths, its third lane is nonzero, and
its last is `d (b - a)(b + a) / c`. -/
def entryOk (j : Nat) : Bool :=
  ((List.range 4).all fun k => (List.range 10).all fun i =>
    decide (limbsOf (entryLanes j) k i < 2 ^ limbWidth i)) &&
  entryValue j 2 % p25519 != 0 &&
  entryValue j 3 * entryValue j 2 % p25519 ==
    d25519 * ((entryValue j 1 + p25519 - entryValue j 0 % p25519) * (entryValue j 1 + entryValue j 0)) %
      p25519

/-- Every entry is well formed, the first names `B`, and each other names the
one before it plus `2B`. -/
def tableOk : Bool :=
  (List.range 64).all entryOk && entryPoint 0 == edBNat &&
    (List.range 63).all fun j => entryPoint (j + 1) == addNat (entryPoint j) (addNat edBNat edBNat)

theorem tableOk_true : tableOk = true := by decide +kernel

/-! ## From the check to the group -/

theorem cast_mod (n : Nat) : ((n % p25519 : Nat) : Fp) = (n : Fp) := ZMod.natCast_mod n p25519

theorem fp_pow_inv (x : Fp) : x ^ (p25519 - 2) = x⁻¹ := by
  by_cases hx : x = 0
  · rw [hx, zero_pow (by unfold p25519; norm_num), inv_zero]
  · apply eq_inv_of_mul_eq_one_left
    rw [← pow_succ, show p25519 - 2 + 1 = p25519 - 1 by unfold p25519; norm_num]
    exact ZMod.pow_card_sub_one_eq_one hx

theorem cast_invP (c : Nat) : ((invP c : Nat) : Fp) = (c : Fp)⁻¹ := by
  rw [invP, powMod_eq _ _ _ _ (by unfold p25519; norm_num), cast_mod, Nat.cast_pow, fp_pow_inv]

/-- Casts of the cached point's coordinates. -/
theorem cast_cachedPoint (a b c : Nat) :
    (((cachedPoint a b c).1 : Nat) : Fp) = ((b : Fp) - a) * (c : Fp)⁻¹ ∧
      (((cachedPoint a b c).2 : Nat) : Fp) = ((b : Fp) + a) * (c : Fp)⁻¹ := by
  have hsub : ((b + p25519 - a % p25519 : Nat) : Fp) = (b : Fp) - a := by
    rw [Nat.cast_sub (by have := Nat.mod_lt a (show p25519 > 0 by unfold p25519; norm_num); omega),
      Nat.cast_add, cast_mod, ZMod.natCast_self, add_zero]
  constructor
  · simp only [cachedPoint, cast_mod, Nat.cast_mul, cast_invP, hsub]
  · simp only [cachedPoint, cast_mod, Nat.cast_mul, Nat.cast_add, cast_invP]

theorem cast_addNat (P Q : Nat × Nat) :
    ((((addNat P Q).1 : Nat) : Fp), (((addNat P Q).2 : Nat) : Fp)) =
      add dF ((P.1 : Fp), (P.2 : Fp)) ((Q.1 : Fp), (Q.2 : Fp)) := by
  have ht : ((d25519 * P.1 * Q.1 * P.2 * Q.2 % p25519 : Nat) : Fp) =
      dF * (P.1 : Fp) * Q.1 * P.2 * Q.2 := by
    rw [cast_mod]; push_cast; rfl
  have hle : d25519 * P.1 * Q.1 * P.2 * Q.2 % p25519 ≤ 1 + p25519 :=
    by have := Nat.mod_lt (d25519 * P.1 * Q.1 * P.2 * Q.2) (show p25519 > 0 by unfold p25519; norm_num); omega
  simp only [addNat, add, cast_mod, Nat.cast_mul, Nat.cast_add, cast_invP, div_eq_mul_inv]
  rw [Nat.cast_sub hle]
  simp only [Nat.cast_add, Nat.cast_one, ZMod.natCast_self, ht, add_zero]

/-- The affine point a check's pair names. -/
def castPair (P : Nat × Nat) : Fp × Fp := ((P.1 : Fp), (P.2 : Fp))

theorem castPair_edB : castPair edBNat = basePoint.1 := by
  simp only [castPair, edBNat, basePoint, toPoint]
  constructor

theorem multiples (hok : tableOk = true) :
    ∀ j < 64, ((2 * j + 1) • basePoint).1 = castPair (entryPoint j) := by
  simp only [tableOk, Bool.and_eq_true, List.all_eq_true, List.mem_range, beq_iff_eq] at hok
  obtain ⟨⟨-, h0⟩, hstep⟩ := hok
  have h2 : (2 • basePoint).1 = castPair (addNat edBNat edBNat) := by
    rw [two_nsmul, Point.val_add, castPair, cast_addNat]
    rw [← castPair_edB]
    rfl
  intro j hj
  induction j with
  | zero => rw [mul_zero, zero_add, one_nsmul, h0, castPair_edB]
  | succ j ih =>
    rw [show 2 * (j + 1) + 1 = (2 * j + 1) + 2 by ring, add_nsmul, Point.val_add, ih (by omega), h2,
      hstep j (by omega)]
    simp only [castPair]
    rw [← cast_addNat]

/-- Entry `j` holds cached coordinates of `(2j + 1)B`, in limbs within their
widths. -/
theorem base_odd_multiples_spec (j : Nat) (hj : j < 64) :
    (∀ k < 4, ∀ i < 10, limbsOf (entryLanes j) k i < 2 ^ limbWidth i) ∧
      IsCached ((2 * j + 1) • basePoint) (entryValue j 0) (entryValue j 1) (entryValue j 2)
        (entryValue j 3) := by
  have hok := tableOk_true
  have hpt := multiples hok j hj
  simp only [tableOk, Bool.and_eq_true, List.all_eq_true, List.mem_range] at hok
  have he := hok.1.1 j hj
  simp only [entryOk, Bool.and_eq_true, List.all_eq_true, List.mem_range, decide_eq_true_eq,
    bne_iff_ne, ne_eq, beq_iff_eq] at he
  obtain ⟨⟨hb, hc⟩, hd⟩ := he
  refine ⟨hb, ?_⟩
  set a := entryValue j 0
  set b := entryValue j 1
  set c := entryValue j 2
  set e := entryValue j 3
  have hc0 : (c : Fp) ≠ 0 := by
    rwa [Ne, ZMod.natCast_eq_zero_iff, Nat.dvd_iff_mod_eq_zero]
  obtain ⟨hx, hy⟩ := cast_cachedPoint a b c
  have hP : ((2 * j + 1) • basePoint).1 = (((b : Fp) - a) * (c : Fp)⁻¹, ((b : Fp) + a) * (c : Fp)⁻¹) := by
    rw [hpt, castPair, entryPoint, hx, hy]
  have hdF : (e : Fp) * c = dF * (((b : Fp) - a) * (b + a)) := by
    have := congrArg (fun n : Nat => (n : Fp)) hd
    simp only [cast_mod, Nat.cast_mul, Nat.cast_add] at this
    rw [Nat.cast_sub (by have := Nat.mod_lt a (show p25519 > 0 by unfold p25519; norm_num); omega),
      Nat.cast_add, cast_mod, ZMod.natCast_self, add_zero] at this
    exact this
  have h2 : (2 : Fp) ≠ 0 := fp_two_ne_zero
  refine ⟨(c : Fp) / 2, div_ne_zero hc0 fp_two_ne_zero, ?_, ?_, ?_, ?_⟩ <;> try simp only [hP]
  · field_simp
    ring
  · field_simp
    ring
  · field_simp
  · rw [show (e : Fp) = dF * (((b : Fp) - a) * (b + a)) / c by rw [eq_div_iff hc0, hdF]]
    field_simp

end rind.x86_64
