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

/-! ## SHA-3 as FIPS 203's `H` and `G` -/

theorem sha3_256_congr {n n' : ℕ} (B : 𝔹 n) (C : 𝔹 n') (h : B.toList = C.toList) :
    Spec.SHA3.sha3_256 B = Spec.SHA3.sha3_256 C := by
  have hn : n = n' := by rw [← B.length_toList, ← C.length_toList, h]
  subst hn
  rw [Vector.toList_inj.mp h]

theorem sha3_512_congr {n n' : ℕ} (B : 𝔹 n) (C : 𝔹 n') (h : B.toList = C.toList) :
    Spec.SHA3.sha3_512 B = Spec.SHA3.sha3_512 C := by
  have hn : n = n' := by rw [← B.length_toList, ← C.length_toList, h]
  subst hn
  rw [Vector.toList_inj.mp h]

/-- Bytes that are SHA3-256's of `M` are `H(M)`. -/
theorem h_eq {n : ℕ} (x : List U8) (hl : x.length = 32) (M : 𝔹 n) (hx : bv x = sha3_256 M.toList) :
    toVec 32 x hl = H M := by
  apply Vector.toList_inj.mp
  rw [toVec_toList, hx, sha3_256_eq]
  unfold H
  rw [sha3_256_congr (toB M.toList) M (by simp [toB])]

/-- Bytes that are SHA3-512's of `M` are FIPS 202's. -/
theorem sha512_toVec {n : ℕ} (x : List U8) (hl : x.length = 64) (M : 𝔹 n) (hx : bv x = sha3_512 M.toList) :
    toVec 64 x hl = Spec.SHA3.sha3_512 M := by
  apply Vector.toList_inj.mp
  rw [toVec_toList, hx, sha3_512_eq, sha3_512_congr (toB M.toList) M (by simp [toB])]

/-- The halves of SHA3-512's bytes on `M` are `G(M)`. -/
theorem g_eq {n : ℕ} (x : List U8) (hl : x.length = 64) (M : 𝔹 n) (hx : bv x = sha3_512 M.toList) :
    toVec 32 (sub x 0 32) (sub_length _ _ _ (by omega)) = (G M).1 ∧
      toVec 32 (sub x 32 32) (sub_length _ _ _ (by omega)) = (G M).2 := by
  unfold G
  rw [← sha512_toVec x hl M hx]
  refine ⟨?_, ?_⟩ <;> simp [slice_toVec]

/-! ## `EncapKey::new` -/

/-- `EncapKey::new` keeps the key's bytes and decoded form, and hashes the
bytes with SHA3-256. -/
theorem encap_key_new_spec (h : RunsSha3) {X : Type}
    (P : mid.mlkem.Params X Vec Mat EkBytes CtBytes DkBytes Cache Enc) (hP : Is768 P) (bytes : EkBytes)
    (d : mid.mlkem.Decoded X Vec Mat EkBytes CtBytes DkBytes Cache Enc) :
    mid.mlkem.EncapKey.new P bytes d ⦃ ek =>
      ek.bytes = bytes ∧ bv ek.h_ek.val = sha3_256 (bv bytes.val) ∧ ek.hashed = true ∧ ek.decoded = some d ⦄ := by
  unfold mid.mlkem.EncapKey.new
  simp only [hP.ek.as_ref]
  step with sha3ctx_new_spec 136#usize 32#usize (by decide) (by decide) as ⟨c, hc⟩
  step as ⟨s, hs⟩
  step with sha3ctx_update_spec h (by decide) c [] hc s as ⟨c1, hc1⟩
  step with sha3ctx_finish_spec h (by decide) c1 _ hc1 as ⟨a, ha⟩
  rw [ha, List.nil_append, hs]
  rfl

/-! ## `Coeffs::sample`, untransposed -/

