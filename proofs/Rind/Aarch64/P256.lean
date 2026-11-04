import Rind.Aarch64.S2nBignum
import Rind.Bytes
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

end rind.aarch64
