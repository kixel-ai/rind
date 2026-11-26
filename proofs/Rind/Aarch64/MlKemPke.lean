import Rind.Aarch64.MlKemPoly
open Aeneas Aeneas.Std Result rind.spec Spec Spec.MLKEM rind.spec.mlkem rind.spec.s2n

/-!
# K-PKE on aarch64

`mid::mlkem`'s K-PKE for ML-KEM-768, over `MlKemPoly`'s vector specs. The
translation takes the set's `Params` impl as a parameter, since Aeneas does
not translate it: `Is768` states what ML-KEM-768's impl is.
-/

namespace rind.aarch64

namespace MlKemPke

open MlKemCoding MlKemRoutines MlKemGeneric MlKemPoly

abbrev Vec := Std.Array Poly 3#usize
abbrev Mat := Std.Array Poly 9#usize
abbrev Cache := Std.Array (Std.Array I16 128#usize) 3#usize
abbrev Enc := Std.Array (Std.Array U8 384#usize) 3#usize
abbrev EkBytes := Std.Array U8 1184#usize
abbrev CtBytes := Std.Array U8 1088#usize
abbrev DkBytes := Std.Array U8 2400#usize

/-- `P` is ML-KEM-768's `Params` impl: its constants, and its types'
`FixedArray` impls those of arrays. -/
structure Is768 {X : Type} (P : mid.mlkem.Params X Vec Mat EkBytes CtBytes DkBytes Cache Enc) : Prop where
  K : P.K = ok 3#usize
  ETA1 : P.ETA1 = ok 2#usize
  DU : P.DU = ok 10#usize
  DV : P.DV = ok 4#usize
  vec : IsArray P.VectorInst.FixedArraySelfArrayI16256Inst
  cache : IsArray P.VectorInst.FixedArraySelf_MulCacheArrayI16128Inst
  enc : IsArray P.VectorInst.FixedArraySelf_EncodedArrayU8384Inst
  mat : IsArray P.FixedArraySelf_MatrixArrayI16256Inst
  ek : IsArray P.FixedArraySelf_EncapKeyBytesU8Inst
  ct : IsArray P.FixedArraySelf_CiphertextBytesU8Inst
  dk : IsArray P.FixedArraySelf_DecapKeyBytesU8Inst

theorem Holds.mono {lo hi lo' hi' : ℤ} {n : ℕ} {a : List I16} {F : Polynomial} (h : Holds lo hi n a F)
    (h1 : lo' ≤ lo) (h2 : hi ≤ hi') : Holds lo' hi' n a F :=
  fun p hp => ⟨le_trans h1 (h p hp).1, le_trans (h p hp).2.1 h2, (h p hp).2.2⟩

/-- `len` bytes of `l` from `off`. -/
abbrev sub (l : List U8) (off len : ℕ) : List U8 := (l.drop off).take len

theorem sub_length (l : List U8) (off len : ℕ) (h : off + len ≤ l.length) : (sub l off len).length = len := by
  simp only [sub, List.length_take, List.length_drop]
  omega

/-- `Decompress_10(ByteDecode_10)` of polynomial `j` of `u`'s first 960 bytes. -/
def decompU (u : List U8) (hu : 960 ≤ u.length) (j : ℕ) : Polynomial :=
  if hj : j < 3 then
    Polynomial.Decompress 10 (ByteDecode (toVec (32 * 10) (sub u (320 * j) 320) (sub_length _ _ _ (by omega))))
  else 0

/-- `Decompress_4(ByteDecode_4)` of `v`'s 128 bytes. -/
def decompV (c : List U8) (hc : c.length = 1088) : Polynomial :=
  Polynomial.Decompress 4 (ByteDecode (toVec (32 * 4) (sub c 960 128) (sub_length _ _ _ (by omega))))

/-- `K-PKE.Decrypt`'s `w`, as rind computes it. -/
def decrypt (dk : Enc) (c : List U8) (hc : c.length = 1088) : Polynomial :=
  decompV c hc - NTTInv (dot3 (fun j => decode12 (dk.val[j]!)) (fun j => NTT (decompU c (by omega) j)))

theorem decompress_vector_loop_spec (bytes : Slice U8) (hb : 960 ≤ bytes.val.length) (polys : Slice Poly)
    (hl : polys.length = 3) (it : core.ops.range.Range Usize) (hs : it.start.val = 0) (he : it.end.val = 3) :
    mid.mlkem.decompress_vector_loop 10#usize 320#usize it bytes polys ⦃ y => y.length = 3 ∧
      ∀ j < 3, Holds 0 3328 256 (y.val[j]!).val (decompU bytes.val hb j) ⦄ := by
  unfold mid.mlkem.decompress_vector_loop
  apply WP.spec_mono (slice_loop (α := Poly) 3 (fun _ _ _ => True)
    (fun j _ b => Holds 0 3328 256 b.val (decompU bytes.val hb j)) _ ?_ polys hl (fun _ _ => trivial) it hs he)
  · intro y hy
    exact hy
  · intro it s he hs hl _
    simp only
    unfold mid.mlkem.decompress_vector_loop.body
    step as ⟨o', it1, ho, he1⟩
    split_ifs at ho with hlt
    · obtain ⟨rfl, hst⟩ := ho
      simp only
      step as ⟨i1, hi1⟩
      step as ⟨i2, hi2⟩
      step as ⟨s1, hs1, hsl⟩
      have hs1l : s1.val.length = (320#usize).val := by
        show s1.length = _
        rw [hsl, hi2, hi1]
        scalar_tac
      rw [try_from_ok 320#usize s1 hs1l]
      simp only [core.result.Result.unwrap]
      step as ⟨a, back', ha, hb'⟩
      subst hb'
      step with decompress_spec 10#usize (L := 320#usize) (by decide) (by decide) (Std.Array.from (n := 320#usize) s1.val hs1l) a
        as ⟨a2, ha2⟩
      refine ⟨by rw [he1]; exact he, hst, by omega, by rw [set_length]; exact hl, ?_,
        fun j hj => set_getElem!_ne _ _ _ _ hj⟩
      rw [set_getElem!_self _ _ _ (by omega)]
      have hv : s1.val = sub bytes.val (320 * it.start.val) 320 := by
        rw [hs1, hi1, hi2]
        simp only [sub, List.slice]
        congr 1
        scalar_tac
      unfold decompU
      rw [dite_true' (by omega)]
      convert ha2 using 4
      · rfl
      · rfl
      · rw [Std.Array.from_val, hv]
    · obtain ⟨rfl, hst⟩ := ho
      apply (WP.spec_ok _).2
      exact ⟨by omega, rfl⟩

end MlKemPke

end rind.aarch64
