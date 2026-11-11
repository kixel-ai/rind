import Rind.Spec

/-!
# The NIST curves' groups, and P-384

HOL Light defines each NIST prime curve's group as `weierstrass_group
(integer_mod_ring p, ring_neg (integer_mod_ring p) (&3), &b)`: the points of
y² = x³ - 3x + b over the integers mod p. This transliterates that group law
once, over the prime `p` and constant `b`, as `Rind.Spec` does for P-256's
alone, and gives P-384's parameters from HOL Light's `EC/nistp384.ml` at
https://github.com/jrh13/hol-light/blob/217dd32e798d98926d3ab81ed3dfcdf435831e1f/EC/nistp384.ml
-/

namespace rind.spec

namespace nist

/-- A point as HOL Light writes one: `none` at infinity, otherwise its affine
coordinates, the field elements of `integer_mod_ring p`, which are numbers
below `p`. -/
abbrev Point := Option (Nat × Nat)

/-- Whether a point is in `weierstrass_curve (integer_mod_ring p, ring_neg
(integer_mod_ring p) (&3), &b)`, the group's carrier: infinity, or
coordinates in the field that satisfy y² = x³ - 3x + b, with
`integer_mod_ring`'s arithmetic mod `p`. -/
def OnCurve (p b : Nat) : Point → Prop
  | none => True
  | some (x, y) => x < p ∧ y < p ∧ y ^ 2 % p = (x ^ 3 + (p - 3) * x + b) % p

instance (p b : Nat) : DecidablePred (OnCurve p b) := fun P =>
  match P with
  | none => isTrue trivial
  | some (x, y) => inferInstanceAs (Decidable (x < p ∧ y < p ∧ _))

/-! The group law, transliterated from HOL Light's definitions. The field's
operations are `integer_mod_ring`'s on numbers below `p`,
https://github.com/jrh13/hol-light/blob/217dd32e798d98926d3ab81ed3dfcdf435831e1f/Library/ringtheory.ml#L16887 -/

/-- `ring_sub (integer_mod_ring p)`: `(a - b) rem p`, which is never
negative. -/
def sub (p a b : Nat) : Nat := (a + (p - b % p)) % p

/-- `ring_inv (integer_mod_ring p)`: the number below `p` that `a` times is 1
mod `p`, if `a` is a field element with one, and otherwise 0,
https://github.com/jrh13/hol-light/blob/217dd32e798d98926d3ab81ed3dfcdf435831e1f/Library/ringtheory.ml#L1970 -/
noncomputable def inv (p a : Nat) : Nat :=
  haveI := Classical.propDecidable
  if h : a < p ∧ ∃ x, x < p ∧ a * x % p = 1 then Classical.choose h.2 else 0

/-- `weierstrass_add` on the curve, with `ring_div` as the product with
`inv`, `ring_of_num` 2 and 3 as themselves, and `a` as `p - 3`. It never reads
`b`,
https://github.com/jrh13/hol-light/blob/217dd32e798d98926d3ab81ed3dfcdf435831e1f/EC/weierstrass.ml#L33 -/
noncomputable def add (p : Nat) : Point → Point → Point
  | none, q => q
  | P, none => P
  | some (x1, y1), some (x2, y2) =>
    if x1 = x2 then
      if y1 = y2 ∧ y1 ≠ 0 then
        let m := (3 * (x1 ^ 2 % p) % p + (p - 3)) % p * inv p (2 * y1 % p) % p
        let x3 := sub p (m ^ 2 % p) (2 * x1 % p)
        let y3 := sub p (m * sub p x1 x3 % p) y1
        some (x3, y3)
      else none
    else
      let m := sub p y2 y1 * inv p (sub p x2 x1) % p
      let x3 := sub p (m ^ 2 % p) ((x1 + x2) % p)
      let y3 := sub p (m * sub p x1 x3 % p) y1
      some (x3, y3)

/-- `group_pow` on the group, the point `P` multiplied by `n`: `group_pow`'s
definition, `P` times the multiple below,
https://github.com/jrh13/hol-light/blob/217dd32e798d98926d3ab81ed3dfcdf435831e1f/Library/grouptheory.ml#L376 -/
noncomputable def pow (p : Nat) (P : Point) : Nat → Point
  | 0 => none
  | n + 1 => add p P (pow p P n)

/-- `weierstrass_neg` on the curve, which `WEIERSTRASS_GROUP` shows is
`group_inv`: y negated mod p. -/
def neg (p : Nat) : Point → Point
  | none => none
  | some (x, y) => some (x, (p - y % p) % p)

/-- FIPS 186-5 section 6.4.1's ECDSA signature `(r, s)` on the curve over
`p` whose generator `G` has order `n`, under private key `d`, with
per-message secret `k`, of the hash's integer `e`: r is the x-coordinate of
kG mod n, and s is (e + rd)/k mod n. A rind signature is this for the first
`k` whose `r` and `s` are both nonzero. -/
noncomputable def ecdsaSign (p n : Nat) (G : Point) (d k e : Nat) : Option (Nat × Nat) :=
  match pow p G k with
  | some (x, _) => some (x % n, (((e + x % n * d : Nat) : ZMod n) * (k : ZMod n)⁻¹).val)
  | none => none

/-- FIPS 186-5 section 6.4.2's ECDSA verification of `(r, s)` over the hash's
integer `e` under the public key `Q`, on the curve over `p` whose generator
`G` has order `n`: r and s are in [1, n), and u₁G + u₂Q, for u₁ = e/s and
u₂ = r/s mod n, is a finite point whose x-coordinate mod n is r. -/
def ecdsaVerifies (p n : Nat) (G Q : Point) (e r s : Nat) : Prop :=
  0 < r ∧ r < n ∧ 0 < s ∧ s < n ∧
    match add p (pow p G (((e : ZMod n) * (s : ZMod n)⁻¹).val))
        (pow p Q (((r : ZMod n) * (s : ZMod n)⁻¹).val)) with
    | some (x, _) => x % n = r
    | none => False

end nist

/-! ## P-384 -/

/-- `p_384`, the field's prime. -/
def p384 : Nat :=
  39402006196394479212279040100143613805079739270465446667948293404245721771496870329047266088258938001861606973112319

/-- `n_384`, the group's order. -/
def n384 : Nat :=
  39402006196394479212279040100143613805079739270465446667946905279627659399113263569398956308152294913554433653942643

/-- `b_384`, the curve's constant term; its `a` is -3. -/
def b384 : Nat :=
  0xb3312fa7e23ee7e4988e056be3f82d19181d9c6efe8141120314088f5013875ac656398d8a2ed19d2a85c8edd3ec2aef

/-- `G_384`, the generator. -/
def p384G : nist.Point :=
  some (0xaa87ca22be8b05378eb1c71ef320ad746e1d3b628ba79b9859f741e082542a385502f25dbf55296c3a545e3872760ab7,
    0x3617de4a96262c6f5d9e98bf9292dc29f8f41dbd289a147ce9da3113b5f0b8c00a60b1ce1d7e819d7a431d7c90ea0e5f)

/-- Whether a point is in `group_carrier p384_group`, by `P384_GROUP`. -/
abbrev p384OnCurve : nist.Point → Prop := nist.OnCurve p384 b384

/-- `group_mul p384_group`, by `P384_GROUP`. -/
noncomputable abbrev p384Add : nist.Point → nist.Point → nist.Point := nist.add p384

/-- `group_pow p384_group`. -/
noncomputable abbrev p384Pow : nist.Point → Nat → nist.Point := nist.pow p384

/-- `group_inv p384_group`, by `P384_GROUP`. -/
abbrev p384Neg : nist.Point → nist.Point := nist.neg p384

end rind.spec
