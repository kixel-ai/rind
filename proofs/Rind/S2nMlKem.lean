import Rind.MlKem

/-!
# s2n-bignum's ML-KEM specs

The functions s2n-bignum's ML-KEM postconditions name, from
`common/mlkem_mldsa.ml` and `arm/proofs/mlkem_basemul_k3.ml` at b4f17ee7, which
`thirdparty/s2n-bignum` holds, transliterated: HOL Light's `num->int` is
`ℕ → ℤ`, `isum (0..127)` is `∑ j ∈ range 128`, `&a pow n` is `(a : ℤ) ^ n`, and
`x rem &3329` is `x % 3329`, both the remainder in `[0, 3329)`. `bitreverse7`
reverses the seven bits of `word n : 7 word`, as `BitVec.reverse` does.

Each postcondition holds modulo 3329, so the bridges state each in `Zq`,
against FIPS 203's `NTT`, `NTTInv`, and `MultiplyNTTs`. `poly f` reads
s2n-bignum's coefficient function as a FIPS 203 polynomial. The aarch64
routines keep FIPS 203's coefficient order; the x86_64 AVX2 NTTs keep
coefficient `avx2Layout p` at position `p`. The inverse NTTs and the base
multiplication also scale by `2 ^ 16` and `2 ^ -16`, Montgomery's factor.
-/

open Spec.MLKEM Finset rind.spec.mlkem

namespace rind.spec.s2n

/-! ## Transliteration -/

/-- `bitreverse7`. -/
def bitreverse7 (n : ℕ) : ℕ := (BitVec.ofNat 7 n).reverse.toNat

/-- `bitreverse_pairs`. -/
def bitreversePairs (i : ℕ) : ℕ := 2 * bitreverse7 (i / 2) + i % 2

/-- `avx2_ntt_order`. -/
def avx2NttOrder (i : ℕ) : ℕ := bitreverse7 (64 * (i / 64) + (i % 64) / 16 + 4 * (i % 16))

/-- `avx2_ntt_order'`. -/
def avx2NttOrder' (i : ℕ) : ℕ :=
  let j := bitreverse7 i
  64 * (j / 64) + 16 * (j % 4) + (j % 64) / 4

/-- `avx2_reorder`. -/
def avx2Reorder (i : ℕ) : ℕ :=
  let r := (i / 16) % 2
  let q := 16 * (i / 32) + i % 16
  2 * avx2NttOrder q + r

/-- `tomont_3329`. -/
def tomont3329 (a : ℕ → ℤ) : ℕ → ℤ := fun i => (2 ^ 16 * a i) % 3329

/-- `mulcache`. -/
def mulcache (f : ℕ → ℤ) (k : ℕ) : ℤ := (f (2 * k + 1) * 17 ^ (2 * bitreverse7 k + 1)) % 3329

/-- `inverse_ntt`. -/
def inverseNtt (f : ℕ → ℤ) (k : ℕ) : ℤ :=
  (512 * ∑ j ∈ range 128, f (2 * bitreverse7 j + k % 2) * 1175 ^ ((2 * j + 1) * (k / 2))) % 3329

/-- `forward_ntt`. -/
def forwardNtt (f : ℕ → ℤ) (k : ℕ) : ℤ :=
  (∑ j ∈ range 128, f (2 * j + k % 2) * 17 ^ ((2 * bitreverse7 (k / 2) + 1) * j)) % 3329

/-- `avx2_forward_ntt`. -/
def avx2ForwardNtt (f : ℕ → ℤ) (k : ℕ) : ℤ :=
  let r := (k / 16) % 2
  let q := 16 * (k / 32) + k % 16
  (∑ j ∈ range 128, f (2 * j + r) * 17 ^ ((2 * avx2NttOrder q + 1) * j)) % 3329

/-- `avx2_inverse_ntt`. -/
def avx2InverseNtt (f : ℕ → ℤ) (k : ℕ) : ℤ :=
  (512 * ∑ j ∈ range 128,
      f (avx2NttOrder' j / 16 * 32 + k % 2 * 16 + avx2NttOrder' j % 16) *
        1175 ^ ((2 * j + 1) * (k / 2))) % 3329

/-- `pmull`. -/
def pmull (x0 x1 y0 y1 : ℤ) : ℤ := x1 * y1 + x0 * y0

/-- `pmull_acc3`. -/
def pmullAcc3 (x00 x01 y00 y01 x10 x11 y10 y11 x20 x21 y20 y21 : ℤ) : ℤ :=
  pmull x20 x21 y20 y21 + pmull x10 x11 y10 y11 + pmull x00 x01 y00 y01

