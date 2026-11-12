module
public import Aeneas
@[expose] public section

/-!
# A 128-bit vector's lanes

Both targets' vector registers as `BitVec 128`, lane 0 lowest, which
`Rind.X86_64.Simd` and `Rind.Aarch64.Neon` model the intrinsics over.
-/

namespace rind.simd

/-- 64-bit lane `i`. -/
def lane64 (x : BitVec 128) (i : Nat) : BitVec 64 := x.extractLsb' (64 * i) 64

/-- 32-bit lane `i`. -/
def lane32 (x : BitVec 128) (i : Nat) : BitVec 32 := x.extractLsb' (32 * i) 32

/-- The vector of four 32-bit lanes, lane 0 lowest. -/
def ofLanes32 (f : Nat → BitVec 32) : BitVec 128 := f 3 ++ f 2 ++ f 1 ++ f 0

end rind.simd
