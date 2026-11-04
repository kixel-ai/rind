import Rind.X86_64.AwsLc
import Rind.Bytes
open Aeneas Aeneas.Std Result rind.spec

/-!
# SHA-512, SHA-384, and SHA-512/256, proven from rind's digest API to aws-lc's contract
-/

namespace rind.x86_64

/-! ## Padding, `low::generic::blockwise` -/

@[step]
theorem as_flattened_mut_spec {T : Type} {N : Usize} (s : Slice (Std.Array T N))
    (h : (s.val.flatMap (·.val)).length ≤ Usize.max) :
    core.slice.SliceArray.as_flattened_mut s ⦃ f _ => f.val = s.val.flatMap (·.val) ⦄ := by
  unfold core.slice.SliceArray.as_flattened_mut
  simp only
  rw [dite_eq_left_of_eq_true (eq_true h)]
  simp

/-- The list `pad` writes. -/
theorem pad_list (r l : List U8) (P : Nat) (hl : l.length = 16) (hP : r.length + 17 ≤ P) :
    (((List.replicate P 0#u8).setSlice! 0 r).set r.length 0x80#u8).setSlice! (P - 16) l =
      r ++ 0x80#u8 :: List.replicate (P - r.length - 17) 0#u8 ++ l := by
  have hA : (List.replicate P 0#u8).setSlice! 0 r = r ++ List.replicate (P - r.length) 0#u8 := by
    simp [List.setSlice!, show min r.length P = r.length by omega, List.drop_replicate]
  have hB : (r ++ List.replicate (P - r.length) 0#u8).set r.length 0x80#u8 =
      (r ++ 0x80#u8 :: List.replicate (P - r.length - 17) 0#u8) ++ List.replicate 16 0#u8 := by
    rw [List.set_append_right _ _ (by omega)]
    simp only [Nat.sub_self]
    rw [show P - r.length = (P - r.length - 17 + 16) + 1 by omega, List.replicate_succ]
    simp [List.replicate_add]
  rw [hA, hB]
  generalize hX : r ++ 0x80#u8 :: List.replicate (P - r.length - 17) 0#u8 = X
  have hlen : X.length = P - 16 := by rw [← hX]; simp; omega
  simp only [List.setSlice!, List.length_append, List.length_replicate, hlen, hl,
    show min 16 (P - 16 + 16 - (P - 16)) = 16 by omega, List.take_of_length_le (le_of_eq hl)]
  rw [List.take_append_of_le_length (by omega), List.take_of_length_le (by omega),
    List.drop_eq_nil_of_le (by simp; omega)]
  simp

theorem zero_blocks_flat :
    (Std.Array.repeat 2#usize (Std.Array.repeat 128#usize 0#u8)).val.flatMap (·.val) =
      List.replicate 256 0#u8 := by
  simp [Std.Array.repeat]

/-- `pad` writes the message's tail, the 0x80 byte, zeros, and the length. -/
@[step]
theorem pad_spec (rest : Slice U8) (length : Std.Array U8 16#usize)
    (hr : rest.length < 256) (hr' : 128 ≤ rest.length → rest.length % 128 ≤ 111) :
    low.generic.blockwise.pad (N := 128#usize) rest length
      (Std.Array.repeat 2#usize (Std.Array.repeat 128#usize 0#u8)) ⦃ s _ =>
      s.val = rest.val ++ 0x80#u8 :: List.replicate ((239 - rest.length % 128) % 128) 0#u8 ++
        length.val ⦄ := by
  unfold low.generic.blockwise.pad
  step*
  have hflat := zero_blocks_flat
  have hlen : rest.len.val = rest.length := by simp
  split_ifs with hfit <;> step*
  all_goals
    have hs1 : s1.val = List.replicate 256 0#u8 := by rw [s1_post, s_post, hflat]
    have hlast1 : last1.val = List.replicate padded.val 0#u8 := by
      have : padded.val ≤ 256 := by scalar_tac
      rw [last1_post, hs1, List.slice, List.drop_zero, Nat.sub_zero, List.take_replicate,
        min_eq_left this]
    have hb1 : (index_mut_back1 s3).val = (List.replicate padded.val 0#u8).setSlice! 0 rest.val := by
      rw [s2_post2, hlast1, s3_post]
    have hlast3 : last3.val = ((List.replicate padded.val 0#u8).setSlice! 0 rest.val).set rest.length 0x80#u8 := by
      rw [last3_post, Slice.set_val_eq, hb1]; simp
    have hl3 : last3.length = padded.val := by simp [Slice.length, hlast3, List.length_setSlice!]
    first
    | simp [s4_post1, hl3, i6_post, s5_post, Slice.length]; omega
    | have hP : rest.length + 17 ≤ padded.val := by scalar_tac
      have hz : padded.val - rest.length - 17 = (239 - rest.length % 128) % 128 := by scalar_tac
      rw [s4_post2, hlast3, s6_post, s5_post, Array.val_to_slice, i6_post,
        pad_list _ _ _ (by simp) hP, hz]

/-- `split_tail` leaves whole blocks, then a tail that `pad` fits in two blocks. -/
@[step]
theorem split_tail_spec (message : Slice U8) :
    low.generic.blockwise.split_tail 128#usize 16#usize message ⦃ blocks rest =>
      blocks.val ++ rest.val = message.val ∧ blocks.length % 128 = 0 ∧
      rest.length % 128 = message.length % 128 ∧ rest.length < 256 ∧
      (128 ≤ rest.length → rest.length % 128 ≤ 111) ⦄ := by
  unfold low.generic.blockwise.split_tail
  step*
  split_ifs <;> step* <;> simp only [Slice.length] at * <;>
    rw [blocks_post2, blocks_post3, List.take_append_drop] <;> refine ⟨rfl, ?_⟩ <;> scalar_tac

/-! ## Finishing, `mid::sha2::Sha512State::finish_with` -/

theorem finish_with_loop_spec
    (it : core.iter.adapters.enumerate.Enumerate (core.slice.iter.Iter Std.U64))
    (r : Std.Array U8 64#usize) (V : List U64) (hVl : V.length = 8)
    (hV : it.iter.slice.val = V) (hi : it.iter.i = it.count.val) (hk : it.count.val ≤ 8)
    (hr : r.val.take (8 * it.count.val) = (V.take it.count.val).flatMap beBytes) :
    mid.sha2.Sha512State.finish_with_loop it r ⦃ r' => r'.val = V.flatMap beBytes ⦄ := by
  unfold mid.sha2.Sha512State.finish_with_loop
  apply loop.spec_decr_nat (fun x => 8 - x.1.count.val)
    (fun x => x.1.iter.slice.val = V ∧ x.1.iter.i = x.1.count.val ∧ x.1.count.val ≤ 8 ∧
      x.2.val.take (8 * x.1.count.val) = (V.take x.1.count.val).flatMap beBytes)
  · rintro ⟨it, r⟩ ⟨hV, hi, hk, hr⟩
    simp only at hV hi hk hr ⊢
    unfold mid.sha2.Sha512State.finish_with_loop.body
    simp only [core.iter.adapters.enumerate.IteratorEnumerate.next,
      core.slice.iter.IteratorSliceIter.next]
    have hsl : it.iter.slice.len.val = 8 := by simp [Slice.len, hV, hVl]
    split
    · rename_i hlt
      have hk8 : it.count.val < 8 := by omega
      step*
      · rw [s_post1, s1_post]
        simp [i3_post, i2_post, i1_post, Slice.length]
        omega
      · have ha8 : (a.val).length = 8 := a.property
        have hw : it.iter.slice[it.iter.i] = V[it.count.val] := by
          subst hV
          show it.iter.slice.val[it.iter.i]'(by simp [Slice.len] at hlt; omega) = _
          simp only [hi]
        refine ⟨hV, by omega, by omega, ?_, by omega⟩
        rw [s_post2, s2_post, s1_post]
        have hr64 : (r.val).length = 64 := r.property
        have := take_setSlice! r.val a.val (i1.val) (by rw [ha8, i1_post]; omega)
        simp only [Array.val_to_slice, ha8] at this ⊢
        rw [show 8 * x.val = i1.val + 8 by rw [x_post, i1_post]; ring, this, i1_post,
          show it.count.val * 8 = 8 * it.count.val by ring, hr, x_post, List.take_add_one,
          List.flatMap_append, List.getElem?_eq_getElem (by omega)]
        simp [a_post, hw, beBytes]
    · rename_i hlt
      have hk8 : it.count.val = 8 := by omega
      have hr64 : (r.val).length = 64 := r.property
      rw [hk8, List.take_of_length_le (by omega), List.take_of_length_le (by omega)] at hr
      simpa [WP.spec_ok] using hr
  · exact ⟨hV, hi, hk, hr⟩

@[step]
theorem from_u128_u64_spec (x : U64) :
    lift (core.convert.num.FromU128U64.from x) ⦃ y => y.val = x.val ⦄ := by
  simp [lift, core.convert.num.FromU128U64.from_val_eq]

@[step]
theorem compress_spec (h : RunsSha512) (state : Std.Array U64 8#usize) (blocks : Slice U8)
    (hm : blocks.length % 128 = 0) :
    mid.sha2.Sha512State.compress state blocks ⦃ r => r.val = compress state.val blocks.val ⦄ := by
  unfold mid.sha2.Sha512State.compress
  step*

/-- `finish_with` hashes the message after the state's blocks, padded. -/
@[step]
theorem finish_with_spec (h : RunsSha512) (self : mid.sha2.Sha512State) (message : Slice U8) :
    mid.sha2.Sha512State.finish_with self message ⦃ r =>
      r.val = (compress self.h.val (padAfter (128 * self.nblocks.val) message.val)).flatMap beBytes ⦄ := by
  unfold mid.sha2.Sha512State.finish_with
  have hB : (UScalar.cast .U128 mid.sha2.Sha512State.finish_with.BLOCK_SZ).val = 128 := by
    simp [mid.sha2.Sha512State.finish_with.BLOCK_SZ, mid.sha2.Sha512Context.BLOCK_SZ, UScalar.cast_val_eq]
  have hL : (UScalar.cast .U128 message.len).val = message.length := by
    have := slice_length_lt message
    simp [UScalar.cast_val_eq, Slice.length] at this ⊢; omega
  have hn : self.nblocks.val < 2 ^ 64 := self.nblocks.hBounds
  have hm : message.length < 2 ^ 64 := slice_length_lt message
  step*
  all_goals (try (simp only [hB, hL] at *; scalar_tac))
  have hbits : bits.val = 8 * (128 * self.nblocks.val + message.length) := by
    rw [bits_post, i5_post, i2_post, i_post, i1_post, hB, i4_post, hL]; ring
  have hh : (if b = true then ok self.h else mid.sha2.Sha512State.compress self.h blocks) ⦃ h' =>
      h'.val = compress self.h.val blocks.val ⦄ := by
    split
    · have : blocks.val = [] := List.eq_nil_of_length_eq_zero (by simp_all [Slice.length])
      simp [this]
    · step*
  step with hh as ⟨h', hh'⟩
  step*
  · have : (a1.val).length = 16 := by simp
    simp only [Slice.length, s_post, List.length_append, List.length_cons, List.length_replicate] at this ⊢
    omega
  · simp only [core.slice.Slice.iter]
    step*
    have hl : (h1.val).length = 8 := h1.property
    apply WP.spec_mono (finish_with_loop_spec iter _ h1.val hl ?_ ?_ ?_ ?_)
    · intro r hr
      rw [hr, h1_post, hh', ← compress_append _ _ _ blocks_post1]
      congr 2
      have hbv : bits.bv = BitVec.ofNat 128 (8 * (128 * self.nblocks.val + message.length)) := by
        apply BitVec.eq_of_toNat_eq
        rw [BitVec.toNat_ofNat, ← hbits]
        exact (Nat.mod_eq_of_lt bits.bv.isLt).symm
      have hml : (blocks.val ++ rest.val).length = message.val.length := by rw [blocks_post]
      rw [s_post, a1_post, hbv, padAfter, ← blocks_post2, ← blocks_post]
      simp only [List.append_assoc, Slice.length, List.cons_append, hml]
    all_goals simp [iter_post, iter_post1, s1_post, Array.val_to_slice]

end rind.x86_64
