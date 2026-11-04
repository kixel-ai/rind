import Rind.X86_64.ShaBlocks
import Rind.Bytes
open Aeneas Aeneas.Std Result rind.spec

/-!
# SHA-1 and SHA-256, from their `Hash` impls to the block functions

The hash of a message is FIPS 180-4's, given `ShaBlocks`: the contracts of the
block functions below rind's padding, which no proof covers yet.
`admin/prove` writes the aarch64 proof from this file by renaming the target.
-/

namespace rind.x86_64

/-- The bytes `u32::to_be_bytes` writes. -/
def beBytes (w : U32) : List U8 := w.bv.toBEBytes.map (@UScalar.mk UScalarTy.U8)

/-! ## The digest's encoding -/

theorem sha1_out_loop_spec
    (it : core.iter.adapters.enumerate.Enumerate (core.slice.iter.Iter Std.U32))
    (r : Std.Array U8 20#usize) (V : List U32) (hVl : V.length = 5)
    (hV : it.iter.slice.val = V) (hi : it.iter.i = it.count.val) (hk : it.count.val ≤ 5)
    (hr : r.val.take (4 * it.count.val) = (V.take it.count.val).flatMap beBytes) :
    mid.sha1.Sha1State.finish_with_loop it r ⦃ r' => r'.val = V.flatMap beBytes ⦄ := by
  unfold mid.sha1.Sha1State.finish_with_loop
  apply loop.spec_decr_nat (fun x => 5 - x.1.count.val)
    (fun x => x.1.iter.slice.val = V ∧ x.1.iter.i = x.1.count.val ∧ x.1.count.val ≤ 5 ∧
      x.2.val.take (4 * x.1.count.val) = (V.take x.1.count.val).flatMap beBytes)
  · rintro ⟨it, r⟩ ⟨hV, hi, hk, hr⟩
    simp only at hV hi hk hr ⊢
    unfold mid.sha1.Sha1State.finish_with_loop.body
    simp only [core.iter.adapters.enumerate.IteratorEnumerate.next,
      core.slice.iter.IteratorSliceIter.next]
    have hsl : it.iter.slice.len.val = 5 := by simp [Slice.len, hV, hVl]
    split
    · rename_i hlt
      have hk4 : it.count.val < 5 := by omega
      step*
      · rw [s_post1, s1_post]
        simp [i3_post, i2_post, i1_post, Slice.length]
        omega
      · have ha8 : (a.val).length = 4 := a.property
        have hw : it.iter.slice[it.iter.i] = V[it.count.val] := by
          subst hV
          show it.iter.slice.val[it.iter.i]'(by simp [Slice.len] at hlt; omega) = _
          simp only [hi]
        refine ⟨hV, by omega, by omega, ?_, by omega⟩
        rw [s_post2, s2_post, s1_post]
        have hr32 : (r.val).length = 20 := r.property
        have := take_setSlice! r.val a.val (i1.val) (by rw [ha8, i1_post]; omega)
        simp only [Array.val_to_slice, ha8] at this ⊢
        rw [show 4 * x.val = i1.val + 4 by rw [x_post, i1_post]; ring, this, i1_post,
          show it.count.val * 4 = 4 * it.count.val by ring, hr, x_post, List.take_add_one,
          List.flatMap_append, List.getElem?_eq_getElem (by omega)]
        simp [a_post, hw, beBytes]
    · rename_i hlt
      have hk4 : it.count.val = 5 := by omega
      have hr32 : (r.val).length = 20 := r.property
      rw [hk4, List.take_of_length_le (by omega), List.take_of_length_le (by omega)] at hr
      simpa [WP.spec_ok] using hr
  · exact ⟨hV, hi, hk, hr⟩

theorem sha256_out_loop_spec
    (it : core.iter.adapters.enumerate.Enumerate (core.slice.iter.Iter Std.U32))
    (r : Std.Array U8 32#usize) (V : List U32) (hVl : V.length = 8)
    (hV : it.iter.slice.val = V) (hi : it.iter.i = it.count.val) (hk : it.count.val ≤ 8)
    (hr : r.val.take (4 * it.count.val) = (V.take it.count.val).flatMap beBytes) :
    mid.sha2.Sha256State.finish_with_loop it r ⦃ r' => r'.val = V.flatMap beBytes ⦄ := by
  unfold mid.sha2.Sha256State.finish_with_loop
  apply loop.spec_decr_nat (fun x => 8 - x.1.count.val)
    (fun x => x.1.iter.slice.val = V ∧ x.1.iter.i = x.1.count.val ∧ x.1.count.val ≤ 8 ∧
      x.2.val.take (4 * x.1.count.val) = (V.take x.1.count.val).flatMap beBytes)
  · rintro ⟨it, r⟩ ⟨hV, hi, hk, hr⟩
    simp only at hV hi hk hr ⊢
    unfold mid.sha2.Sha256State.finish_with_loop.body
    simp only [core.iter.adapters.enumerate.IteratorEnumerate.next,
      core.slice.iter.IteratorSliceIter.next]
    have hsl : it.iter.slice.len.val = 8 := by simp [Slice.len, hV, hVl]
    split
    · rename_i hlt
      have hk4 : it.count.val < 8 := by omega
      step*
      · rw [s_post1, s1_post]
        simp [i3_post, i2_post, i1_post, Slice.length]
        omega
      · have ha8 : (a.val).length = 4 := a.property
        have hw : it.iter.slice[it.iter.i] = V[it.count.val] := by
          subst hV
          show it.iter.slice.val[it.iter.i]'(by simp [Slice.len] at hlt; omega) = _
          simp only [hi]
        refine ⟨hV, by omega, by omega, ?_, by omega⟩
        rw [s_post2, s2_post, s1_post]
        have hr32 : (r.val).length = 32 := r.property
        have := take_setSlice! r.val a.val (i1.val) (by rw [ha8, i1_post]; omega)
        simp only [Array.val_to_slice, ha8] at this ⊢
        rw [show 4 * x.val = i1.val + 4 by rw [x_post, i1_post]; ring, this, i1_post,
          show it.count.val * 4 = 4 * it.count.val by ring, hr, x_post, List.take_add_one,
          List.flatMap_append, List.getElem?_eq_getElem (by omega)]
        simp [a_post, hw, beBytes]
    · rename_i hlt
      have hk4 : it.count.val = 8 := by omega
      have hr32 : (r.val).length = 32 := r.property
      rw [hk4, List.take_of_length_le (by omega), List.take_of_length_le (by omega)] at hr
      simpa [WP.spec_ok] using hr
  · exact ⟨hV, hi, hk, hr⟩

theorem bv_flatMap_beBytes (V : List U32) :
    bv (V.flatMap beBytes) = (words V).flatMap BitVec.toBEBytes := by
  induction V with
  | nil => rfl
  | cons w V ih =>
    simp only [List.flatMap_cons, bv, List.map_append, words, List.map_cons] at ih ⊢
    rw [ih]
    simp [beBytes, List.map_map, Function.comp_def]

/-- Rust's padding of `m` after the whole blocks `P`, closed by `bits` as
`u64::to_be_bytes` writes it, is FIPS 180-4's of `P ++ m`. -/
theorem pad_bv (P m : List U8) (bits : U64) (hP : P.length % 64 = 0)
    (hb : bits.val = 8 * (P.length + m.length)) :
    bv (P ++ m ++ [128#u8] ++ List.replicate (padZeros 64 8 m.length) 0#u8 ++
      bits.bv.toBEBytes.map (@UScalar.mk UScalarTy.U8)) = pad (bv (P ++ m)) := by
  have hz : padZeros 64 8 m.length = (64 - ((bv (P ++ m)).length + 9) % 64) % 64 := by
    have := padZeros_sub (N := 64) (L := 8) (n := P.length + m.length) (start := P.length) hP
      (by omega)
    rw [show P.length + m.length - P.length = m.length by omega] at this
    rw [this]
    simp [padZeros, bv]
  have hbits : bits.bv = BitVec.ofNat 64 (8 * (bv (P ++ m)).length) := by
    apply BitVec.eq_of_toNat_eq
    simp only [BitVec.toNat_ofNat, bv, List.length_map, List.length_append]
    rw [← hb, Nat.mod_eq_of_lt (by scalar_tac)]
    rfl
  rw [pad, hz, hbits]
  simp [bv, List.map_map, Function.comp_def]

/-! ## `mid::sha2::Sha256State` -/

/-- A SHA-256 state that has absorbed `P`, a whole number of blocks. -/
def Sha256Absorbed (P : List U8) (s : mid.sha2.Sha256State) : Prop :=
  Absorbed sha256.compress sha256.H0 P s.h ∧ s.nblocks.val * 64 = P.length

theorem sha256_finish_with_spec (hb : ShaBlocks) (P : List U8) (s : mid.sha2.Sha256State)
    (message : Slice U8) (hs : Sha256Absorbed P s)
    (hlen : 8 * (P.length + message.length) ≤ U64.max) :
    mid.sha2.Sha256State.finish_with s message ⦃ r =>
      bv r.val = sha256.hash (bv (P ++ message.val)) ⦄ := by
  obtain ⟨⟨hh, hP⟩, hn⟩ := hs
  have hml : message.len.val = message.length := by simp [Slice.len, Slice.length]
  unfold mid.sha2.Sha256State.finish_with
  step*
  have hi : i.val = 64 := by
    rw [i_post]
    simp [mid.sha2.Sha256State.finish_with.BLOCK_SZ, mid.sha2.Sha256Context.BLOCK_SZ]
  rcases o with _ | z
  · simp only at o_post; rw [hi] at o_post; omega
  simp only at o_post
  have hz : z.val = P.length := by rw [o_post.2.1, hi, hn]
  simp only [core.option.Option.and_then,
    mid.sha2.Sha256State.finish_with.closure.Insts.CoreOpsFunctionFnOnceTupleU64OptionU64,
    mid.sha2.Sha256State.finish_with.closure.Insts.CoreOpsFunctionFnOnceTupleU64OptionU64.call_once]
  step*
  have hx : x.val = message.length := by rw [x_post, ← hml]; simp
  have ha := U64.checked_add_bv_spec z x
  rcases hz2 : z.checked_add x with _ | z2
  · rw [hz2] at ha; simp only at ha; omega
  rw [hz2] at ha
  simp only at ha
  simp only [mid.sha2.Sha256State.finish_with.closure_1.Insts.CoreOpsFunctionFnOnceTupleU64OptionU64.call_once,
    bind_ok]
  have hm := U64.checked_mul_bv_spec z2 8#u64
  have h8 : (8#u64).val = 8 := by simp
  rcases hz3 : z2.checked_mul 8#u64 with _ | bits
  · rw [hz3] at hm; simp only at hm; rw [h8] at hm; omega
  rw [hz3] at hm
  simp only at hm
  have hbits : bits.val = 8 * (P.length + message.length) := by rw [hm.2.1, h8, ha.2.1]; omega
  simp only [core.option.Option.expect, Result.ofOption, bind_ok, hb.held]
  step*
  step with sha256_compress_padded_spec hb P s.h message a ⟨hh, hP⟩ as ⟨h', hh'⟩
  simp only [core.slice.Slice.iter]
  step*
  have hv : (h'.val).length = 8 := h'.property
  apply WP.spec_mono (sha256_out_loop_spec iter _ h'.val hv ?_ ?_ ?_ ?_)
  · intro r hr
    rw [hr, bv_flatMap_beBytes, hh'.1, a_post, pad_bv P message.val bits hP hbits]
    rfl
  all_goals simp [iter_post, iter_post1, s_post, Array.val_to_slice]

end rind.x86_64
