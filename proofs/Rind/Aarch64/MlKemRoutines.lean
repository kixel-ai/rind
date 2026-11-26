import Rind.Aarch64.MlKemCoding
import Rind.Aarch64.MlKemTables
import Rind.S2nMlKem
import Rind.MlKemPacking
open Aeneas Aeneas.Std Result rind.spec Spec Spec.MLKEM rind.spec.mlkem rind.spec.s2n

/-!
# ML-KEM's polynomial routines on aarch64

Each axiom restates one of the HOL Light theorems about the ML-KEM routines
aarch64 runs, about the opaque Rust wrapper around it: s2n-bignum's, at the
revision rind transliterates (3f01260f), for the NTTs, the mulcache, base
multiplication, reduction, Montgomery conversion, 12-bit packing, and
rejection sampling, and mlkem-native's, at the revision
`admin/import-mlkem-native` imports (58721ebd), for ciphertext compression.
Each theorem's preconditions on memory hold for every call from safe Rust:
a `&mut` result cannot overlap an input, the routine's code, or its table,
the routine's stack lies below the caller's frame, and the ABI keeps the
stack pointer 16-byte aligned; its total correctness (`ensures`) gives the
`ok`. A theorem whose postcondition assumes the tables or the input bounds it
names is restated with them as hypotheses, which is weaker. The restatement,
that rind's inline assembly is the object code each proof is about, which
`admin/prove bytes` checks for s2n-bignum's routines and
[a quest](/quest/m4/verified/mlkem-compress-bytes.md) adds for
mlkem-native's, and that each wrapper passes the arguments the theorem names,
are trusted. The tables `low::aarch64::mlkem` passes are not: `MlKemTables`
holds s2n-bignum's, which `admin/prove` writes from its HOL Light sources,
and the kernel checks rind's against them (`ntt_zetas_01234_eq` and its
siblings). The rejection sampler's 4096-byte table is the exception, too long
a literal for Lean to elaborate: its wrapper stays opaque, and `admin/prove`
checks the table's text is s2n-bignum's instead.

ML-KEM-768, the set the ✓ covers, runs `mlkem_basemul_k3` alone of the base
multiplications, so the axioms leave out `_k2` and `_k4`.

The specs after them state what each routine computes in FIPS 203's terms,
which `mid::mlkem`'s proof builds on: the NTTs, the mulcache, and the base
multiplication, over coefficients in FIPS 203's order, as aarch64 keeps them
(`mlkem_ntt_spec`, `mlkem_intt_spec`, `mlkem_mulcache_compute_spec`,
`mlkem_basemul_k3_spec`); reduction and Montgomery conversion
(`mlkem_reduce_spec`, `mlkem_tomont_spec`); `ByteEncode_12`
(`mlkem_tobytes_spec`); and `ByteEncode_d(Compress_d(f))` for each width a
ciphertext takes (`mlkem_compress_spec`).
-/

namespace rind.aarch64

namespace MlKemRoutines

open MlKemCoding MlKemTables

/-- The integers an array of `i16`s holds, as s2n-bignum's specs index them. -/
def coeff (a : List I16) : ℕ → ℤ := fun i => (a[i]!).val

/-- The words an array of `i16`s holds, as numbers. -/
def words (a : List I16) : List ℕ := a.map (·.bv.toNat)

/-! ## s2n-bignum's contracts -/

