import Rind.X86_64.Sha
open Aeneas Aeneas.Std Result rind.spec

/-!
# HMAC's keyed states, `high::hmac`, over any hash

`HmacKey` and `Hmac` compute RFC 2104's HMAC, as HACL*'s `Spec.Agile.HMAC`
states it, over any hash whose `Hash` impl meets `HashSpec`: SHA-1's and
SHA-256's do, given `ShaBlocks`.
-/

namespace rind.x86_64

/-- `S` with every byte from index `i` on XORed with `c`. -/
def xorFrom (c : U8) (S : Slice U8) (i : Nat) : Slice U8 :=
  Slice.from (S.val.mapIdx fun j x => if i ≤ j then x ^^^ c else x) (by simp)

theorem xorFrom_step (c : U8) (S : Slice U8) (i : Nat) (hi : i < S.length) :
    (xorFrom c S (i + 1)).setAtNat i (S.val[i] ^^^ c) = xorFrom c S i := by
  simp only [Slice.setAtNat, xorFrom, Slice.from_val]
  congr 1
  apply List.ext_getElem (by simp)
  intro j h1 h2
  rw [List.getElem_set]
  by_cases h : i = j
  · subst h; simp
  · rw [if_neg h, List.getElem_mapIdx, List.getElem_mapIdx]
    by_cases hj : i + 1 ≤ j
    · rw [if_pos hj, if_pos (by omega)]
    · rw [if_neg hj, if_neg (by omega)]

theorem xorFrom_end (c : U8) (S : Slice U8) : xorFrom c S S.length = S := by
  apply Slice.ext
  simp only [xorFrom, Slice.from_val]
  apply List.ext_getElem (by simp)
  intro j h1 h2
  rw [List.getElem_mapIdx, if_neg (by simp only [List.length_mapIdx, Slice.length] at h1 ⊢; omega)]

theorem new_loop0_spec (S : Slice U8)
    (back : core.slice.iter.IterMut U8 → core.slice.iter.IterMut U8) :
    high.hmac.HmacKey.new_loop0 { slice := S } back ⦃ r =>
      r = back ⟨xorFrom 54#u8 S 0, S.length⟩ ⦄ := by
  unfold high.hmac.HmacKey.new_loop0
  apply loop.spec_decr_nat (fun x => S.length - x.1.i)
    (fun x => x.1.slice = S ∧ x.1.i ≤ S.length ∧
      x.2 ⟨xorFrom 54#u8 S x.1.i, S.length⟩ = back ⟨xorFrom 54#u8 S 0, S.length⟩)
  · rintro ⟨⟨sl, i⟩, bk⟩ ⟨hs, hi, hb⟩
    simp only at hs hi hb ⊢
    subst hs
    unfold high.hmac.HmacKey.new_loop0.body core.slice.iter.IteratorIterMut.next
    split
    · rename_i hlt
      have hlt' : i < sl.length := by simpa [Slice.len, Slice.length] using hlt
      step*
      have hb1 : byte1 = sl.val[i] ^^^ 54#u8 := UScalar.eq_of_val_eq byte1_post
      refine ⟨by omega, ?_, by omega⟩
      rw [hb1, xorFrom_step 54#u8 sl i hlt', hb]
    · rename_i hge
      have hl : sl.length = sl.val.length := rfl
      have hi' : i = sl.length := by simp [Slice.len] at hge; omega
      step*
      subst hi'
      rw [xorFrom_end] at hb
      exact hb
  · exact ⟨rfl, by simp, rfl⟩

theorem new_loop1_spec (S : Slice U8)
    (back : core.slice.iter.IterMut U8 → core.slice.iter.IterMut U8) :
    high.hmac.HmacKey.new_loop1 { slice := S } back ⦃ im b =>
      b im = back ⟨xorFrom (92#u8 ^^^ 54#u8) S 0, S.length⟩ ⦄ := by
  unfold high.hmac.HmacKey.new_loop1
  apply loop.spec_decr_nat (fun x => S.length - x.1.i)
    (fun x => x.1.slice = S ∧ x.1.i ≤ S.length ∧
      x.2 ⟨xorFrom (92#u8 ^^^ 54#u8) S x.1.i, S.length⟩ =
        back ⟨xorFrom (92#u8 ^^^ 54#u8) S 0, S.length⟩)
  · rintro ⟨⟨sl, k⟩, bk⟩ ⟨hs, hi, hb⟩
    simp only at hs hi hb ⊢
    subst hs
    unfold high.hmac.HmacKey.new_loop1.body core.slice.iter.IteratorIterMut.next
    split
    · rename_i hlt
      have hlt' : k < sl.length := by simpa [Slice.len, Slice.length] using hlt
      step*
      have hc : i = 92#u8 ^^^ 54#u8 := UScalar.eq_of_val_eq i_post
      have hb1 : byte1 = sl.val[k] ^^^ (92#u8 ^^^ 54#u8) := by
        rw [← hc]; exact UScalar.eq_of_val_eq byte1_post
      refine ⟨by omega, ?_, by omega⟩
      rw [hb1, xorFrom_step _ sl k hlt', hb]
    · rename_i hge
      have hl : sl.length = sl.val.length := rfl
      have hi' : k = sl.length := by simp [Slice.len] at hge; omega
      step*
      subst hi'
      rw [xorFrom_end] at hb
      exact hb
  · exact ⟨rfl, by simp, rfl⟩

end rind.x86_64
