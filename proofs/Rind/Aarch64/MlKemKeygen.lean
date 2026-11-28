import Rind.Aarch64.MlKemSample
open Aeneas Aeneas.Std Result rind.spec Spec Spec.MLKEM rind.spec.mlkem rind.spec.s2n

/-!
# K-PKE's key generation on aarch64

`DecapKey::kpke_keygen` for ML-KEM-768, over `MlKemPoly`'s vector specs,
`MlKemCbd`'s noise, `MlKemSample`'s matrix, and SHA-3's contexts: it is
`K-PKE.KeyGen` (`kpke_keygen_fips`), and the encapsulation key it returns
holds its hash and the decoded form `kpke_encrypt_fips` takes. Like
`decoded_new_spec`, it assumes `SampleNTT` finishes on each of the matrix's
inputs (`Halts`), which no proof shows for every input.
-/

namespace rind.aarch64

namespace MlKemKeygen

open MlKemCoding MlKemRoutines MlKemPoly MlKemPke MlKemEncrypt MlKemSample
open MlKemCbd (cbd2 get2 sample_poly_cbd_spec toVec_toList)

/-! ## `t̂ = Â ∘ ŝ + ê` -/

/-- The inner loop of `Coeffs::mul_add`: each coefficient's sum, wrapping. -/
theorem mul_add_inner_spec (a row : Poly)
    (hb : ∀ p < 256, -32768 ≤ (row.val[p]!).val + (a.val[p]!).val ∧ (row.val[p]!).val + (a.val[p]!).val ≤ 32767)
    (it : core.ops.range.Range Usize) (hs : it.start.val = 0) (he : it.end.val = 256) :
    mid.mlkem.CoeffsMNtt.mul_add_loop0_loop0 it a row ⦃ r =>
      ∀ p < 256, (r.val[p]!).val = (row.val[p]!).val + (a.val[p]!).val ⦄ := by
  unfold mid.mlkem.CoeffsMNtt.mul_add_loop0_loop0
  apply WP.spec_mono (range_loop 256 (fun c (s : Poly) =>
    ∀ p < 256, (s.val[p]!).val = if p < c then (row.val[p]!).val + (a.val[p]!).val else (row.val[p]!).val)
    _ ?_ it row he (by omega) (fun p hp => by simp [hs]))
  · intro r hr p hp
    rw [hr p hp, MlKemPoly.ite_pos hp]
  · intro it s he hs hinv
    simp only
    unfold mid.mlkem.CoeffsMNtt.mul_add_loop0_loop0.body
    step as ⟨o', it1, ho, he1⟩
    split_ifs at ho with hlt
    · obtain ⟨rfl, hst⟩ := ho
      simp only
      step as ⟨x, hx⟩
      step as ⟨y, hy⟩
      step as ⟨z, hz⟩
      step as ⟨a2, ha2⟩
      refine ⟨by rw [he1]; exact he, hst, by omega, fun p hp => ?_⟩
      rw [ha2, MlKemPoly.array_set_getElem! _ _ _ _ (by omega)]
      split_ifs with h1 h2 h2
      · subst h1
        rw [hz, core.num.I16.wrapping_add_val_eq, hx, hy, ← getElem!_pos, ← getElem!_pos]
        have := hinv it.start.val hp
        rw [MlKemPoly.ite_neg (by omega)] at this
        rw [this]
        exact bmod16 _ (hb _ hp).1 (hb _ hp).2
      · omega
      · rw [hinv p hp, MlKemPoly.ite_pos (by omega)]
      · rw [hinv p hp, MlKemPoly.ite_neg (by omega)]
    · obtain ⟨rfl, hst⟩ := ho
      apply (WP.spec_ok _).2
      have : it.start.val = 256 := by omega
      rw [this] at hinv
      exact hinv

