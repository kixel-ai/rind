module
public import Aeneas
public import Mathlib.Data.Nat.Digits.Defs
open Aeneas Aeneas.Std
@[expose] public section

/-!
# What rind's X25519 and P-256 compute

The functional spec the proofs state rind's results against: how bytes and
limbs encode numbers, X25519 itself, and the P-256 group, each as HOL Light
defines it for s2n-bignum's theorems.
-/

namespace rind.spec

/-- The number that little-endian bytes encode. -/
def leNat (bytes : List U8) : Nat :=
  Nat.ofDigits 256 (bytes.map (·.val))

/-- The number that big-endian bytes encode. -/
def beNat (bytes : List U8) : Nat :=
  leNat bytes.reverse

/-- The number that little-endian 64-bit limbs encode: HOL Light's
`bignum_from_memory`. -/
def wordsNat (words : List U64) : Nat :=
  Nat.ofDigits (2 ^ 64) (words.map (·.val))

/-- RFC 7748's X25519 of a scalar and a u-coordinate, each read as a number,
including the scalar's clamping and the u-coordinate's top-bit mask: HOL
Light's `rfcx25519`, defined in `EC/x25519.ml` at
https://github.com/jrh13/hol-light/blob/217dd32e798d98926d3ab81ed3dfcdf435831e1f/EC/x25519.ml#L608
and proven there to be the u-coordinate of the scalar multiple on Curve25519.

It is opaque here: nothing is assumed of it beyond the routine contracts in
`Rind.<Arch>.S2nBignum`, which restate s2n-bignum's theorems about it. -/
opaque rfcx25519 : Nat → Nat → Nat

/-! ## P-256, from HOL Light's `EC/nistp256.ml` at
https://github.com/jrh13/hol-light/blob/217dd32e798d98926d3ab81ed3dfcdf435831e1f/EC/nistp256.ml -/

/-- `p_256`, the field's prime. -/
def p256 : Nat := 115792089210356248762697446949407573530086143415290314195533631308867097853951

/-- `n_256`, the group's order. -/
def n256 : Nat := 115792089210356248762697446949407573529996955224135760342422259061068512044369

/-- `b_256`, the curve's constant term; its `a` is -3. -/
def b256 : Nat := 0x5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b

/-- A point of `p256_group` as HOL Light writes one: `none` at infinity,
otherwise its affine coordinates, the field elements of
`integer_mod_ring p_256`, which are numbers below `p256`. -/
abbrev P256Point := Option (Nat × Nat)

/-- Whether a point is in `group_carrier p256_group`, which `P256_GROUP`
shows is `weierstrass_curve (integer_mod_ring p_256, ring_neg (integer_mod_ring
p_256) (&3), &b_256)`: infinity, or coordinates in the field that satisfy
y² = x³ - 3x + b, with `integer_mod_ring`'s arithmetic mod `p256`. -/
def p256OnCurve : P256Point → Prop
  | none => True
  | some (x, y) => x < p256 ∧ y < p256 ∧ y ^ 2 % p256 = (x ^ 3 + (p256 - 3) * x + b256) % p256

instance : DecidablePred p256OnCurve := fun P =>
  match P with
  | none => isTrue trivial
  | some (x, y) => inferInstanceAs (Decidable (x < p256 ∧ y < p256 ∧ _))

/-- `G_256`, the generator. -/
def p256G : P256Point :=
  some (0x6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296,
    0x4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5)

/-- `group_pow p256_group P n`, the point `P` multiplied by `n`.

It is opaque here: nothing is assumed of it beyond the routine contracts in
`Rind.Aarch64.S2nBignum`, which restate s2n-bignum's theorems about it. -/
opaque p256Pow : P256Point → Nat → P256Point

end rind.spec
