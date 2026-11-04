module
public import Aeneas
public import Mathlib.Data.Nat.Digits.Defs
open Aeneas Aeneas.Std
@[expose] public section

/-!
# What rind's X25519 computes

The functional spec the proofs state rind's results against: how bytes and
limbs encode numbers, and X25519 itself, which is s2n-bignum's.
-/

namespace rind.spec

/-- The number that little-endian bytes encode. -/
def leNat (bytes : List U8) : Nat :=
  Nat.ofDigits 256 (bytes.map (·.val))

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

end rind.spec
