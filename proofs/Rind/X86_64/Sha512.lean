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

/-! ## Updating, `mid::sha2::Sha512Context::update` -/

@[step]
theorem saturating_add_spec (x y : U64) (h : x.val + y.val < 2 ^ 64) :
    lift (core.num.U64.saturating_add x y) ⦃ z => z.val = x.val + y.val ⦄ := by
  simp only [lift, WP.spec_ok, core.num.U64.saturating_add, UScalar.saturating_add]
  show (BitVec.ofNat _ _).toNat = _
  rw [BitVec.toNat_ofNat, min_eq_right (by simp [U64.max_eq]; omega)]
  simp; omega

/-- `update_blocks` compresses whole blocks and counts them. -/
@[step]
theorem update_blocks_spec (h : RunsSha512) (st : mid.sha2.Sha512State) (blocks : Slice U8)
    (hm : blocks.length % 128 = 0) (hn : st.nblocks.val + blocks.length / 128 < 2 ^ 64) :
    mid.sha2.Sha512State.Insts.RindLowGenericBlockwiseUpdateBlocks.update_blocks st blocks ⦃ st' =>
      st'.h.val = compress st.h.val blocks.val ∧
        st'.nblocks.val = st.nblocks.val + blocks.length / 128 ⦄ := by
  unfold mid.sha2.Sha512State.Insts.RindLowGenericBlockwiseUpdateBlocks.update_blocks
  have hB : mid.sha2.Sha512Context.BLOCK_SZ.val = 128 := by simp [mid.sha2.Sha512Context.BLOCK_SZ]
  step*
  rename_i hb
  have h0 : blocks.length = 0 := by simpa [hb] using b1_post
  simp [compress_short _ _ (by omega : blocks.length < 128), h0]

