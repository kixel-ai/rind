import Rind.Ed25519Points
open rind.edwards

/-!
# The radix 2^25.5 limbs of dalek's AVX2 field elements

dalek's AVX2 backend holds four field elements, lanes A, B, C, and D, in five
vectors of eight 32-bit lanes: vector `j` holds limbs `2j` and `2j + 1` of each,
as `(a₂ⱼ, b₂ⱼ, a₂ⱼ₊₁, b₂ⱼ₊₁, c₂ⱼ, d₂ⱼ, c₂ⱼ₊₁, d₂ⱼ₊₁)`. Limb `i` is
alternately 26 and 25 bits wide, at bit offset `limbOffset i`.
-/

namespace rind.spec

/-- Limb `i`'s bit offset in a field element: 0, 26, 51, 77, and so on. -/
def limbOffset (i : Nat) : Nat := 51 * (i / 2) + 26 * (i % 2)

/-- Limb `i`'s width: 26 bits for an even `i`, 25 for an odd one. -/
def limbWidth (i : Nat) : Nat := 26 - i % 2

/-- The 32-bit lane of its vector that holds limb `i` of field element `k`. -/
def limbLane (k i : Nat) : Nat := [0, 1, 4, 5][k]! + 2 * (i % 2)

/-- The value of ten limbs. -/
def limbsValue (l : Nat → Nat) : Nat := ∑ i ∈ Finset.range 10, l i * 2 ^ limbOffset i

/-- The limbs of field element `k`, given each vector's lanes. -/
def limbsOf (lanes : Nat → Nat → Nat) (k : Nat) : Nat → Nat := fun i => lanes (i / 2) (limbLane k i)

theorem edOnCurve_edB : edOnCurve edB := by
  unfold edOnCurve
  decide +kernel

/-- edwards25519's base point `B`, as a point of the group. -/
def basePoint : Point dF := toPoint edB edOnCurve_edB

theorem ofPoint_basePoint : ofPoint basePoint = edB := ofPoint_toPoint _ _

end rind.spec