/-- `MLKEM_NTT_SUBROUTINE_CORRECT`, which assumes its input's coefficients
below `2^13` in magnitude,
https://github.com/awslabs/s2n-bignum/blob/3f01260ff1bd2577abf0117ce45aa008bc243a80/arm/proofs/mlkem_ntt.ml#L514 -/
axiom mlkem_ntt_axiom (a : Std.Array I16 256#usize) (z01234 : Std.Array I16 80#usize)
    (z56 : Std.Array I16 384#usize) (h01234 : z01234.val.map (·.val) = nttZetasLayer01234)
    (h56 : z56.val.map (·.val) = nttZetasLayer56) (hb : ∀ i < 256, |(a.val[i]!).val| ≤ 8191) :
    low.aarch64.mlkem_ntt.mlkem_ntt a z01234 z56 ⦃ r => ∀ i < 256,
      (r.val[i]!).val ≡ forwardNtt (coeff a.val) i [ZMOD 3329] ∧ |(r.val[i]!).val| ≤ 23594 ⦄

/-- `MLKEM_INTT_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/3f01260ff1bd2577abf0117ce45aa008bc243a80/arm/proofs/mlkem_intt.ml#L556 -/
axiom mlkem_intt_axiom (a : Std.Array I16 256#usize) (z01234 : Std.Array I16 80#usize)
    (z56 : Std.Array I16 384#usize) (h01234 : z01234.val.map (·.val) = inttZetasLayer01234)
    (h56 : z56.val.map (·.val) = inttZetasLayer56) :
    low.aarch64.mlkem_intt.mlkem_intt a z01234 z56 ⦃ r => ∀ i < 256,
      (r.val[i]!).val ≡ inverseNtt (coeff a.val) i [ZMOD 3329] ∧ |(r.val[i]!).val| ≤ 26624 ⦄

/-- `MLKEM_MULCACHE_COMPUTE_SUBROUTINE_CORRECT`, whose `have_mulcache_zetas`
is `hz` and `hzt`,
https://github.com/awslabs/s2n-bignum/blob/3f01260ff1bd2577abf0117ce45aa008bc243a80/arm/proofs/mlkem_mulcache_compute.ml#L213 -/
axiom mlkem_mulcache_compute_axiom (x : Std.Array I16 128#usize) (a : Std.Array I16 256#usize)
    (z zt : Std.Array I16 128#usize) (hz : z.val.map (·.val) = mulcacheZetas)
    (hzt : zt.val.map (·.val) = mulcacheZetasTwisted) :
    low.aarch64.mlkem_mulcache_compute.mlkem_mulcache_compute x a z zt ⦃ r => ∀ i < 128,
      (r.val[i]!).val ≡ mulcache (coeff a.val) i [ZMOD 3329] ∧ |(r.val[i]!).val| ≤ 3328 ⦄

/-- `MLKEM_BASEMUL_K3_SUBROUTINE_CORRECT`, which assumes the first factor's
coefficients at most `2^12` in magnitude; its three polynomials, and the
second factor's, are consecutive in each array, and their mulcaches in `bt`,
https://github.com/awslabs/s2n-bignum/blob/3f01260ff1bd2577abf0117ce45aa008bc243a80/arm/proofs/mlkem_basemul_k3.ml#L403 -/
axiom mlkem_basemul_k3_axiom (r : Std.Array I16 256#usize) (a b : Std.Array I16 768#usize)
    (bt : Std.Array I16 384#usize) (ha : ∀ i < 768, |(a.val[i]!).val| ≤ 4096) :
    low.aarch64.mlkem_basemul_k3.mlkem_basemul_k3 r a b bt ⦃ r' => ∀ i < 128,
      (r'.val[2 * i]!).val ≡ basemul3Even
        (coeff a.val) (coeff b.val) (coeff bt.val)
        (coeff (a.val.drop 256)) (coeff (b.val.drop 256)) (coeff (bt.val.drop 128))
        (coeff (a.val.drop 512)) (coeff (b.val.drop 512)) (coeff (bt.val.drop 256)) i [ZMOD 3329] ∧
      (r'.val[2 * i + 1]!).val ≡ basemul3Odd
        (coeff a.val) (coeff b.val) (coeff (a.val.drop 256)) (coeff (b.val.drop 256))
        (coeff (a.val.drop 512)) (coeff (b.val.drop 512)) i [ZMOD 3329] ⦄

/-- `MLKEM_REDUCE_SUBROUTINE_CORRECT`, whose `rem` is the remainder in
`[0, 3329)`, as Lean's `%` on integers is,
https://github.com/awslabs/s2n-bignum/blob/3f01260ff1bd2577abf0117ce45aa008bc243a80/arm/proofs/mlkem_reduce.ml#L181 -/
axiom mlkem_reduce_axiom (a : Std.Array I16 256#usize) :
    low.aarch64.mlkem_reduce.mlkem_reduce a ⦃ r => ∀ i < 256, (r.val[i]!).val = (a.val[i]!).val % 3329 ⦄

/-- `MLKEM_TOMONT_SUBROUTINE_CORRECT`,
https://github.com/awslabs/s2n-bignum/blob/3f01260ff1bd2577abf0117ce45aa008bc243a80/arm/proofs/mlkem_tomont.ml#L180 -/
axiom mlkem_tomont_axiom (a : Std.Array I16 256#usize) :
    low.aarch64.mlkem_tomont.mlkem_tomont a ⦃ r => ∀ i < 256,
      (r.val[i]!).val ≡ tomont3329 (coeff a.val) i [ZMOD 3329] ∧ |(r.val[i]!).val| ≤ 3328 ⦄

/-- `MLKEM_TOBYTES_SUBROUTINE_CORRECT`: the low 12 bits of each coefficient,
packed,
https://github.com/awslabs/s2n-bignum/blob/3f01260ff1bd2577abf0117ce45aa008bc243a80/arm/proofs/mlkem_tobytes.ml#L198 -/
axiom mlkem_tobytes_axiom (r : Std.Array U8 384#usize) (a : Std.Array I16 256#usize) :
    low.aarch64.mlkem_tobytes.mlkem_tobytes r a ⦃ r' => leNat r'.val = numOfWords 12 (words a.val) ⦄

/-- The coefficients rejection sampling keeps from `bytes`: the first 256 of
its 12-bit words, least significant first, that are below `q`. -/
def rejOut (bytes : List U8) : List ℕ :=
  ((wordsOfNum 12 (2 * bytes.length / 3) (leNat bytes)).filter (· < 3329)).take 256

/-- `MLKEM_REJ_UNIFORM_SUBROUTINE_CORRECT`, for an input a whole number of
24-byte blocks, as it requires, about the wrapper, whose table precondition
`admin/prove` checks: it returns how many coefficients it kept and writes
them, leaving the rest of `r` unspecified,
https://github.com/awslabs/s2n-bignum/blob/3f01260ff1bd2577abf0117ce45aa008bc243a80/arm/proofs/mlkem_rej_uniform_VARIABLE_TIME.ml#L1626 -/
axiom mlkem_rej_uniform_vartime_axiom (r : Std.Array I16 256#usize) (input : Slice U8)
    (hlen : input.length % 24 = 0) :
    low.aarch64.mlkem.mlkem_rej_uniform_vartime r input ⦃ res =>
      res.1.val = (rejOut input.val).length ∧
        ∀ i < (rejOut input.val).length, (res.2.val[i]!).val = (((rejOut input.val)[i]! : ℕ) : ℤ) ⦄

/-! ## mlkem-native's contracts

Each assumes coefficients in `[0, q)`. -/

/-- `MLKEM_POLY_COMPRESS_D4_SUBROUTINE_CORRECT`,
https://github.com/pq-code-package/mlkem-native/blob/58721ebde4b682bb3384ef7d11333e4f0ddb0164/proofs/hol_light/aarch64/proofs/mlkem_poly_compress_d4_aarch64_asm.ml#L203 -/
axiom mlkem_compress_d4_axiom (r : Std.Array U8 128#usize) (a : Std.Array I16 256#usize)
    (ha : ∀ i < 256, 0 ≤ (a.val[i]!).val ∧ (a.val[i]!).val ≤ 3328) :
    low.aarch64.mlkem.mlkem_compress_d4 r a ⦃ r' =>
      leNat r'.val = numOfWords 4 ((words a.val).map (compressD 4)) ⦄

/-- `MLKEM_POLY_COMPRESS_D5_SUBROUTINE_CORRECT`, whose table precondition holds
because the wrapper passes rind's copy of mlkem-native's table,
https://github.com/pq-code-package/mlkem-native/blob/58721ebde4b682bb3384ef7d11333e4f0ddb0164/proofs/hol_light/aarch64/proofs/mlkem_poly_compress_d5_aarch64_asm.ml#L407 -/
axiom mlkem_compress_d5_axiom (r : Std.Array U8 160#usize) (a : Std.Array I16 256#usize)
    (ha : ∀ i < 256, 0 ≤ (a.val[i]!).val ∧ (a.val[i]!).val ≤ 3328) :
    low.aarch64.mlkem.mlkem_compress_d5 r a ⦃ r' =>
      leNat r'.val = numOfWords 5 ((words a.val).map (compressD 5)) ⦄

/-- `MLKEM_POLY_COMPRESS_D10_SUBROUTINE_CORRECT`,
https://github.com/pq-code-package/mlkem-native/blob/58721ebde4b682bb3384ef7d11333e4f0ddb0164/proofs/hol_light/aarch64/proofs/mlkem_poly_compress_d10_aarch64_asm.ml#L765 -/
axiom mlkem_compress_d10_axiom (r : Std.Array U8 320#usize) (a : Std.Array I16 256#usize)
    (ha : ∀ i < 256, 0 ≤ (a.val[i]!).val ∧ (a.val[i]!).val ≤ 3328) :
    low.aarch64.mlkem.mlkem_compress_d10 r a ⦃ r' =>
      leNat r'.val = numOfWords 10 ((words a.val).map (compressD 10)) ⦄

/-- `MLKEM_POLY_COMPRESS_D11_SUBROUTINE_CORRECT`,
https://github.com/pq-code-package/mlkem-native/blob/58721ebde4b682bb3384ef7d11333e4f0ddb0164/proofs/hol_light/aarch64/proofs/mlkem_poly_compress_d11_aarch64_asm.ml#L843 -/
axiom mlkem_compress_d11_axiom (r : Std.Array U8 352#usize) (a : Std.Array I16 256#usize)
    (ha : ∀ i < 256, 0 ≤ (a.val[i]!).val ∧ (a.val[i]!).val ≤ 3328) :
    low.aarch64.mlkem.mlkem_compress_d11 r a ⦃ r' =>
      leNat r'.val = numOfWords 11 ((words a.val).map (compressD 11)) ⦄

/-! ## rind's tables are s2n-bignum's -/

theorem ntt_zetas_01234_eq :
    (low.aarch64.mlkem.NTT_ZETAS_01234 : Std.Array I16 80#usize).val.map (·.val) =
      nttZetasLayer01234 := by
  decide +kernel

theorem ntt_zetas_56_eq :
    (low.aarch64.mlkem.NTT_ZETAS_56 : Std.Array I16 384#usize).val.map (·.val) =
      nttZetasLayer56 := by
  decide +kernel

theorem intt_zetas_01234_eq :
    (low.aarch64.mlkem.INTT_ZETAS_01234 : Std.Array I16 80#usize).val.map (·.val) =
      inttZetasLayer01234 := by
  decide +kernel

theorem intt_zetas_56_eq :
    (low.aarch64.mlkem.INTT_ZETAS_56 : Std.Array I16 384#usize).val.map (·.val) =
      inttZetasLayer56 := by
  decide +kernel

theorem mulcache_zetas_eq :
    (low.aarch64.mlkem.MULCACHE_ZETAS : Std.Array I16 128#usize).val.map (·.val) =
      mulcacheZetas := by
  decide +kernel

theorem mulcache_zetas_twisted_eq :
    (low.aarch64.mlkem.MULCACHE_ZETAS_TWISTED : Std.Array I16 128#usize).val.map (·.val) =
      mulcacheZetasTwisted := by
  decide +kernel

end MlKemRoutines

end rind.aarch64
