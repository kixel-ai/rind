module
public import Aeneas
public import Mathlib.Data.Nat.Digits.Defs
open Aeneas Aeneas.Std
@[expose] public section

/-!
# What rind computes

The functional spec the proofs state rind's results against: how bytes and
limbs encode numbers, X25519 itself, and the P-256 group, each as HOL Light
defines it for s2n-bignum's theorems, and ChaCha20's block function and QUIC
header protection, transliterated from their RFCs.
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
y² = x³ - 3x + b, with `integer_mod_ring`'s arithmetic mod `p256`,
https://github.com/jrh13/hol-light/blob/217dd32e798d98926d3ab81ed3dfcdf435831e1f/EC/nistp256.ml#L82

The proofs must decide this membership, so the composition rule lets it be
this defining equation rather than an opaque set. -/
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

/-! The group law, transliterated from HOL Light's definitions: `group_mul
p256_group` is `weierstrass_add (integer_mod_ring p_256, ring_neg
(integer_mod_ring p_256) (&3), &b_256)` by `P256_GROUP`, above. The field's
operations are `integer_mod_ring`'s on numbers below `p256`,
https://github.com/jrh13/hol-light/blob/217dd32e798d98926d3ab81ed3dfcdf435831e1f/Library/ringtheory.ml#L16887 -/

/-- `ring_sub (integer_mod_ring p_256)`: `(a - b) rem p_256`, which is never
negative. -/
def p256Sub (a b : Nat) : Nat := (a + (p256 - b % p256)) % p256

/-- `ring_inv (integer_mod_ring p_256)`: the number below `p256` that `a` times
is 1 mod `p256`, if `a` is a field element with one, and otherwise 0,
https://github.com/jrh13/hol-light/blob/217dd32e798d98926d3ab81ed3dfcdf435831e1f/Library/ringtheory.ml#L1970 -/
noncomputable def p256Inv (a : Nat) : Nat :=
  haveI := Classical.propDecidable
  if h : a < p256 ∧ ∃ x, x < p256 ∧ a * x % p256 = 1 then Classical.choose h.2 else 0

/-- `weierstrass_add` on `p256_group`'s curve, with `ring_div` as the product
with `p256Inv`, `ring_of_num` 2 and 3 as themselves, and `a` as `p256 - 3`,
https://github.com/jrh13/hol-light/blob/217dd32e798d98926d3ab81ed3dfcdf435831e1f/EC/weierstrass.ml#L33 -/
noncomputable def p256Add : P256Point → P256Point → P256Point
  | none, q => q
  | p, none => p
  | some (x1, y1), some (x2, y2) =>
    if x1 = x2 then
      if y1 = y2 ∧ y1 ≠ 0 then
        let m := (3 * (x1 ^ 2 % p256) % p256 + (p256 - 3)) % p256 * p256Inv (2 * y1 % p256) % p256
        let x3 := p256Sub (m ^ 2 % p256) (2 * x1 % p256)
        let y3 := p256Sub (m * p256Sub x1 x3 % p256) y1
        some (x3, y3)
      else none
    else
      let m := p256Sub y2 y1 * p256Inv (p256Sub x2 x1) % p256
      let x3 := p256Sub (m ^ 2 % p256) ((x1 + x2) % p256)
      let y3 := p256Sub (m * p256Sub x1 x3 % p256) y1
      some (x3, y3)

/-- `group_pow p256_group P n`, the point `P` multiplied by `n`: `group_pow`'s
definition, `P` times the multiple below,
https://github.com/jrh13/hol-light/blob/217dd32e798d98926d3ab81ed3dfcdf435831e1f/Library/grouptheory.ml#L376 -/
noncomputable def p256Pow (P : P256Point) : Nat → P256Point
  | 0 => none
  | n + 1 => p256Add P (p256Pow P n)

/-! ## ChaCha20 and QUIC header protection -/

namespace chacha20

/-- A 32-bit word of ChaCha20's state. -/
abbrev Word := BitVec 32

/-- RFC 8439 section 2.1's quarter round on four words. -/
def qr (a b c d : Word) : Word × Word × Word × Word :=
  let a := a + b
  let d := (d ^^^ a).rotateLeft 16
  let c := c + d
  let b := (b ^^^ c).rotateLeft 12
  let a := a + b
  let d := (d ^^^ a).rotateLeft 8
  let c := c + d
  let b := (b ^^^ c).rotateLeft 7
  (a, b, c, d)

/-- RFC 8439 section 2.2's quarter round on state words `x`, `y`, `z`, and `w`. -/
def quarterRound (s : List Word) (x y z w : Nat) : List Word :=
  let (a, b, c, d) := qr s[x]! s[y]! s[z]! s[w]!
  (((s.set x a).set y b).set z c).set w d

/-- RFC 8439 section 2.3.1's `inner_block`: the column rounds, then the
diagonal rounds. -/
def innerBlock (s : List Word) : List Word :=
  let s := quarterRound s 0 4 8 12
  let s := quarterRound s 1 5 9 13
  let s := quarterRound s 2 6 10 14
  let s := quarterRound s 3 7 11 15
  let s := quarterRound s 0 5 10 15
  let s := quarterRound s 1 6 11 12
  let s := quarterRound s 2 7 8 13
  quarterRound s 3 4 9 14

/-- The word whose little-endian bytes these are. -/
def le32 (b0 b1 b2 b3 : BitVec 8) : Word := BitVec.fromLEBytes [b0, b1, b2, b3]

/-- `bytes` as little-endian words, four bytes each. -/
def words (bytes : List (BitVec 8)) : List Word :=
  (List.range (bytes.length / 4)).map fun i =>
    le32 bytes[4 * i]! bytes[4 * i + 1]! bytes[4 * i + 2]! bytes[4 * i + 3]!

/-- RFC 8439 section 2.3's ChaCha20 block function: the 64-byte keystream
block for a 32-byte key, a block counter, and a 12-byte nonce. -/
def block (key : List (BitVec 8)) (counter : Word) (nonce : List (BitVec 8)) : List (BitVec 8) :=
  let state := [0x61707865, 0x3320646e, 0x79622d32, 0x6b206574] ++ words key ++ [counter] ++
    words nonce
  let working := innerBlock^[10] state
  (List.zipWith (· + ·) working state).flatMap BitVec.toLEBytes

/-- RFC 9001 section 5.4.4's ChaCha20 header-protection mask: ChaCha20 under
the header-protection key of five zero bytes, so the keystream's first five,
with the sample's first four bytes as the little-endian block counter and the
rest as the nonce. -/
def headerProtectionMask (key sample : List (BitVec 8)) : List (BitVec 8) :=
  (block key (le32 sample[0]! sample[1]! sample[2]! sample[3]!) (sample.drop 4)).take 5

end chacha20

end rind.spec