/-- The state after an optional `update_blocks`, skipped for no blocks. -/
theorem update_blocks_if_spec (h : RunsSha512) (b : Bool) (st : mid.sha2.Sha512State)
    (blocks : Slice U8) (hb : (b = true) = (blocks.length = 0)) (hm : blocks.length % 128 = 0)
    (hn : st.nblocks.val + blocks.length / 128 < 2 ^ 64) :
    (if b = true then ok st
      else mid.sha2.Sha512State.Insts.RindLowGenericBlockwiseUpdateBlocks.update_blocks st blocks)
      ⦃ st' => st'.h.val = compress st.h.val blocks.val ∧
        st'.nblocks.val = st.nblocks.val + blocks.length / 128 ⦄ := by
  split
  · rename_i hb'
    have h0 : blocks.length = 0 := by simpa [hb'] using hb
    simp [compress_short _ _ (by omega : blocks.length < 128), h0]
  · step*

/-- `omega` once every slice length reads as its list's. -/
macro "len_omega" : tactic => `(tactic| (try simp only [Slice.length, Slice.len_val] at *) <;> omega)

theorem setSlice!_fill {α : Type _} (buf hd : List α) (u : Nat) (h : u + hd.length = buf.length) :
    buf.setSlice! u hd = buf.take u ++ hd := by
  simp only [List.setSlice!, show min hd.length (buf.length - u) = hd.length by omega,
    List.take_of_length_le (le_refl _), List.drop_eq_nil_of_le (show buf.length ≤ u + hd.length by omega),
    List.append_nil]

theorem take_setSlice!_zero {α : Type _} (buf r : List α) (h : r.length ≤ buf.length) :
    (buf.setSlice! 0 r).take r.length = r := by
  have := take_setSlice! buf r 0 (by omega)
  simpa using this

/-- `complete_blocks` compresses the buffered bytes and `bytes` up to their
last 1 to 128 bytes, which it buffers. -/
theorem complete_blocks_spec (h : RunsSha512) (bw : low.generic.blockwise.Blockwise 128#usize)
    (bytes : Slice U8) (st : mid.sha2.Sha512State) (hu : bw.used.val ≤ 128)
    (hlong : 128 < bw.used.val + bytes.length)
    (hn : st.nblocks.val + (bw.used.val + bytes.length) / 128 < 2 ^ 64) :
    low.generic.blockwise.Blockwise.complete_blocks
      mid.sha2.Sha512State.Insts.RindLowGenericBlockwiseUpdateBlocks bw bytes st ⦃ bw' st' =>
      let all := bw.buffer.val.take bw.used.val ++ bytes.val
      let k := (all.length - 1) / 128 * 128
      st'.h.val = compress st.h.val (all.take k) ∧ st'.nblocks.val = st.nblocks.val + k / 128 ∧
        bw'.used.val = all.length - k ∧ bw'.buffer.val.take bw'.used.val = all.drop k ⦄ := by
  unfold low.generic.blockwise.Blockwise.complete_blocks
  have hbl : (bw.buffer.val).length = 128 := bw.buffer.property
  have hlen : (bw.buffer.val.take bw.used.val ++ bytes.val).length = bw.used.val + bytes.length := by
    simp [Slice.length]; omega
  split
  · rename_i hpos
    step as ⟨i, hi, hi'⟩
    step as ⟨hr, hhl, hrl, hhv, hrv⟩
    obtain ⟨head, rest1⟩ := hr
    simp only at *
    step as ⟨sb, hsv, hsl, hback⟩
    obtain ⟨s, back⟩ := sb
    simp only at *
    step as ⟨s1, hs1⟩
    step as ⟨s2, hs2⟩
    have hhead : head.val.length = 128 - bw.used.val := by
      simp only [Slice.length] at hhl; omega
    have hfull : (back s1).val = bw.buffer.val.take bw.used.val ++ head.val := by
      rw [hback, hs1, setSlice!_fill _ _ _ (by omega)]
    have hs2l : s2.length = 128 := by
      simp only [hs2, Slice.length, Array.val_to_slice, hfull, List.length_append, List.length_take,
        hhead, hbl]; omega
    step with update_blocks_spec h st s2 (by omega) (by omega) as ⟨st1, hst1, hst1'⟩
    step as ⟨i1, hi1, hi1'⟩
    step as ⟨i2, hi2⟩
    step as ⟨i3, hi3⟩
    step as ⟨whole, rest, hwl, hrl2, hwv, hrv2⟩
    step as ⟨b, hb⟩
    have hr1 : rest1.len.val = rest1.length := by simp
    have hi1n : i1.val = rest1.length - 1 := by rw [hi1, hr1]
    have hrest1 : rest1.length ≥ 1 := by rw [← hr1]; exact hi1'
    have hwl' : whole.length = (rest1.length - 1) / 128 * 128 := by rw [hwl, hi3, hi2, hi1n]
    have hrl' : rest.length = rest1.length - (rest1.length - 1) / 128 * 128 := by
      rw [hrl2, hi3, hi2, hi1n]
    have hi3n : i3.val = (rest1.length - 1) / 128 * 128 := by rw [hi3, hi2, hi1n]
    have hpos' : bw.used.val > 0 := hpos
    have hk : ((bw.buffer.val.take bw.used.val ++ bytes.val).length - 1) / 128 * 128 = 128 + i3.val := by
      rw [hlen, hi3n]; len_omega
    step with update_blocks_if_spec h b st1 whole hb (by len_omega)
      (by rw [hst1', hs2l]; len_omega) as ⟨st2, hst2, hst2'⟩
    step as ⟨s3, back3, hsv', hsl', hback'⟩
    step as ⟨s4, hs4⟩
    have hA : (bw.buffer.val.take bw.used.val).length = bw.used.val := by simp [hbl]; omega
    have hiu : i.val + bw.used.val = 128 := by omega
    have hrest : rest.val = bytes.val.drop (i.val + i3.val) := by
      rw [hrv2, hrv, List.drop_drop, Nat.add_comm]
    have hsplit : (bw.buffer.val.take bw.used.val ++ bytes.val).take (128 + i3.val) =
        (bw.buffer.val.take bw.used.val ++ head.val) ++ whole.val := by
      rw [List.take_append, List.take_of_length_le (by omega), hA,
        show 128 + i3.val - bw.used.val = i.val + i3.val by omega, List.take_add, hhv, hwv, hrv,
        List.append_assoc]
    have hdrop : (bw.buffer.val.take bw.used.val ++ bytes.val).drop (128 + i3.val) = rest.val := by
      rw [List.drop_append, List.drop_of_length_le (by omega), List.nil_append, hA,
        show 128 + i3.val - bw.used.val = i.val + i3.val by omega, hrest]
    have hfl : (bw.buffer.val.take bw.used.val ++ head.val).length = 128 := by
      rw [List.length_append, hA]; exact (show head.val.length = i.val from hhl) ▸ (by omega)
    have hrestl : rest.val.length = rest1.val.length - i3.val := hrl2
    have hr1l : rest1.val.length = bytes.val.length - i.val := hrl
    refine ⟨?_, ?_, ?_, ?_⟩
    · rw [hk, hsplit, hst2, hst1, hs2, Array.val_to_slice, hfull]
      exact (compress_append _ _ _ (by rw [hfl])).symm
    · rw [hk, hst2', hst1', hs2l, hwl', ← hi3n]; omega
    · rw [hk, hlen, Slice.len_val]
      show rest.val.length = _
      simp only [Slice.length] at hr1l ⊢
      omega
    · have hb128 : ((back s1).val).length = 128 := (back s1).property
      rw [hk, hdrop, hback', hs4, Slice.len_val, take_setSlice!_zero _ _ (by
        rw [hb128, hrestl, hi3n]; simp only [Slice.length] at hrest1 ⊢; omega)]
  · rename_i hneg
    have hu0 : bw.used.val = 0 := by
      have : ¬ bw.used.val > 0 := hneg
      omega
    step*
    have hall : bw.buffer.val.take bw.used.val ++ bytes.val = bytes.val := by simp [hu0]
    have hi3n : i3.val = (bytes.val.length - 1) / 128 * 128 := by
      rw [i3_post, i2_post, i1_post, Slice.len_val]
    have hk : ((bw.buffer.val.take bw.used.val ++ bytes.val).length - 1) / 128 * 128 = i3.val := by
      rw [hall, hi3n]
    have hwl : whole.val.length = i3.val := whole_post
    have hrl : rest.val.length = bytes.val.length - i3.val := whole_post1
    step with update_blocks_if_spec h b st whole b_post (by rw [whole_post, hi3n]; omega)
      (by rw [whole_post, hi3n]; simp only [Slice.length, hu0] at hn ⊢; omega) as ⟨st2, hst2, hst2'⟩
    step as ⟨s3, back3, hsv', hsl', hback'⟩
    step as ⟨s4, hs4⟩
    refine ⟨?_, ?_, ?_, ?_⟩
    · rw [hk, hall, hst2, whole_post2]
    · rw [hk, hst2', whole_post]
    · rw [hk, hall, Slice.len_val]; exact hrl
    · rw [hk, hall, hback', hs4, Slice.len_val, take_setSlice!_zero _ _ (by rw [hbl, hrl, hi3n]; omega),
        whole_post3]

end rind.x86_64