/-- Polynomial `3i + j` of ML-KEM-768's matrix is SHAKE128's on `ρ ‖ j ‖ i`. -/
theorem matMsg_untransposed (rho : List Byte) (i j : ℕ) (hj : j < 3) :
    matMsg rho false 3 (3 * i + j) = rho ++ [(j : Byte), (i : Byte)] := by
  unfold matMsg
  rw [show (3 * i + j) / 3 = i by omega, show (3 * i + j) % 3 = j by omega]
  rfl

/-- `Coeffs::sample` of ML-KEM-768's matrix: polynomial `3i + j` is FIPS 203's
`SampleNTT(ρ ‖ j ‖ i)`, the matrix's entry in row `i` and column `j`, given
that `SampleNTT` finishes on each. -/
theorem sample_spec (h : RunsSha3) (inst : mid.mlkem.FixedArray Mat Poly) (hi : IsArray inst)
    (rho : Std.Array U8 32#usize) (ρ : 𝔹 32) (hρ : bv rho.val = ρ.toList)
    (hH : ∀ i : ℕ, i < 3 → ∀ j : ℕ, j < 3 → Halts (ρ ‖ #v[(j : Byte)] ‖ #v[(i : Byte)]).toList) :
    mid.mlkem.CoeffsMNtt.sample inst rho false ⦃ r =>
      ∀ i : ℕ, i < 3 → ∀ j : ℕ, j < 3 →
        Holds 0 3328 256 (r.1.val[3 * i + j]!).val (SampleNTT (ρ ‖ #v[(j : Byte)] ‖ #v[(i : Byte)])) ⦄ := by
  have hmsg (i j : ℕ) (hj : j < 3) :
      matMsg (bv rho.val) false 3 (3 * i + j) = (ρ ‖ #v[(j : Byte)] ‖ #v[(i : Byte)]).toList := by
    rw [matMsg_untransposed _ _ _ hj, hρ, vappend_toList, vappend_toList, List.append_assoc]
    rfl
  apply WP.spec_mono (coeffs_sample_spec h inst hi rho false (fun p hp => by
    have := hH (p / 3) (by omega) (p % 3) (by omega)
    rwa [← hmsg _ _ (by omega), show 3 * (p / 3) + p % 3 = p by omega] at this))
  intro r hr i hi3 j hj3 c hc
  have hs := hr (3 * i + j) (by omega) c hc
  rw [hmsg _ _ hj3] at hs
  have hlt := sampled_lt _ c hc (hH i hi3 j hj3)
  refine ⟨by rw [hs]; omega, by rw [hs]; omega, ?_⟩
  rw [hs, getElem!_pos (SampleNTT _) c hc, sampleNTT_sampled _ (hH i hi3 j hj3) c hc]
  simp

/-! ## `K-PKE.KeyGen` -/

theorem try_copy_eq {T : Type} (N : Usize) (inst : core.marker.Copy T) (s : Slice T) (h : s.length = N.val) :
    core.array.TryFromArrayCopySlice.try_from N inst s = ok (.Ok (Std.Array.from s.val h)) := by
  unfold core.array.TryFromArrayCopySlice.try_from
  rw [dite_true' h]

theorem flat3 (l : List (Std.Array U8 384#usize)) (h : l.length = 3) :
    l.flatMap (·.val) = (l[0]!).val ++ (l[1]!).val ++ (l[2]!).val := by
  rcases l with _ | ⟨a, _ | ⟨b, _ | ⟨c, _ | ⟨d, l⟩⟩⟩⟩ <;> simp at h
  simp

/-- `ByteEncode_12` of three polynomials, as the bytes of three encoded arrays. -/
theorem bv_flat3 (l : List (Std.Array U8 384#usize)) (h : l.length = 3) (F : ℕ → Polynomial)
    (hF : ∀ j < 3, toVec (32 * 12) (l[j]!).val (l[j]!).property = ByteEncode 12 (F j)) :
    bv (l.flatMap (·.val)) = enc3 F := by
  rw [flat3 l h]
  simp only [bv, List.map_append]
  unfold enc3
  rw [← hF 0 (by omega), ← hF 1 (by omega), ← hF 2 (by omega), toVec_toList, toVec_toList, toVec_toList]
  rfl

/-- The SHA3-512 input of `K-PKE.KeyGen`'s `G`: `d ‖ k`. -/
theorem g_input (d : Std.Array U8 32#usize) (x : U8) (hx : x.val = 3) :
    bv (d.val ++ [x]) = (toVec 32 d.val d.property ‖ #v[((k .ML_KEM_768 : ℕ) : Byte)]).toList := by
  rw [vappend_toList, toVec_toList]
  simp only [bv, List.map_append, List.map_cons, List.map_nil]
  rw [u8_bv x 3 hx]
  rfl

/-- `kpke_keygen` writes `ByteEncode_12(t̂) ‖ ρ` as the encapsulation key, with
its hash and decoded form, and `ByteEncode_12(ŝ)` as the decryption key. -/
theorem kpke_keygen_spec (h : RunsSha3) {X : Type}
    (P : mid.mlkem.Params X Vec Mat EkBytes CtBytes DkBytes Cache Enc) (hP : Is768 P) (d : Std.Array U8 32#usize)
    (hH : ∀ i : ℕ, i < 3 → ∀ j : ℕ, j < 3 →
      Halts ((kgG (toVec 32 d.val d.property)).1 ‖ #v[(j : Byte)] ‖ #v[(i : Byte)]).toList) :
    mid.mlkem.DecapKey.kpke_keygen P d ⦃ r =>
      bv r.1.bytes.val = enc3 (kgT (kgG (toVec 32 d.val d.property)).1 (kgG (toVec 32 d.val d.property)).2) ++
          (kgG (toVec 32 d.val d.property)).1.toList ∧
        bv r.1.h_ek.val = sha3_256 (bv r.1.bytes.val) ∧ r.1.hashed = true ∧
        (∃ D, r.1.decoded = some D ∧
          DecodedHolds D (kgT (kgG (toVec 32 d.val d.property)).1 (kgG (toVec 32 d.val d.property)).2)
            (fun i j => SampleNTT ((kgG (toVec 32 d.val d.property)).1 ‖ #v[(i : Byte)] ‖ #v[(j : Byte)]))) ∧
        bv (r.2.val.flatMap (·.val)) = enc3 (kgS (kgG (toVec 32 d.val d.property)).2) ⦄ := by
  unfold mid.mlkem.DecapKey.kpke_keygen
  simp only [hP.K, hP.ETA1, zero_eq _ hP.vec, hP.vec.as_mut, hP.ek.filled, hP.ek.as_mut, hP.enc.as_ref, bind_ok]
  -- `(ρ, σ) ← G(d ‖ k)`.
  step with sha3ctx_new_spec 72#usize 64#usize (by decide) (by decide) as ⟨g, hg⟩
  step as ⟨s, hs⟩
  step with sha3ctx_update_spec h (by decide) g [] hg s as ⟨g1, hg1⟩
  step as ⟨i1, hi1⟩
  step as ⟨s1, hs1⟩
  step with sha3ctx_update_spec h (by decide) g1 _ hg1 s1 as ⟨g2, hg2⟩
  step with sha3ctx_finish_spec h (by decide) g2 _ hg2 as ⟨g3, hg3⟩
  step as ⟨s2, hs2⟩
  step as ⟨rho, sigma, hrl, hsl, hrv, hsv⟩
  have hg3l : g3.val.length = 64 := g3.property
  have hs2v : s2.val = g3.val := by rw [hs2, Std.Array.val_to_slice]
  have hsl' : sigma.length = 32 := by
    rw [hsl]; show s2.val.length - 32 = 32; rw [hs2v, hg3l]
  rw [try_copy_eq 32#usize _ rho hrl, try_copy_eq 32#usize _ sigma hsl']
  simp only [core.result.Result.unwrap, low.ct.into_public, bind_ok]
  have hi1v : i1.val = 3 := by rw [hi1, UScalar.cast_val_eq]; simp
  have hM : bv ([] ++ s.val ++ s1.val) = (toVec 32 d.val d.property ‖ #v[((k .ML_KEM_768 : ℕ) : Byte)]).toList := by
    rw [List.nil_append, hs, hs1, Std.Array.val_to_slice, Std.Array.val_to_slice]
    exact g_input d i1 hi1v
  rw [hM] at hg3
  obtain ⟨hρ, hσ⟩ := g_eq g3.val hg3l _ hg3
  set ρ := (kgG (toVec 32 d.val d.property)).1 with hρdef
  set σ := (kgG (toVec 32 d.val d.property)).2 with hσdef
  have hrho : bv (Std.Array.from (n := 32#usize) rho.val hrl).val = ρ.toList := by
    rw [Std.Array.from_val, ← hρ, toVec_toList, hrv, hs2v]
    rfl
  have hsig : toVec 32 (Std.Array.from (n := 32#usize) sigma.val hsl').val
      (Std.Array.property _) = σ := by
    rw [← hσ]
    apply toVec_congr
    rw [Std.Array.from_val, hsv, hs2v]
    simp [sub, List.take_of_length_le, hg3l]
  -- `Â`.
  step with sample_spec h P.FixedArraySelf_MatrixArrayI16256Inst hP.mat _ ρ hrho hH as ⟨a_hat, ha_hat⟩
  obtain ⟨ahat, ⟨⟩⟩ := a_hat
  -- `s` and `e`.
  set sg := Std.Array.from (n := 32#usize) sigma.val hsl' with hsg
  have hcbd : ∀ N : ℕ, cbd2 sg N = SamplePolyCBD (η := η₁ .ML_KEM_768) (PRF (η₁ .ML_KEM_768) σ (N : Byte)) := by
    intro N
    unfold cbd2
    rw [hsig]
    rfl
  apply spec_bind_ok
  step as ⟨s4, back, hs4v, hs4l, hback⟩
  step as ⟨s5, back1, hs5v, hs5l, hback1⟩
  refine WP.spec_bind (sample_poly_cbd_spec h sg 0#u8 s4 s5 (by rw [hs4l, hs5l]; scalar_tac)) ?_
  rintro ⟨s6, s7⟩ ⟨hl6, hl7, hq⟩
  have h0 : (0#u8).val = 0 := rfl
  have hS : VHolds (-2) 2 3 (back s6).val (cbd2 sg) := by
    intro j hj
    rw [hback s6 (by rw [hl6, hs4l])]
    have := hq j (by rw [hs4l, hs5l]; scalar_tac)
    unfold get2 at this
    rw [ite_eq_left (by rw [hl6, hs4l]; scalar_tac), h0, Nat.zero_add] at this
    exact this
  have hE : VHolds (-2) 2 3 (back1 s7).val (fun j => cbd2 sg (3 + j)) := by
    intro j hj
    rw [hback1 s7 (by rw [hl7, hs5l])]
    have := hq (3 + j) (by rw [hs4l, hs5l]; scalar_tac)
    unfold get2 at this
    rw [ite_eq_right (by rw [hl6, hs4l]; scalar_tac), hl6, hs4l, h0, Nat.zero_add] at this
    simpa [show (3#usize).val = 3 from rfl] using this
  -- `ŝ`, `ê`, and `t̂`.
  refine WP.spec_bind (ntt_spec _ hP.vec (back s6) (cbd2 sg)
    (fun j hj => Holds.mono (hS j hj) (by norm_num) (by norm_num))) ?_
  rintro ⟨sh, ⟨⟩⟩ hsh
  refine WP.spec_bind (ntt_spec _ hP.vec (back1 s7) (fun j => cbd2 sg (3 + j))
    (fun j hj => Holds.mono (hE j hj) (by norm_num) (by norm_num))) ?_
  rintro ⟨eh, ⟨⟩⟩ heh
  refine WP.spec_bind (mul_add_spec P.VectorInst hP.vec hP.cache P.FixedArraySelf_MatrixArrayI16256Inst hP.mat
    ahat sh eh (fun i j => SampleNTT (ρ ‖ #v[(j : Byte)] ‖ #v[(i : Byte)])) (fun j => NTT (cbd2 sg j))
    (fun i => NTT (cbd2 sg (3 + i)))
    (fun i hi j hj => Holds.mono (ha_hat i hi j hj) (by norm_num) (by norm_num))
    (fun j hj => Holds.congr (hsh j hj)) heh) ?_
  rintro ⟨th, ⟨⟩⟩ hth
  have hT : (fun i : ℕ => dot3 (fun j : ℕ => SampleNTT (ρ ‖ #v[(j : Byte)] ‖ #v[(i : Byte)])) (fun j => NTT (cbd2 sg j)) +
      NTT (cbd2 sg (3 + i))) = kgT ρ σ := by
    funext i
    unfold kgT kgS
    simp only [hcbd]
  rw [hT] at hth
  have hSv : (fun j : ℕ => NTT (cbd2 sg j)) = kgS σ := by
    funext j
    unfold kgS
    rw [hcbd]
  -- The encapsulation key's bytes.
  step as ⟨s8, back2, hs8v, hs8l, hback2⟩
  step as ⟨i3, hi3⟩
  step as ⟨tb, rb, sback, hr1, hr2, hr3, hr4, hr5⟩
  refine WP.spec_bind (to_bytes_spec P.VectorInst hP.vec hP.enc th (kgT ρ σ) hth) ?_
  intro t6 ht6
  step as ⟨s9, hs9⟩
  have hs9l : s9.length = 3 := array_length s9 t6 hs9
  step with as_flattened_spec s9 (by rw [hs9l]; scalar_tac) as ⟨s10, hs10⟩
  have hfl : (t6.val.flatMap (·.val)).length = 1152 := by rw [flat_length, t6.property]; rfl
  have hs10l : s10.length = 1152 := by show s10.val.length = _; rw [hs10, hs9, hfl]
  have hs8l' : s8.length = 1184 := by rw [hs8l]
  have hi3v : i3.val = 1152 := by rw [hi3]
  step as ⟨tb1, htb1⟩
  step as ⟨s11, hs11⟩
  step as ⟨rb1, hrb1⟩
  step with transpose_spec P.FixedArraySelf_MatrixArrayI16256Inst hP.mat ahat as ⟨c, hc⟩
  step with encap_key_new_spec h P hP _ _ as ⟨ek, hek1, hek2, hek3, hek4⟩
  refine WP.spec_bind (reduce_in_place_spec _ hP.vec _ sh (kgS σ) (fun j hj => by
    rw [← hSv]; exact Holds.congr (hsh j hj))) ?_
  rintro ⟨sh1, ⟨⟩⟩ hsh1
  refine WP.spec_bind (to_bytes_spec P.VectorInst hP.vec hP.enc sh1 (kgS σ) hsh1) ?_
  intro dk hdk
  apply (WP.spec_ok _).2
  have hbytes : (back2 (sback (tb1, rb1))).val = t6.val.flatMap (·.val) ++ rho.val := by
    have hl1 : tb1.length = i3.val := by rw [htb1, hs10l, hi3v]
    have hl2 : rb1.length = s8.length - i3.val := by
      rw [hrb1, hs8l', hi3v, hs11]
      show (Std.Array.from (n := 32#usize) rho.val hrl).to_slice.val.length = _
      rw [Std.Array.val_to_slice, Std.Array.from_val]
      exact hrl
    obtain ⟨hv, hl⟩ := hr5 tb1 rb1 hl1 hl2
    rw [hback2 _ (by rw [hl, hs8l']), hv, htb1, hrb1, hs10, hs9, hs11, Std.Array.val_to_slice,
      Std.Array.from_val]
  refine ⟨?_, ?_, hek3, ⟨_, hek4, ⟨?_, ?_⟩⟩, ?_⟩
  · rw [hek1, hbytes]
    simp only [bv, List.map_append]
    rw [← bv, ← bv, bv_flat3 _ t6.property _ ht6, ← hrho, Std.Array.from_val]
  · rw [hek2, hek1]
  · exact hth
  · intro i hi j hj
    simp only
    rw [hc i hi j hj]
    exact ha_hat j hj i hi
  · exact bv_flat3 _ dk.property _ hdk


/-- `ByteDecode_12` undoes `ByteEncode_12`. -/
theorem byteDecode_byteEncode12 (F : Polynomial) :
    (ByteDecode (d := 12) (ByteEncode 12 F (by omega)) (by omega) : Polynomial) = F := by
  apply Vector.ext
  intro i hi
  rw [← getElem!_pos _ i hi, ← getElem!_pos F i hi, ByteDecode_get _ _ i hi]
  have hb : ∀ j : Fin 12, bit (ByteEncode 12 F (by omega)) (i * 12 + j.val) = (F[i]!).val.testBit j.val := by
    intro j
    rw [ByteEncode_bit (d := 12) F _ _ (by omega), show (i * 12 + j.val) / 12 = i by omega,
      show (i * 12 + j.val) % 12 = j.val by omega]
  simp only [hb]
  have hlt : (F[i]!).val < 3329 := ZMod.val_lt (F[i]!)
  rw [← mod_two_pow_eq_sum, Nat.mod_eq_of_lt (by omega)]
  exact ZMod.natCast_zmod_val (F[i]!)

/-- 384 bytes from `384 j` of `ByteEncode_12` of three polynomials, then more
bytes, are polynomial `j`'s encoding. -/
theorem sub_enc3 (l : List U8) (T : ℕ → Polynomial) (ρ : List Byte) (h : bv l = enc3 T ++ ρ) (j : ℕ)
    (hj : j < 3) : bv (sub l (384 * j) 384) = (ByteEncode 12 (T j)).toList := by
  have hb : bv (sub l (384 * j) 384) = ((bv l).drop (384 * j)).take 384 := by simp [bv, sub, List.map_take, List.map_drop]
  rw [hb, h]
  unfold enc3
  have h0 := (ByteEncode 12 (T 0) (by omega)).length_toList
  have h1 := (ByteEncode 12 (T 1) (by omega)).length_toList
  have h2 := (ByteEncode 12 (T 2) (by omega)).length_toList
  interval_cases j <;> simp [List.drop_append, h0, h1, h2]

/-- An encapsulation key's polynomial `j` of `t̂`, as `K-PKE.Encrypt` decodes it,
is `T j` when the key is `ByteEncode_12(t̂) ‖ ρ` of coefficients in `[0, q)`. -/
theorem decode_enc3 (ek : EkBytes) (T : ℕ → Polynomial) (ρ : List Byte) (h : bv ek.val = enc3 T ++ ρ) (j : ℕ)
    (hj : j < 3) :
    (PolyVector.ByteDecode (k := k .ML_KEM_768) 12 (slice (toVec 1184 ek.val ek.property) 0 1152))[j]! = T j := by
  have hek : ek.val.length = 1184 := ek.property
  have hl : (sub ek.val (384 * j) 384).length = (384#usize).val := sub_length _ _ _ (by omega)
  rw [← decode_t_hat ek (Std.Array.from _ hl) j hj (by rw [Std.Array.from_val])]
  unfold decode12
  rw [show toVec (32 * 12) (Std.Array.from (sub ek.val (384 * j) 384) hl).val (Std.Array.property _) =
      ByteEncode 12 (T j) (by omega) from Vector.toList_inj.mp (by rw [toVec_toList, Std.Array.from_val,
        sub_enc3 _ T ρ h j hj])]
  exact byteDecode_byteEncode12 (T j)

/-- The 32 bytes after an encapsulation key's encoded `t̂` are `ρ`. -/
theorem rho_enc3 (ek : EkBytes) (T : ℕ → Polynomial) (ρ : 𝔹 32) (h : bv ek.val = enc3 T ++ ρ.toList) :
    slice (toVec 1184 ek.val ek.property) 1152 32 = ρ := by
  have hek : ek.val.length = 1184 := ek.property
  rw [slice_toVec]
  apply Vector.toList_inj.mp
  rw [toVec_toList]
  have hb : bv (sub ek.val 1152 32) = ((bv ek.val).drop 1152).take 32 := by simp [bv, sub, List.map_take, List.map_drop]
  rw [hb, h]
  unfold enc3
  have h0 := (ByteEncode 12 (T 0) (by omega)).length_toList
  have h1 := (ByteEncode 12 (T 1) (by omega)).length_toList
  have h2 := (ByteEncode 12 (T 2) (by omega)).length_toList
  simp [List.drop_append, h0, h1, h2]

/-- The decoded form of the encapsulation key `E`: `t̂`'s polynomials and the
transposed matrix, as `K-PKE.Encrypt` reads them from `E`, which
`kpke_encrypt_fips` takes. -/
abbrev EkDecoded {X : Type} (D : mid.mlkem.Decoded X Vec Mat EkBytes CtBytes DkBytes Cache Enc) (E : 𝔹 1184) :
    Prop :=
  DecodedHolds D (fun j => (PolyVector.ByteDecode (k := k .ML_KEM_768) 12 (slice E 0 1152))[j]!)
    (fun i j => SampleNTT (slice E 1152 32 ‖ #v[(i : Byte)] ‖ #v[(j : Byte)]))

/-- The encapsulation key `ek` holds `E`: its bytes, their hash `H(E)`, and
its decoded form. -/
structure EkHolds {X : Type} (ek : mid.mlkem.EncapKey X Vec Mat EkBytes CtBytes DkBytes Cache Enc) (E : 𝔹 1184) :
    Prop where
  bytes : toVec 1184 ek.bytes.val ek.bytes.property = E
  h_ek : toVec 32 ek.h_ek.val ek.h_ek.property = H E
  hashed : ek.hashed = true
  decoded : ∃ D, ek.decoded = some D ∧ EkDecoded D E

/-- `kpke_keygen` is FIPS 203's `K-PKE.KeyGen` for ML-KEM-768, and the
encapsulation key it returns holds its encoding, given that `SampleNTT`
finishes on each of the matrix's inputs. -/
theorem kpke_keygen_fips (h : RunsSha3) {X : Type}
    (P : mid.mlkem.Params X Vec Mat EkBytes CtBytes DkBytes Cache Enc) (hP : Is768 P) (d : Std.Array U8 32#usize)
    (hH : ∀ i : ℕ, i < 3 → ∀ j : ℕ, j < 3 →
      Halts ((kgG (toVec 32 d.val d.property)).1 ‖ #v[(j : Byte)] ‖ #v[(i : Byte)]).toList) :
    mid.mlkem.DecapKey.kpke_keygen P d ⦃ r =>
      toVec 1184 r.1.bytes.val r.1.bytes.property = (K_PKE.KeyGen .ML_KEM_768 (toVec 32 d.val d.property)).1 ∧
        dkPke r.2 = (K_PKE.KeyGen .ML_KEM_768 (toVec 32 d.val d.property)).2 ∧
        EkHolds r.1 (toVec 1184 r.1.bytes.val r.1.bytes.property) ⦄ := by
  apply WP.spec_mono (kpke_keygen_spec h P hP d hH)
  rintro ⟨ek, dk⟩ ⟨hb, hh, hhs, ⟨D, hD, hDT, hDA⟩, hdk⟩
  obtain ⟨heq1, heq2⟩ := keygen_eq (toVec 32 d.val d.property)
  refine ⟨Vector.toList_inj.mp (by rw [toVec_toList, hb, heq1]), Vector.toList_inj.mp (by
    unfold dkPke; rw [toVec_toList, hdk, heq2]), rfl, h_eq _ _ _ (by rw [toVec_toList]; exact hh), hhs,
    D, hD, ?_, ?_⟩
  · intro j hj
    simp only
    rw [decode_enc3 ek.bytes _ _ hb j hj]
    exact hDT j hj
  · intro i hi j hj
    simp only
    rw [rho_enc3 ek.bytes _ _ hb]
    exact hDA i hi j hj

end MlKemKeygen

end rind.aarch64
