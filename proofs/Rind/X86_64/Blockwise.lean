import Rind.X86_64.Funs
import Rind.HashSpec
open Aeneas Aeneas.Std Result

/-!
# Merkle-Damgard padding and buffering, `low::generic::blockwise`

What `pad`, `compress_padded`, and `Blockwise` compute, for any hash whose
`Compress` impl adds whole blocks to what its state has absorbed.
-/

namespace rind.x86_64

/-- The zero bytes FIPS 180-4's padding puts between the 0x80 byte and an
`L`-byte length after `n` bytes, for `N`-byte blocks. -/
def padZeros (N L n : Nat) : Nat := (N - (n + 1 + L) % N) % N

@[step]
theorem as_flattened_mut_spec {T : Type} {N : Usize} (s : Slice (Std.Array T N))
    (h : s.length * N.val ≤ Usize.max) :
    core.slice.SliceArray.as_flattened_mut s ⦃ f _ =>
      f.val = (s.val.map (·.val)).flatten ⦄ := by
  have hl : ((s.val.map (·.val)).flatten).length = s.length * N.val := by
    rw [List.length_flatten, List.map_map]
    have : ∀ a ∈ s.val, ((·.length) ∘ (·.val) : Std.Array T N → Nat) a = N.val := by simp
    rw [List.map_congr_left this]
    simp
  unfold core.slice.SliceArray.as_flattened_mut
  simp only [hl, h, ↓reduceDIte, WP.spec_ok, WP.uncurry'_pair, Slice.from_val]

/-- `pad`'s length: the rest, the 0x80 byte, the zeros, and the length fill
one or two whole blocks. -/
theorem padded_eq {N L n : Nat} (hN : 0 < N) (hL : L + 1 ≤ N) (hr : n + 1 + L ≤ 2 * N) :
    (if n % N + 1 + L ≤ N then n / N * N + N else n / N * N + 2 * N) =
      n + 1 + L + padZeros N L n := by
  unfold padZeros
  rcases Nat.lt_or_ge n N with h | h
  · have h1 : n / N = 0 := Nat.div_eq_of_lt h
    have h2 : n % N = n := Nat.mod_eq_of_lt h
    rw [h1, h2]
    by_cases h3 : n + 1 + L ≤ N
    · rcases Nat.lt_or_ge (n + 1 + L) N with h4 | h4
      · rw [Nat.mod_eq_of_lt h4, Nat.mod_eq_of_lt (by omega)]; simp [h3]
      · have : n + 1 + L = N := by omega
        rw [this, Nat.mod_self]; simp
    · have h4 : (n + 1 + L) % N = n + 1 + L - N := by
        rw [Nat.mod_eq_sub_mod (by omega), Nat.mod_eq_of_lt (by omega)]
      rw [h4, Nat.mod_eq_of_lt (by omega)]; simp [h3]; omega
  · have h1 : n / N = 1 := Nat.div_eq_of_lt_le (by omega) (by omega)
    have h2 : n % N = n - N := by rw [Nat.mod_eq_sub_mod h, Nat.mod_eq_of_lt (by omega)]
    rw [h1, h2, if_pos (show n - N + 1 + L ≤ N by omega)]
    rcases Nat.lt_or_ge (n + 1 + L) (2 * N) with h3 | h3
    · have h4 : (n + 1 + L) % N = n + 1 + L - N := by
        rw [Nat.mod_eq_sub_mod (by omega), Nat.mod_eq_of_lt (by omega)]
      rw [h4, Nat.mod_eq_of_lt (by omega)]; omega
    · have : n + 1 + L = 2 * N := by omega
      rw [this, Nat.mul_mod_left, Nat.sub_zero, Nat.mod_self]; omega

theorem padded_le {N L n : Nat} (hN : 0 < N) (hL : L + 1 ≤ N) (hr : n + 1 + L ≤ 2 * N) :
    n + 1 + L + padZeros N L n ≤ 2 * N := by
  rw [← padded_eq hN hL hr]
  rcases Nat.lt_or_ge n N with h | h
  · rw [Nat.div_eq_of_lt h]; split <;> omega
  · have h2 : n % N = n - N := by rw [Nat.mod_eq_sub_mod h, Nat.mod_eq_of_lt (by omega)]
    rw [Nat.div_eq_of_lt_le (k := 1) (by omega) (by omega), h2]; split <;> omega

theorem setSlice!_eq {α : Type} (s s' : List α) (i : Nat) (h : i + s'.length ≤ s.length) :
    s.setSlice! i s' = s.take i ++ s' ++ s.drop (i + s'.length) := by
  simp only [List.setSlice!]
  rw [Nat.min_eq_left (by omega), List.take_length]

/-- What `pad` writes into its zeroed buffer of `P` bytes. -/
theorem pad_list (r len : List U8) (P : Nat) (hP : r.length + 1 + len.length ≤ P) :
    (((List.replicate P 0#u8).setSlice! 0 r).set r.length 128#u8).setSlice! (P - len.length) len =
      r ++ [128#u8] ++ List.replicate (P - len.length - 1 - r.length) 0#u8 ++ len := by
  obtain ⟨Z, rfl⟩ : ∃ Z, P = r.length + 1 + Z + len.length :=
    ⟨P - len.length - 1 - r.length, by omega⟩
  have hA : (List.replicate (r.length + 1 + Z + len.length) 0#u8).setSlice! 0 r =
      r ++ List.replicate (Z + len.length + 1) 0#u8 := by
    rw [setSlice!_eq _ _ _ (by simp <;> omega)]
    simp only [List.take_zero, List.nil_append, Nat.zero_add, List.drop_replicate]
    congr 2
    omega
  have hB : (r ++ List.replicate (Z + len.length + 1) 0#u8).set r.length 128#u8 =
      (r ++ 128#u8 :: List.replicate Z 0#u8) ++ List.replicate len.length 0#u8 := by
    rw [List.set_append_right _ _ (by simp), Nat.sub_self, List.replicate_succ,
      List.set_cons_zero, List.replicate_add]
    simp
  have hC : r.length + 1 + Z + len.length - len.length =
      (r ++ 128#u8 :: List.replicate Z 0#u8).length := by simp; omega
  rw [hA, hB, hC, setSlice!_eq _ _ _ (by simp; omega)]
  rw [List.take_left', List.drop_eq_nil_of_le (by simp; omega)]
  · have : (r ++ 128#u8 :: List.replicate Z 0#u8).length - 1 - r.length = Z := by simp
    rw [this]
    simp
  · rfl

theorem pad_spec {N L : Usize} (rest : Slice U8) (length : Std.Array U8 L)
    (hN : 0 < N.val) (hN2 : 2 * N.val ≤ Usize.max) (hL : L.val + 1 ≤ N.val)
    (hr : rest.length + 1 + L.val ≤ 2 * N.val) :
    low.generic.blockwise.pad rest length (Std.Array.repeat 2#usize (Std.Array.repeat N 0#u8))
      ⦃ s _ => s.val = rest.val ++ [128#u8] ++ List.replicate (padZeros N L rest.length) 0#u8 ++
        length.val ⦄ := by
  unfold low.generic.blockwise.pad
  have hlen : rest.len.val = rest.length := by simp [Slice.len, Slice.length]
  have hpad := padded_eq hN hL hr
  have hP2 := padded_le hN hL hr
  have hd : rest.length / N.val ≤ 1 :=
    Nat.le_of_lt_succ (Nat.div_lt_of_lt_mul (by omega))
  have hdm := Nat.div_mul_le_self rest.length N.val
  have hzero : ((Std.Array.repeat 2#usize (Std.Array.repeat N 0#u8)).val.map (·.val)).flatten =
      List.replicate (2 * N.val) 0#u8 := by
    simp only [Std.Array.repeat, Std.Array.from_val, Nat.two_mul]
    simp [List.replicate_succ]
  step*
  apply WP.spec_bind (Pₘ := fun (padded : Usize) =>
    padded.val = rest.length + 1 + L.val + padZeros N L rest.length)
  · have hxN : rest.length / N.val * N.val ≤ N.val :=
      (Nat.mul_le_mul_right _ hd).trans (by simp)
    split
    · rename_i hc
      have hc' : rest.length % N.val + 1 + L.val ≤ N.val := by
        have := hc; simp only [UScalar.le_equiv] at this; simp only [hlen] at *; omega
      step as ⟨x, hx⟩
      step as ⟨y, hy⟩
      step as ⟨z, hz⟩
      rw [hz, hy, hx, hlen, ← hpad, if_pos hc']
    · rename_i hc
      have hc' : ¬ rest.length % N.val + 1 + L.val ≤ N.val := by
        have := hc; simp only [UScalar.le_equiv] at this; simp only [hlen] at *; omega
      step as ⟨x, hx⟩
      step as ⟨y, hy⟩
      step as ⟨w, hw⟩
      step as ⟨z, hz⟩
      rw [hz, hy, hx, hlen, hw, ← hpad, if_neg hc']
  · intro padded hP
    step*
    · simp only [s4_post1, last3_post, s5_post, Slice.length, Slice.set_val_eq, List.length_set,
        s2_post2, List.length_setSlice!, last1_post1.symm.trans rfl, i6_post, Std.Array.to_slice,
        Slice.from_val]
      have h1 := last1_post1
      simp only [Slice.length] at h1 hP
      rw [h1]
      simp
      omega
    · have hs1 : s1.val = List.replicate (2 * N.val) 0#u8 := by rw [s1_post, s_post, hzero]
      have hl1 : last1.val = List.replicate padded.val 0#u8 := by
        rw [last1_post, hs1]; simp [List.slice]; omega
      rw [s4_post2, s6_post, s5_post, last3_post, Slice.set_val_eq, s2_post2, s3_post, hl1, i6_post]
      have hL' : length.val.length = L.val := by simp
      have hr' : rest.len.val = rest.val.length := hlen
      rw [hr', ← hL', Std.Array.to_slice]
      simp only [Slice.length] at hP
      have hz : padded.val - length.val.length - 1 - rest.val.length =
          padZeros N length.val.length rest.val.length := by rw [hL']; omega
      rw [Slice.from_val, pad_list _ _ _ (by rw [hL']; omega), hz]

end rind.x86_64