/-- `inverse_mod 3329 65536`: the inverse of `2 ^ 16` modulo 3329 in `[0, 3329)`,
which `inverseMod_spec` pins. -/
def inverseMod : ℕ := 169

theorem inverseMod_spec : inverseMod < 3329 ∧ 65536 * inverseMod % 3329 = 1 := by decide

/-- `pmul_acc3`. -/
def pmulAcc3 (x00 x01 y00 y01 x10 x11 y10 y11 x20 x21 y20 y21 : ℤ) : ℤ :=
  ((inverseMod : ℤ) * pmullAcc3 x00 x01 y00 y01 x10 x11 y10 y11 x20 x21 y20 y21) % 3329

/-- `basemul3_even`. -/
def basemul3Even (x0 y0 y0t x1 y1 y1t x2 y2 y2t : ℕ → ℤ) (i : ℕ) : ℤ :=
  pmulAcc3 (x0 (2 * i)) (x0 (2 * i + 1)) (y0 (2 * i)) (y0t i)
    (x1 (2 * i)) (x1 (2 * i + 1)) (y1 (2 * i)) (y1t i)
    (x2 (2 * i)) (x2 (2 * i + 1)) (y2 (2 * i)) (y2t i)

/-- `basemul3_odd`. -/
def basemul3Odd (x0 y0 x1 y1 x2 y2 : ℕ → ℤ) (i : ℕ) : ℤ :=
  pmulAcc3 (x0 (2 * i)) (x0 (2 * i + 1)) (y0 (2 * i + 1)) (y0 (2 * i))
    (x1 (2 * i)) (x1 (2 * i + 1)) (y1 (2 * i + 1)) (y1 (2 * i))
    (x2 (2 * i)) (x2 (2 * i + 1)) (y2 (2 * i + 1)) (y2 (2 * i))

/-! ## Bridges -/

/-- s2n-bignum's coefficients `f 0, …, f 255` as a FIPS 203 polynomial. -/
def poly (f : ℕ → ℤ) : Polynomial := Vector.ofFn fun i => (f i.val : Zq)

/-- The FIPS 203 coefficient the AVX2 NTTs keep at position `p`. -/
def avx2Layout (p : ℕ) : ℕ := bitreversePairs (avx2Reorder p)

theorem poly_get (f : ℕ → ℤ) (i : ℕ) (hi : i < 256) : (poly f)[i]! = (f i : Zq) := by
  rw [getElem!_pos (poly f) i hi]
  simp [poly]

theorem cast_rem (x : ℤ) : ((x % 3329 : ℤ) : Zq) = (x : Zq) := ZMod.intCast_mod x 3329

theorem bitreverse7_eq : ∀ n < 128, bitreverse7 n = bitRev 7 n := by decide +kernel

theorem ζ_eq : (17 : Zq) = ζ := rfl

/-- `forward_ntt`, which the aarch64 `mlkem_ntt` computes, is FIPS 203's `NTT`. -/
theorem forwardNtt_eq (f : ℕ → ℤ) (k : ℕ) (hk : k < 256) :
    (forwardNtt f k : Zq) = (NTT (poly f))[k]! := by
  have hi : k / 2 < 128 := by omega
  have hb : k % 2 < 2 := Nat.mod_lt _ (by norm_num)
  rw [forwardNtt, cast_rem, ← Nat.div_add_mod k 2, NTT_get _ _ _ hi hb,
    bitreverse7_eq _ (by omega)]
  push_cast
  refine sum_congr rfl fun j hj => ?_
  rw [poly_get f _ (by have := mem_range.1 hj; omega), ζ_eq,
    show (2 * (k / 2) + k % 2) / 2 = k / 2 by omega, show (2 * (k / 2) + k % 2) % 2 = k % 2 by omega]

/-- The sum the inverse NTTs scale: FIPS 203's `NTTInv` in Montgomery form, with
its terms in s2n-bignum's order. -/
theorem inverse_sum (g : Polynomial) (k : ℕ) (hk : k < 256) :
    (512 : Zq) * ∑ j ∈ range 128, g[2 * bitRev 7 j + k % 2]! * 1175 ^ ((2 * j + 1) * (k / 2)) =
      2 ^ 16 * (NTTInv g)[k]! := by
  have hj : k / 2 < 128 := by omega
  have hb : k % 2 < 2 := Nat.mod_lt _ (by norm_num)
  rw [← Nat.div_add_mod k 2, NTTInv_get g _ _ hj hb, ← mul_assoc,
    show (2 : Zq) ^ 16 * 3303 = 512 by decide,
    show (2 * (k / 2) + k % 2) / 2 = k / 2 by omega, show (2 * (k / 2) + k % 2) % 2 = k % 2 by omega]
  refine congrArg (512 * ·) ?_
  refine sum_nbij' (bitRev 7) (bitRev 7) (fun j hj => ?_) (fun j hj => ?_) (fun j hj => ?_)
    (fun j hj => ?_) (fun j hj => ?_)
  · exact mem_range.2 (bitRev_lt j (mem_range.1 hj))
  · exact mem_range.2 (bitRev_lt j (mem_range.1 hj))
  · exact bitRev_bitRev j (mem_range.1 hj)
  · exact bitRev_bitRev j (mem_range.1 hj)
  · rw [bitRev_bitRev j (mem_range.1 hj)]