/-- The loop of `Coeffs::mul_add`: row `i` gains the scalar product of the
matrix's row `i` and `s`, given `s`'s mulcache. -/
theorem mul_add_loop_spec {Enc : Type}
    (vec : mid.mlkem.Vector (Std.Array Poly 3#usize) (Std.Array (Std.Array I16 128#usize) 3#usize) Enc)
    (h1 : IsArray vec.FixedArraySelfArrayI16256Inst) (h2 : IsArray vec.FixedArraySelf_MulCacheArrayI16128Inst)
    (mat : mid.mlkem.FixedArray (Std.Array Poly 9#usize) Poly)
    (a : Slice Poly) (ha : a.length = 9) (s : Std.Array Poly 3#usize)
    (sc : Std.Array (Std.Array I16 128#usize) 3#usize) (A : ℕ → ℕ → Polynomial) (S E : ℕ → Polynomial)
    (hA : ∀ i < 3, ∀ j < 3, Holds (-4096) 4096 256 (a.val[3 * i + j]!).val (A i j))
    (hs : ∀ j < 3, Congr (s.val[j]!).val (S j)) (hc : ∀ j < 3, CacheHolds (sc.val[j]!).val (S j))
    (rows0 : Slice Poly) (hl0 : rows0.length = 3) (he0 : VHolds (-23594) 23594 3 rows0.val E)
    (term : mid.mlkem.Coeffs Poly mid.mlkem.Ntt)
    (it : core.ops.range.Range Usize) (hst : it.start.val = 0) (hen : it.end.val = 3) :
    mid.mlkem.CoeffsMNtt.mul_add_loop0 mat vec it (s, ()) (sc, ()) term a 3#usize rows0 ⦃ r =>
      r.length = 3 ∧ ∀ i < 3, Congr (r.val[i]!).val (dot3 (A i) S + E i) ⦄ := by
  unfold mid.mlkem.CoeffsMNtt.mul_add_loop0
  apply range_loop' 3 (fun i (x : mid.mlkem.Coeffs Poly mid.mlkem.Ntt × Slice Poly) =>
      x.2.length = 3 ∧ (∀ j < i, Congr (x.2.val[j]!).val (dot3 (A j) S + E j)) ∧
        ∀ j, i ≤ j → x.2.val[j]! = rows0.val[j]!) _ _ ?_ it (term, rows0) hen (by omega)
    ⟨hl0, fun j hj => absurd hj (by omega), fun _ _ => rfl⟩
  rintro it ⟨t, rows⟩ he hs' ⟨hl, hdone, hrest⟩
  simp only at hl hdone hrest ⊢
  unfold mid.mlkem.CoeffsMNtt.mul_add_loop0.body
  step as ⟨o', it1, ho, he1⟩
  split_ifs at ho with hlt
  · obtain ⟨rfl, hst1⟩ := ho
    obtain ⟨t0, pd⟩ := t
    simp only [h1.as_ref, h2.as_ref]
    step as ⟨i1, hi1⟩
    step as ⟨i2, hi2⟩
    step as ⟨sl, hsl1, hsl2⟩
    step as ⟨s1, hs1⟩
    step as ⟨s2, hs2⟩
    have hsl : sl.length = 3 := by scalar_tac
    have hsv : ∀ j < 3, sl.val[j]! = a.val[3 * it.start.val + j]! := by
      intro j hj
      rw [hsl1, List.getElem!_slice _ _ _ _ ⟨by scalar_tac, by scalar_tac⟩]
      congr 1
      scalar_tac
    step with basemul_spec t0 sl s1 s2 (A it.start.val) S hsl (array_length s1 s hs1)
        (array_length s2 sc hs2) (fun j hj => by rw [hsv j hj]; exact hA _ (by omega) j hj)
        (fun j hj p hp => by rw [hs1]; exact hs j hj p hp) (by rw [hs2]; exact hc) as ⟨a2, ha2⟩
    step with mlkem_tomont_spec a2 (dot3 (A it.start.val) S) ha2 as ⟨a3, ha3⟩
    step as ⟨row, back, hrow, hback⟩
    have hrow' : row = rows0.val[it.start.val]! := by
      rw [hrow, ← getElem!_pos, hrest _ le_rfl]
    rw [N_eq]
    step with mul_add_inner_spec a3 row (fun p hp => by
        obtain ⟨x1, x2, -⟩ := ha3 p hp
        obtain ⟨y1, y2, -⟩ := he0 it.start.val (by omega) p hp
        rw [hrow']
        constructor <;> omega)
      { start := 0#usize, «end» := 256#usize } rfl rfl as ⟨row1, hrow1⟩
    refine ⟨by rw [he1]; exact he, hst1, by omega, ?_, ?_, ?_⟩
    · rw [hback, set_length]; exact hl
    · intro j hj
      rw [hback]
      by_cases hji : j = it.start.val
      · subst hji
        rw [set_getElem!_self _ _ _ (by omega)]
        intro p hp
        rw [hrow1 p hp, add_get _ _ _ hp, ← (ha3 p hp).2.2, hrow', ← (he0 _ (by omega) p hp).2.2]
        push_cast
        ring
      · rw [set_getElem!_ne _ _ _ _ hji]
        exact hdone j (by omega)
    · intro j hj
      rw [hback, set_getElem!_ne _ _ _ _ (by omega)]
      exact hrest j (by omega)
  · obtain ⟨rfl, hst1⟩ := ho
    apply (WP.spec_ok _).2
    have : it.start.val = 3 := by omega
    rw [this] at hdone
    exact ⟨hl, hdone⟩

/-- `Coeffs::mul_add`: row `i` is the scalar product of the matrix's row `i`
and `s`, plus `e`'s polynomial `i`, reduced into `[0, q)`, for a matrix of
coefficients at most `2 ^ 12` in magnitude and `e` an NTT's output. -/
theorem mul_add_spec {Enc : Type}
    (vec : mid.mlkem.Vector (Std.Array Poly 3#usize) (Std.Array (Std.Array I16 128#usize) 3#usize) Enc)
    (h1 : IsArray vec.FixedArraySelfArrayI16256Inst) (h2 : IsArray vec.FixedArraySelf_MulCacheArrayI16128Inst)
    (mat : mid.mlkem.FixedArray (Std.Array Poly 9#usize) Poly) (hm : IsArray mat)
    (a : Std.Array Poly 9#usize) (s e : Std.Array Poly 3#usize) (A : ℕ → ℕ → Polynomial)
    (S E : ℕ → Polynomial)
    (hA : ∀ i < 3, ∀ j < 3, Holds (-4096) 4096 256 (a.val[3 * i + j]!).val (A i j))
    (hs : ∀ j < 3, Congr (s.val[j]!).val (S j)) (he : VHolds (-23594) 23594 3 e.val E) :
    mid.mlkem.CoeffsMNtt.mul_add mat vec (a, ()) (s, ()) (e, ()) ⦃ r =>
      VHolds 0 3328 3 r.1.val (fun i => dot3 (A i) S + E i) ⦄ := by
  unfold mid.mlkem.CoeffsMNtt.mul_add mid.mlkem.Coeffs.Insts.CoreCloneClone.clone
  simp only [h1.clone, hm.as_ref, h1.as_mut, zero1_eq, bind_ok]
  refine spec_bind_ok (e, ()) _ _ ?_
  refine WP.spec_bind (mul_cache_spec vec h1 h2 s S hs) ?_
  rintro ⟨sc, ⟨⟩⟩ hsc
  apply spec_bind_ok
  step as ⟨sl, hsl⟩
  have hal : sl.length = 9 := array_length sl a hsl
  have hk : mid.mlkem.rank (Slice.len sl) = ok 3#usize := by
    unfold mid.mlkem.rank
    rw [Slice.len_val, hal]
    rfl
  rw [hk]
  apply spec_bind_ok
  step as ⟨rows, back, hrv, hrl, hback⟩
  refine WP.spec_bind (mul_add_loop_spec vec h1 h2 mat sl hal s sc A S E (by rw [hsl]; exact hA) hs hsc rows hrl
      (by rw [hrv]; exact he) _ { start := 0#usize, «end» := 3#usize } rfl rfl) ?_
  rintro rows1 ⟨hl1, hq1⟩
  apply WP.spec_mono (reduce_in_place_spec _ h1 _ (back rows1) (fun i => dot3 (A i) S + E i)
    (fun i hi => by rw [hback _ hl1]; exact hq1 i hi))
  intro r hr
  exact hr

/-! ## The transpose -/

/-- The position whose polynomial lands at `p` of a 3 by 3 matrix once the
entries in its first `i` rows and columns are transposed, and those of row
`i` and column `i` before the `j`th. -/
def trPos (i j p : ℕ) : ℕ :=
  if (p / 3 < i ∧ p % 3 < i) ∨ (p / 3 = i ∧ p % 3 < j) ∨ (p % 3 = i ∧ p / 3 < j) then 3 * (p % 3) + p / 3
  else p

theorem trPos_swap (i j p : ℕ) (hj : j < i) (hi : i < 3) (hp : p < 9) :
    trPos i (j + 1) p =
      if p = 3 * i + j then trPos i j (3 * j + i) else if p = 3 * j + i then trPos i j (3 * i + j)
      else trPos i j p := by
  unfold trPos
  split_ifs <;> omega

theorem trPos_next (i p : ℕ) (hp : p < 9) : trPos i i p = trPos (i + 1) 0 p := by
  unfold trPos
  split_ifs <;> omega

/-- The inner loop of `Coeffs::transpose`: row `i`'s entries before the
diagonal trade places with column `i`'s. -/
theorem transpose_inner_spec (orig : List Poly) (i : Usize) (hi : i.val < 3) (polys : Slice Poly)
    (hl : polys.length = 9) (h : ∀ p < 9, polys.val[p]! = orig[trPos i.val 0 p]!)
    (it : core.ops.range.Range Usize) (hs : it.start.val = 0) (he : it.end.val = i.val) :
    mid.mlkem.CoeffsMNtt.transpose_loop0_loop0 it polys 3#usize i ⦃ r =>
      r.length = 9 ∧ ∀ p < 9, r.val[p]! = orig[trPos i.val i.val p]! ⦄ := by
  unfold mid.mlkem.CoeffsMNtt.transpose_loop0_loop0
  apply range_loop i.val (fun j (s : Slice Poly) => s.length = 9 ∧ ∀ p < 9, s.val[p]! = orig[trPos i.val j p]!)
    _ ?_ it polys he (by omega) (by rw [hs]; exact ⟨hl, h⟩)
  intro it s he hs' ⟨hsl, hinv⟩
  simp only
  unfold mid.mlkem.CoeffsMNtt.transpose_loop0_loop0.body
  step as ⟨o', it1, ho, he1⟩
  split_ifs at ho with hlt
  · obtain ⟨rfl, hst⟩ := ho
    simp only
    step as ⟨i1, hi1⟩
    step as ⟨i2, hi2⟩
    step as ⟨i3, hi3⟩
    step as ⟨i4, hi4⟩
    have ha : i2.val = 3 * i.val + it.start.val := by scalar_tac
    have hb : i4.val = 3 * it.start.val + i.val := by scalar_tac
    step with core.slice.Slice.swap_spec s i2 i4 (by scalar_tac) (by scalar_tac) as ⟨s', hl', hsa, hsb, hso⟩
    refine ⟨by rw [he1]; exact he, hst, by omega, by rw [hl']; exact hsl, fun p hp => ?_⟩
    rw [hst, trPos_swap i.val it.start.val p (by omega) hi hp]
    by_cases hpa : p = 3 * i.val + it.start.val
    · rw [MlKemPoly.ite_pos hpa, ← hinv _ (by omega), ← hb, ← hsa, hpa, ← ha]
    · rw [MlKemPoly.ite_neg hpa]
      by_cases hpb : p = 3 * it.start.val + i.val
      · rw [MlKemPoly.ite_pos hpb, ← hinv _ (by omega), ← ha, ← hsb, hpb, ← hb]
      · rw [MlKemPoly.ite_neg hpb, hso p (by omega) (by omega), hinv p hp]
  · obtain ⟨rfl, hst⟩ := ho
    apply (WP.spec_ok _).2
    have : it.start.val = i.val := by omega
    rw [this] at hinv
    exact ⟨hsl, hinv⟩

/-- `Coeffs::transpose` of a 3 by 3 matrix: the polynomial at row `i` and
column `j` moves to row `j` and column `i`. -/
theorem transpose_spec (mat : mid.mlkem.FixedArray (Std.Array Poly 9#usize) Poly) (hm : IsArray mat)
    (a : Std.Array Poly 9#usize) :
    mid.mlkem.CoeffsMNtt.transpose mat (a, ()) ⦃ r =>
      ∀ i < 3, ∀ j < 3, r.1.val[3 * i + j]! = a.val[3 * j + i]! ⦄ := by
  unfold mid.mlkem.CoeffsMNtt.transpose
  simp only [hm.as_mut]
  step as ⟨polys, back, hpv, hpl, hback⟩
  have hk : mid.mlkem.rank (Slice.len polys) = ok 3#usize := by
    unfold mid.mlkem.rank
    rw [Slice.len_val, hpl]
    rfl
  rw [hk]
  apply spec_bind_ok
  unfold mid.mlkem.CoeffsMNtt.transpose_loop0
  refine WP.spec_bind (range_loop 3 (fun i (s : Slice Poly) => s.length = 9 ∧
      ∀ p < 9, s.val[p]! = a.val[trPos i 0 p]!) _ ?_ { start := 0#usize, «end» := 3#usize } polys rfl
      (by simp) ⟨hpl, fun p hp => by rw [hpv]; simp [trPos]⟩) ?_
  · intro it s he hs' ⟨hsl, hinv⟩
    simp only
    unfold mid.mlkem.CoeffsMNtt.transpose_loop0.body
    step as ⟨o', it1, ho, he1⟩
    split_ifs at ho with hlt
    · obtain ⟨rfl, hst⟩ := ho
      simp only
      step with transpose_inner_spec a.val it.start (by omega) s hsl hinv { start := 0#usize, «end» := it.start }
          rfl rfl as ⟨s1, hl1, hq1⟩
      refine ⟨by rw [he1]; exact he, hst, by omega, hl1, fun p hp => ?_⟩
      rw [hq1 p hp, trPos_next _ _ hp, hst]
    · obtain ⟨rfl, hst⟩ := ho
      apply (WP.spec_ok _).2
      have : it.start.val = 3 := by omega
      rw [this] at hinv
      exact ⟨hsl, hinv⟩
  · rintro r ⟨hl, hr⟩
    apply (WP.spec_ok _).2
    intro i hi j hj
    rw [hback _ hl, hr _ (by omega)]
    congr 1
    unfold trPos
    split_ifs <;> omega

/-! ## FIPS 203's `K-PKE.KeyGen`

`K-PKE.KeyGen` for ML-KEM-768, unrolled to the bytes of its keys, as
`encrypt_eq` unrolls `K-PKE.Encrypt`. -/

open scoped Spec.Notations

/-- `K-PKE.KeyGen`'s `(ρ, σ)`: `G(d ‖ k)`. -/
abbrev kgG (d : 𝔹 32) : 𝔹 32 × 𝔹 32 := G (d ‖ #v[((k .ML_KEM_768 : ℕ) : Byte)])

/-- `K-PKE.KeyGen`'s `ŝ`, polynomial `j`, from `σ`. -/
def kgS (σ : 𝔹 32) (j : ℕ) : Polynomial := NTT (SamplePolyCBD (PRF (η₁ .ML_KEM_768) σ (j : Byte)))

/-- `K-PKE.KeyGen`'s `t̂`, polynomial `i`, from `ρ` and `σ`: row `i` of `Â`
times `ŝ`, plus `ê`'s polynomial `i`. -/
def kgT (ρ σ : 𝔹 32) (i : ℕ) : Polynomial :=
  dot3 (fun j => SampleNTT (ρ ‖ #v[(j : Byte)] ‖ #v[(i : Byte)])) (kgS σ) +
    NTT (SamplePolyCBD (PRF (η₁ .ML_KEM_768) σ ((3 + i : ℕ) : Byte)))

/-- The bytes of `ByteEncode_12` of three polynomials. -/
def enc3 (F : ℕ → Polynomial) : List Byte :=
  (ByteEncode 12 (F 0)).toList ++ (ByteEncode 12 (F 1)).toList ++ (ByteEncode 12 (F 2)).toList

theorem encode12_3 (v : PolyVector q (k .ML_KEM_768)) :
    (PolyVector.ByteEncode 12 v (by omega)).toList =
      (ByteEncode 12 v[0] (by omega)).toList ++ (ByteEncode 12 v[1] (by omega)).toList ++
        (ByteEncode 12 v[2] (by omega)).toList := by
  have h := toList3 (v.map (fun x => ByteEncode 12 x (by omega)))
  unfold PolyVector.ByteEncode
  simp only [Vector.toList, Vector.flatten, Array.toList_flatten, Array.toList_map, List.map_map] at h ⊢
  rw [h]
  simp [Vector.getElem_map]

/-- `K-PKE.KeyGen` for ML-KEM-768: `ekPKE` is `ByteEncode_12(t̂) ‖ ρ`, and
`dkPKE` is `ByteEncode_12(ŝ)`. -/
theorem keygen_eq (d : 𝔹 32) :
    (K_PKE.KeyGen .ML_KEM_768 d).1.toList = enc3 (kgT (kgG d).1 (kgG d).2) ++ (kgG d).1.toList ∧
      (K_PKE.KeyGen .ML_KEM_768 d).2.toList = enc3 (kgS (kgG d).2) := by
  unfold K_PKE.KeyGen
  simp only [update_eq, set_eq]
  simp only [Aeneas.SRRange.forIn'_eq_forIn'_range', Aeneas.SRRange.size, size768, List.range'_succ,
    List.range'_zero, List.forIn'_cons, List.forIn'_nil, pure_bind, Nat.zero_add, Nat.reduceAdd]
  simp only [Id.run_pure]
  simp only [Vector.toList_cast, append_eq, Vector.toList_append, encode12_3]
  refine ⟨?_, ?_⟩
  · simp (disch := decide) only [add_getElem, ntt_getElem]
    rw [hmul_eq, mulVec3 _ _ 0 (by decide), mulVec3 _ _ 1 (by decide), mulVec3 _ _ 2 (by decide)]
    simp (disch := decide) only [upd_same, upd_ne, Vector.getElem_setIfInBounds, ntt_getElem]
    simp only [Nat.reduceEqDiff, ↓reduceIte]
    unfold enc3 kgT kgS dot3
    rfl
  · simp (disch := decide) only [ntt_getElem, Vector.getElem_setIfInBounds]
    simp only [Nat.reduceEqDiff, ↓reduceIte]
    unfold enc3 kgS
    rfl

end MlKemKeygen

end rind.aarch64
