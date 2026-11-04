import Rind.Aarch64.S2nBignum
import Rind.Bytes
import Mathlib.Tactic.LinearCombination
open Aeneas Aeneas.Std Result rind.spec

/-!
# aarch64 P-256 ECDH, proven from rind's agreement API to s2n-bignum's contracts
-/

namespace rind.aarch64

/-! ## Byte and limb conversions, `mid::util` -/

theorem be_to_u64x4_loop_spec (b : Std.Array U8 32#usize) (iter : core.ops.range.Range Std.Usize)
    (r : Std.Array U64 4#usize)
    (hs : iter.start.val ≤ 4) (he : iter.end.val = 4)
    (hr : ∀ i < iter.start.val, (r.val[i]!).val = beNat (b.val.slice (8 * (3 - i)) (8 * (4 - i)))) :
    mid.util.big_endian_to_u64x4_loop iter b r ⦃ r' =>
      ∀ i < 4, (r'.val[i]!).val = beNat (b.val.slice (8 * (3 - i)) (8 * (4 - i))) ⦄ := by
  unfold mid.util.big_endian_to_u64x4_loop
  apply loop.spec_decr_nat (fun x => 4 - x.1.start.val)
    (fun x => x.1.start.val ≤ 4 ∧ x.1.end.val = 4 ∧
      ∀ i < x.1.start.val, (x.2.val[i]!).val = beNat (b.val.slice (8 * (3 - i)) (8 * (4 - i))))
  · rintro ⟨it, r⟩ ⟨hs, he, hr⟩
    simp only at hs he hr ⊢
    unfold mid.util.big_endian_to_u64x4_loop.body
    step as ⟨o, iter1, ho, he1⟩
    split_ifs at ho with hlt
    · obtain ⟨rfl, hst⟩ := ho
      simp only
      step*
      · rcases r1 with a | _
        · exact ⟨a, rfl⟩
        · exact absurd (by rw [b1_post1, i4_post, i2_post, i3_post, i1_post, i_post]; omega) r1_post
      · subst r1_post
        obtain ⟨hab, -⟩ := r1_post
        have hi : i5.val = beNat (b.val.slice (8 * (3 - it.start.val)) (8 * (4 - it.start.val))) := by
          rw [val_of_fromBEBytes _ i5 i5_post, hab, b1_post, i2_post, i1_post, i_post, i4_post,
            i3_post, Array.val_to_slice]
          congr 2 <;> omega
        refine ⟨by omega, by simp [he1, he], ?_, by omega⟩
        intro j hj
        rw [a1_post, Std.Array.set_val_eq]
        by_cases hjs : j = it.start.val
        · subst hjs
          simp_lists [hi]
        · have h := hr j (by omega)
          simp_lists at h ⊢
          exact h
    · obtain ⟨rfl, hst⟩ := ho
      simp only [WP.spec_ok]
      intro i hi
      exact hr i (by omega)
  · exact ⟨hs, he, hr⟩

@[step]
theorem be_to_u64x4_spec (b : Std.Array U8 32#usize) :
    mid.util.big_endian_to_u64x4 b ⦃ w => wordsNat w.val = beNat b.val ⦄ := by
  unfold mid.util.big_endian_to_u64x4
  apply WP.spec_mono (be_to_u64x4_loop_spec b _ _ (by simp) (by simp) (by simp))
  intro w hw
  rw [wordsNat_four _ w.property, beNat_32 _ b.property, hw 0 (by omega), hw 1 (by omega),
    hw 2 (by omega), hw 3 (by omega)]

/-- The bytes `u64::to_be_bytes` writes. -/
def beBytes (w : U64) : List U8 := w.bv.toBEBytes.map (@UScalar.mk UScalarTy.U8)

theorem length_beBytes (w : U64) : (beBytes w).length = 8 := by
  simp [beBytes]

theorem u64x4_to_be_loop_spec (v : Std.Array U64 4#usize) (iter : core.ops.range.Range Std.Usize)
    (r : Std.Array U8 32#usize)
    (hs : iter.start.val ≤ 4) (he : iter.end.val = 4)
    (hr : r.val = List.replicate (8 * (4 - iter.start.val)) 0#u8 ++
      ((v.val.take iter.start.val).reverse.flatMap beBytes)) :
    mid.util.u64x4_to_big_endian_loop iter v r ⦃ r' =>
      r'.val = v.val.reverse.flatMap beBytes ⦄ := by
  unfold mid.util.u64x4_to_big_endian_loop
  apply loop.spec_decr_nat (fun x => 4 - x.1.start.val)
    (fun x => x.1.start.val ≤ 4 ∧ x.1.end.val = 4 ∧
      x.2.val = List.replicate (8 * (4 - x.1.start.val)) 0#u8 ++
        ((v.val.take x.1.start.val).reverse.flatMap beBytes))
  · rintro ⟨it, r⟩ ⟨hs, he, hr⟩
    simp only at hs he hr ⊢
    unfold mid.util.u64x4_to_big_endian_loop.body
    step as ⟨o, iter1, ho, he1⟩
    split_ifs at ho with hlt
    · obtain ⟨rfl, hst⟩ := ho
      simp only
      have hv : (v.val).length = 4 := v.property
      step*
      · rw [s_post1, s1_post]
        simp [i4_post, i3_post, i2_post, i1_post, i_post]
        omega
      · refine ⟨by omega, by simp [he1, he], ?_, by omega⟩
        have hs1 : s1.val = beBytes (v.val[it.start.val]) := by
          rw [s1_post, Array.val_to_slice, a_post, i5_post, beBytes]
        rw [s_post2, s2_post, hs1, hr, show 8 * (4 - it.start.val) = 8 * (3 - it.start.val) + 8 by omega,
          ← List.replicate_append_replicate, show i2.val = (List.replicate (8 * (3 - it.start.val)) 0#u8).length by
            simp [i2_post, i1_post, i_post]; omega,
          setSlice!_append _ _ _ _ (by simp [length_beBytes]), hst,
          show 8 * (4 - (it.start.val + 1)) = 8 * (3 - it.start.val) by omega]
        simp only [List.append_assoc, List.append_cancel_left_eq]
        rw [List.take_add_one, List.getElem?_eq_getElem (by omega), Option.toList_some,
          List.reverse_append, List.flatMap_append]
        simp only [List.reverse_cons, List.reverse_nil, List.nil_append, List.flatMap_cons,
          List.flatMap_nil, List.append_nil]
    · obtain ⟨rfl, hst⟩ := ho
      simp only [WP.spec_ok]
      have h4 : it.start.val = 4 := by omega
      have hv : (v.val).length = 4 := v.property
      rw [hr, h4, List.take_of_length_le (by omega)]
      simp
  · exact ⟨hs, he, hr⟩

theorem beNat_beBytes (w : U64) : beNat (beBytes w) = w.val := beNat_toBEBytes w

@[step]
theorem u64x4_to_be_spec (v : Std.Array U64 4#usize) :
    mid.util.u64x4_to_big_endian v ⦃ b => beNat b.val = wordsNat v.val ⦄ := by
  unfold mid.util.u64x4_to_big_endian
  apply WP.spec_mono (u64x4_to_be_loop_spec v _ _ (by simp) (by simp) (by simp))
  intro b hb
  rw [hb]
  have hv : (v.val).length = 4 := v.property
  generalize v.val = l at hv ⊢
  match l, hv with
  | [a, b, c, d], _ =>
    simp only [List.reverse_cons, List.reverse_nil, List.nil_append, List.cons_append,
      List.flatMap_cons, List.flatMap_nil, List.append_nil, beNat_append, length_beBytes,
      beNat_beBytes, wordsNat, List.map_cons, List.map_nil, Nat.ofDigits_cons, Nat.ofDigits_nil,
      List.append_assoc, List.singleton_append, List.length_append]
    ring

@[step]
theorem be_slice_to_u64x4_spec (s : Slice U8) :
    mid.util.big_endian_slice_to_u64x4 s ⦃ o =>
      if s.length = 32 then ∃ w, o = some w ∧ wordsNat w.val = beNat s.val else o = none ⦄ := by
  unfold mid.util.big_endian_slice_to_u64x4
  step*
  rcases r with a | _
  · obtain ⟨ha, hl⟩ := r_post
    simp only [core.result.Result.ok, core.option.Option.Insts.CoreOpsTry_traitTry.branch]
    step*
  · simp [core.result.Result.ok, core.option.Option.Insts.CoreOpsTry_traitTry.branch,
      core.option.Option.Insts.CoreOpsTry_traitFromResidualOptionNever.from_residual, r_post]

theorem be_any_size_32_spec (s : Slice U8) (h : s.length = 32) :
    mid.util.big_endian_slice_any_size_to_u64x4 s ⦃ o =>
      ∃ w, o = some w ∧ wordsNat w.val = beNat s.val ⦄ := by
  unfold mid.util.big_endian_slice_any_size_to_u64x4
  have hl : s.len = 32#usize := by
    apply UScalar.eq_of_val_eq; simpa [Slice.len, Slice.length] using h
  simp only [core.array.TryFromSharedArraySlice.try_from, hl, ↓reduceDIte]
  step as ⟨w, hw⟩
  simp [hw]

/-! ## Field elements and points, `mid::p256` -/

/-- The number a field element's limbs encode. -/
abbrev feNat (fe : mid.p256.FieldElement) : Nat := wordsNat fe.val

@[step]
theorem as_mont_spec (fe : mid.p256.FieldElement) :
    mid.p256.FieldElement.as_mont fe ⦃ r => feNat r = 2 ^ 256 * feNat fe % p256 ⦄ := by
  unfold mid.p256.FieldElement.as_mont mid.p256.FieldElement.Insts.CoreDefaultDefault.default
    core.default.DefaultArray.default
  step*

@[step]
theorem demont_spec (fe : mid.p256.FieldElement) (h : feNat fe < p256) :
    mid.p256.FieldElement.demont fe ⦃ r => feNat r = p256RInv * feNat fe % p256 ⦄ := by
  unfold mid.p256.FieldElement.demont mid.p256.FieldElement.Insts.CoreDefaultDefault.default
    core.default.DefaultArray.default
  step*

@[step]
theorem fe_add_spec (a b : mid.p256.FieldElement) (ha : feNat a < p256) (hb : feNat b < p256) :
    mid.p256.FieldElement.add a b ⦃ r => feNat r = (feNat a + feNat b) % p256 ⦄ := by
  unfold mid.p256.FieldElement.add mid.p256.FieldElement.Insts.CoreDefaultDefault.default
    core.default.DefaultArray.default
  step*

theorem p256_lt : p256 < 2 ^ 256 := by simp only [p256]; decide

@[step]
theorem mont_mul_spec (a b : mid.p256.FieldElement) (ha : feNat a < p256) (hb : feNat b < p256) :
    mid.p256.FieldElement.mont_mul a b ⦃ r => feNat r = p256RInv * feNat a * feNat b % p256 ⦄ := by
  unfold mid.p256.FieldElement.mont_mul mid.p256.FieldElement.Insts.CoreDefaultDefault.default
    core.default.DefaultArray.default
  step*
  exact a_post (le_of_lt (lt_of_lt_of_le (Nat.mul_lt_mul'' ha hb)
    (Nat.mul_le_mul_right _ (le_of_lt p256_lt))))

@[step]
theorem mont_sqr_spec (a : mid.p256.FieldElement) (ha : feNat a < p256) :
    mid.p256.FieldElement.mont_sqr a ⦃ r => feNat r = p256RInv * feNat a ^ 2 % p256 ⦄ := by
  unfold mid.p256.FieldElement.mont_sqr mid.p256.FieldElement.Insts.CoreDefaultDefault.default
    core.default.DefaultArray.default
  step*
  exact a_post (by
    rw [pow_two]
    exact le_of_lt (lt_of_lt_of_le (Nat.mul_lt_mul'' ha ha)
      (Nat.mul_le_mul_right _ (le_of_lt p256_lt))))

@[step]
theorem point_x_spec (pt : mid.p256.AffineMontPoint) :
    mid.p256.AffineMontPoint.x pt ⦃ fe => fe.val = pt.xy.val.take 4 ⦄ := by
  unfold mid.p256.AffineMontPoint.x
  have hl : (pt.xy.val).length = 8 := pt.xy.property
  step*
  · simp [mid.p256.AffineMontPoint.X]
  · simp [mid.p256.AffineMontPoint.X]
  · rcases r with a | _
    · exact ⟨a, rfl⟩
    · exact absurd (by simp [s_post1, mid.p256.AffineMontPoint.X]) r_post
  · subst r_post
    obtain ⟨ha, -⟩ := r_post
    simp [ha, s_post, mid.p256.AffineMontPoint.X, List.slice]

@[step]
theorem point_y_spec (pt : mid.p256.AffineMontPoint) :
    mid.p256.AffineMontPoint.y pt ⦃ fe => fe.val = pt.xy.val.drop 4 ⦄ := by
  unfold mid.p256.AffineMontPoint.y
  have hl : (pt.xy.val).length = 8 := pt.xy.property
  step*
  · simp [mid.p256.AffineMontPoint.Y]
  · simp [mid.p256.AffineMontPoint.Y]
  · rcases r with a | _
    · exact ⟨a, rfl⟩
    · exact absurd (by simp [s_post1, mid.p256.AffineMontPoint.Y]) r_post
  · subst r_post
    obtain ⟨ha, -⟩ := r_post
    simp [ha, s_post, mid.p256.AffineMontPoint.Y, List.slice, List.take_of_length_le, hl]

@[step]
theorem from_xy_spec (x y : mid.p256.FieldElement) :
    mid.p256.AffineMontPoint.from_xy x y ⦃ pt => pt.xy.val = x.val ++ y.val ⦄ := by
  unfold mid.p256.AffineMontPoint.from_xy mid.p256.AffineMontPoint.Insts.CoreDefaultDefault.default
    core.default.DefaultArray.default
  simp only [core.array.Array.index, core.ops.index.IndexSlice, core.slice.index.Slice.index,
    core.slice.index.SliceIndexRangeFullSlice, core.slice.index.SliceIndexRangeFullSlice.index]
  step*
  · simp [mid.p256.AffineMontPoint.X]
  · simp [mid.p256.AffineMontPoint.X]
  · simp [s_post1, mid.p256.AffineMontPoint.X]
  · simp [mid.p256.AffineMontPoint.Y]
  · simp [mid.p256.AffineMontPoint.Y]
  · simp [s3_post1, mid.p256.AffineMontPoint.Y]
  · have hx : (x.val).length = 4 := x.property
    have hy : (y.val).length = 4 := y.property
    rw [s3_post2, s5_post, s2_post, s_post2]
    have h8 : (Array.repeat 8#usize core.default.DefaultU64.default).val =
        [] ++ List.replicate 4 core.default.DefaultU64.default ++
          List.replicate 4 core.default.DefaultU64.default := by
      simp [Array.repeat]
    simp only [mid.p256.AffineMontPoint.X, mid.p256.AffineMontPoint.Y, Array.val_to_slice, h8]
    rw [show (0#usize).val = ([] : List U64).length by simp,
      setSlice!_append _ _ _ _ (by simp [hx]), List.nil_append,
      show (4#usize).val = x.val.length by simp [hx],
      ← List.append_nil (x.val ++ List.replicate 4 _), setSlice!_append _ _ _ _ (by simp [hy])]
    simp

theorem CURVE_A_MONT_val : feNat mid.p256.CURVE_A_MONT = 2 ^ 256 * (p256 - 3) % p256 := by
  simp only [feNat, mid.p256.CURVE_A_MONT, Array.make, Array.from_val, wordsNat, p256]
  decide

theorem CURVE_B_MONT_val : feNat mid.p256.CURVE_B_MONT = 2 ^ 256 * b256 % p256 := by
  simp only [feNat, mid.p256.CURVE_B_MONT, Array.make, Array.from_val, wordsNat, p256, b256]
  decide

/-- rind's curve check, in Montgomery form, is the curve equation on the
coordinates it encodes. -/
theorem mont_on_curve (X Y : Nat) :
    p256RInv * Y ^ 2 % p256 =
        (p256RInv * ((p256RInv * X ^ 2 % p256 + 2 ^ 256 * (p256 - 3) % p256) % p256) * X % p256 +
          2 ^ 256 * b256 % p256) % p256 ↔
      p256OnCurve (some (p256RInv * X % p256, p256RInv * Y % p256)) := by
  have hp : 0 < p256 := by simp [p256]
  have hRr : ((2 ^ 256 : Nat) : ZMod p256) * (p256RInv : ZMod p256) = 1 := by
    have := congrArg (fun n : Nat => (n : ZMod p256)) p256RInv_spec.2
    simpa only [Nat.cast_mul, ZMod.natCast_mod, Nat.cast_one] using this
  generalize (2 : Nat) ^ 256 = R at hRr ⊢
  simp only [p256OnCurve, Nat.mod_lt _ hp, true_and]
  rw [← ZMod.natCast_eq_natCast_iff', ← ZMod.natCast_eq_natCast_iff']
  push_cast [ZMod.natCast_mod]
  constructor
  · intro h
    linear_combination (p256RInv : ZMod p256) * h +
      (((p256 - 3 : Nat) : ZMod p256) * p256RInv * X + b256) * hRr
  · intro g
    linear_combination (R : ZMod p256) * g -
      ((p256RInv : ZMod p256) * Y ^ 2 - (p256RInv : ZMod p256) ^ 2 * X ^ 3) * hRr

theorem pairNat_drop (l : List U64) (h : l.length = 8) : (pairNat l).2 = wordsNat (l.drop 4) := by
  simp [pairNat, List.take_of_length_le, h]

theorem fe_lt_p256 (fe : mid.p256.FieldElement) (n : Nat) (h : feNat fe = n % p256) : feNat fe < p256 := by
  rw [h]; exact Nat.mod_lt _ (by simp [p256])

@[step]
theorem on_curve_spec (pt : mid.p256.AffineMontPoint) (hx : (pairNat pt.xy.val).1 < p256)
    (hy : (pairNat pt.xy.val).2 < p256) :
    mid.p256.AffineMontPoint.on_curve pt ⦃ b =>
      (b ↔ p256OnCurve (some (p256RInv * (pairNat pt.xy.val).1 % p256,
        p256RInv * (pairNat pt.xy.val).2 % p256))) ⦄ := by
  have hl : (pt.xy.val).length = 8 := pt.xy.property
  rw [pairNat_drop _ hl] at hy ⊢
  simp only [pairNat] at hx ⊢
  unfold mid.p256.AffineMontPoint.on_curve
  step as ⟨x, hxv⟩
  have hx' : feNat x < p256 := by simpa [feNat, hxv] using hx
  step as ⟨r0, hr0⟩
  have hA : feNat mid.p256.CURVE_A_MONT < p256 := by rw [CURVE_A_MONT_val]; exact Nat.mod_lt _ (by simp [p256])
  step as ⟨r1, hr1⟩
  step as ⟨r2, hr2⟩
  have hB : feNat mid.p256.CURVE_B_MONT < p256 := by rw [CURVE_B_MONT_val]; exact Nat.mod_lt _ (by simp [p256])
  step as ⟨r3, hr3⟩
  step as ⟨y, hyv⟩
  have hy' : feNat y < p256 := by simpa [feNat, hyv] using hy
  step as ⟨l, hl'⟩
  step*
  have hX : feNat x = wordsNat (pt.xy.val.take 4) := by simp [feNat, hxv]
  have hY : feNat y = wordsNat (pt.xy.val.drop 4) := by simp [feNat, hyv]
  rw [b_post, s_post, s1_post, Array.val_to_slice, Array.val_to_slice, decide_eq_true_iff,
    ← mont_on_curve, ← hX, ← hY, ← CURVE_A_MONT_val, ← CURVE_B_MONT_val]
  simp only [feNat] at hl' hr3 hr2 hr1 hr0
  rw [hl', hr3, hr2, hr1, hr0]

end rind.aarch64