/-- `inverse_ntt`, which the aarch64 `mlkem_intt` computes, is FIPS 203's
`NTTInv` times `2 ^ 16`. -/
theorem inverseNtt_eq (f : ℕ → ℤ) (k : ℕ) (hk : k < 256) :
    (inverseNtt f k : Zq) = 2 ^ 16 * (NTTInv (poly f))[k]! := by
  rw [← inverse_sum _ k hk, inverseNtt, cast_rem]
  push_cast
  refine congrArg (512 * ·) (sum_congr rfl fun j hj => ?_)
  have := bitRev_lt j (mem_range.1 hj)
  have : k % 2 < 2 := Nat.mod_lt _ (by norm_num)
  rw [bitreverse7_eq j (mem_range.1 hj), poly_get f _ (by omega)]

/-- `mulcache`, which the aarch64 `mlkem_mulcache_compute` computes, is each odd
coefficient times the root `MultiplyNTTs` multiplies it by. -/
theorem mulcache_eq (f : ℕ → ℤ) (k : ℕ) (hk : k < 128) :
    (mulcache f k : Zq) = (poly f)[2 * k + 1]! * ζ ^ (2 * bitRev 7 k + 1) := by
  rw [mulcache, cast_rem, poly_get f _ (by omega), bitreverse7_eq k hk]
  push_cast
  rfl

theorem multiplyNTTs_even (f g : Polynomial) (i : ℕ) (hi : i < 128) :
    (MultiplyNTTs f g)[2 * i]! = f[2 * i]! * g[2 * i]! + f[2 * i + 1]! * g[2 * i + 1]! * ζ ^ (2 * bitRev 7 i + 1) := by
  rw [Symcrust.Properties.MLKEM.Ntt.MultiplyNTTs_eq_ofFn, Vector.getElem!_ofFn _ _ (by omega)]
  simp only [show 2 * i % 2 = 0 by omega, show 2 * i / 2 = i by omega, ite_true]
  rfl

theorem multiplyNTTs_odd (f g : Polynomial) (i : ℕ) (hi : i < 128) :
    (MultiplyNTTs f g)[2 * i + 1]! = f[2 * i]! * g[2 * i + 1]! + f[2 * i + 1]! * g[2 * i]! := by
  rw [Symcrust.Properties.MLKEM.Ntt.MultiplyNTTs_eq_ofFn, Vector.getElem!_ofFn _ _ (by omega)]
  simp only [show (2 * i + 1) % 2 = 1 by omega, show (2 * i + 1) / 2 = i by omega]
  rfl

theorem inverseMod_eq : (2 : Zq) ^ 16 * ((inverseMod : ℤ) : Zq) = 1 := by decide

/-- `basemul3_even`, which the aarch64 `mlkem_basemul_k3` computes, is the sum of
three `MultiplyNTTs` products' even coefficients times `2 ^ -16`, given each
`ymt` is `ym`'s `mulcache`. -/
theorem basemul3Even_eq (x0 y0 y0t x1 y1 y1t x2 y2 y2t : ℕ → ℤ) (i : ℕ) (hi : i < 128)
    (h0 : (y0t i : Zq) = mulcache y0 i) (h1 : (y1t i : Zq) = mulcache y1 i)
    (h2 : (y2t i : Zq) = mulcache y2 i) :
    2 ^ 16 * (basemul3Even x0 y0 y0t x1 y1 y1t x2 y2 y2t i : Zq) =
      (MultiplyNTTs (poly x0) (poly y0))[2 * i]! + (MultiplyNTTs (poly x1) (poly y1))[2 * i]! +
        (MultiplyNTTs (poly x2) (poly y2))[2 * i]! := by
  simp only [multiplyNTTs_even _ _ i hi, poly_get _ _ (by omega : 2 * i < 256),
    poly_get _ _ (by omega : 2 * i + 1 < 256)]
  rw [basemul3Even, pmulAcc3, cast_rem, Int.cast_mul, ← mul_assoc, inverseMod_eq, one_mul]
  simp only [pmullAcc3, pmull]
  push_cast
  rw [h0, h1, h2, mulcache_eq _ _ hi, mulcache_eq _ _ hi, mulcache_eq _ _ hi,
    poly_get _ _ (by omega : 2 * i + 1 < 256), poly_get _ _ (by omega : 2 * i + 1 < 256),
    poly_get _ _ (by omega : 2 * i + 1 < 256)]
  ring

/-- `basemul3_odd`, which the aarch64 `mlkem_basemul_k3` computes, is the sum of
three `MultiplyNTTs` products' odd coefficients times `2 ^ -16`. -/
theorem basemul3Odd_eq (x0 y0 x1 y1 x2 y2 : ℕ → ℤ) (i : ℕ) (hi : i < 128) :
    2 ^ 16 * (basemul3Odd x0 y0 x1 y1 x2 y2 i : Zq) =
      (MultiplyNTTs (poly x0) (poly y0))[2 * i + 1]! +
        (MultiplyNTTs (poly x1) (poly y1))[2 * i + 1]! +
        (MultiplyNTTs (poly x2) (poly y2))[2 * i + 1]! := by
  simp only [multiplyNTTs_odd _ _ i hi, poly_get _ _ (by omega : 2 * i < 256),
    poly_get _ _ (by omega : 2 * i + 1 < 256)]
  rw [basemul3Odd, pmulAcc3, cast_rem, Int.cast_mul, ← mul_assoc, inverseMod_eq, one_mul]
  simp only [pmullAcc3, pmull]
  push_cast
  ring

/-- `tomont_3329`, which `mlkem_tomont` computes on both targets, multiplies by `2 ^ 16`. -/
theorem tomont3329_eq (a : ℕ → ℤ) (i : ℕ) : (tomont3329 a i : Zq) = 2 ^ 16 * (a i : Zq) := by
  rw [tomont3329, cast_rem]
  push_cast
  rfl

theorem avx2_forward_index : ∀ p < 256,
    avx2NttOrder (16 * (p / 32) + p % 16) < 128 ∧
    avx2Layout p = 2 * bitRev 7 (avx2NttOrder (16 * (p / 32) + p % 16)) + (p / 16) % 2 := by
  decide +kernel

/-- `avx2_forward_ntt`, which the x86_64 `mlkem_ntt` computes, is FIPS 203's
`NTT` in the AVX2 layout. -/
theorem avx2ForwardNtt_eq (f : ℕ → ℤ) (p : ℕ) (hp : p < 256) :
    (avx2ForwardNtt f p : Zq) = (NTT (poly f))[avx2Layout p]! := by
  obtain ⟨ho, hl⟩ := avx2_forward_index p hp
  have hb : (p / 16) % 2 < 2 := Nat.mod_lt _ (by norm_num)
  rw [hl, NTT_get _ _ _ (bitRev_lt _ ho) hb, bitRev_bitRev _ ho, avx2ForwardNtt, cast_rem]
  push_cast
  refine sum_congr rfl fun j hj => ?_
  rw [poly_get f _ (by have := mem_range.1 hj; omega), ζ_eq]

theorem avx2_inverse_index : ∀ j < 128, ∀ b < 2,
    avx2NttOrder' j / 16 * 32 + b * 16 + avx2NttOrder' j % 16 < 256 ∧
    avx2Layout (avx2NttOrder' j / 16 * 32 + b * 16 + avx2NttOrder' j % 16) = 2 * bitRev 7 j + b := by
  decide +kernel

/-- `avx2_inverse_ntt`, which the x86_64 `mlkem_intt` computes, is FIPS 203's
`NTTInv` times `2 ^ 16`, given its input `f` holds `g` in the AVX2 layout. -/
theorem avx2InverseNtt_eq (f : ℕ → ℤ) (g : Polynomial)
    (h : ∀ p < 256, (f p : Zq) = g[avx2Layout p]!) (k : ℕ) (hk : k < 256) :
    (avx2InverseNtt f k : Zq) = 2 ^ 16 * (NTTInv g)[k]! := by
  rw [← inverse_sum _ k hk, avx2InverseNtt, cast_rem]
  push_cast
  refine congrArg (512 * ·) (sum_congr rfl fun j hj => ?_)
  obtain ⟨hlt, hl⟩ := avx2_inverse_index j (mem_range.1 hj) (k % 2) (Nat.mod_lt _ (by norm_num))
  rw [h _ hlt, hl]

end rind.spec.s2n
