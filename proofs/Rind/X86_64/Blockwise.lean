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

/-- The padding of `x` bytes ends on a block boundary. -/
theorem pad_mod {N L : Nat} (x : Nat) (hN : 0 < N) : (x + 1 + L + padZeros N L x) % N = 0 := by
  unfold padZeros
  have hr := Nat.mod_lt (x + 1 + L) hN
  rw [Nat.add_mod, Nat.mod_mod]
  rcases Nat.eq_zero_or_pos ((x + 1 + L) % N) with h | h
  · rw [h, Nat.sub_zero, Nat.mod_self]; simp
  · rw [Nat.mod_eq_of_lt (show N - (x + 1 + L) % N < N by omega),
      show (x + 1 + L) % N + (N - (x + 1 + L) % N) = N by omega, Nat.mod_self]

/-- Dropping whole blocks off the front leaves the padding unchanged. -/
theorem padZeros_sub {N L n start : Nat} (h : start % N = 0) (hs : start ≤ n) :
    padZeros N L (n - start) = padZeros N L n := by
  unfold padZeros
  obtain ⟨q, rfl⟩ := Nat.dvd_of_mod_eq_zero h
  rw [show n + 1 + L = n - N * q + 1 + L + N * q by omega, Nat.add_mul_mod_self_left]

theorem compress_padded_spec {C S : Type} {N L : Usize}
    (inst : low.generic.blockwise.Compress C S) (R : List U8 → S → Prop) (bound : Nat)
    (hC : ∀ p s (b : Slice U8), R p s → b.length % N.val = 0 → p.length + b.length ≤ bound →
      inst.compress s b ⦃ s' => R (p ++ b.val) s' ⦄)
    (p : List U8) (message : Slice U8) (length : Std.Array U8 L) (state : S) (hR : R p state)
    (hN : 0 < N.val) (hN2 : 2 * N.val ≤ Usize.max) (hL : L.val + 1 ≤ N.val)
    (hb : p.length + message.length + 1 + L.val + padZeros N L message.length ≤ bound) :
    low.generic.blockwise.compress_padded N inst message length state ⦃ s' =>
      R (p ++ message.val ++ [128#u8] ++ List.replicate (padZeros N L message.length) 0#u8 ++
        length.val) s' ⦄ := by
  unfold low.generic.blockwise.compress_padded
  have hlen : message.len.val = message.length := by simp [Slice.len, Slice.length]
  have hmod := Nat.mod_add_div message.length N.val
  have hlt := Nat.mod_lt message.length hN
  step*
  apply WP.spec_bind (Pₘ := fun (start : Usize) => start.val % N.val = 0 ∧
    start.val ≤ message.length ∧ message.length - start.val + 1 + L.val ≤ 2 * N.val)
  · have hq : (N.val * (message.length / N.val)) % N.val = 0 := Nat.mul_mod_right _ _
    have hq1 : (N.val * (message.length / N.val) - N.val) % N.val = 0 := by
      rw [← Nat.mul_sub_one]; exact Nat.mul_mod_right _ _
    simp only [hlen] at tail_post
    split
    · rename_i hc
      have hc' : message.length % N.val + 1 + L.val ≤ N.val := by
        simp only [UScalar.le_equiv] at hc; omega
      split
      · rename_i hge
        have hge' : N.val ≤ message.length := by
          simp only [GE.ge, UScalar.le_equiv] at hge; omega
        have hNq : N.val ≤ N.val * (message.length / N.val) :=
          Nat.le_mul_of_pos_right _ (Nat.div_pos hge' hN)
        step as ⟨i5, h5⟩
        step as ⟨st, hst⟩
        have : st.val = N.val * (message.length / N.val) - N.val := by omega
        exact ⟨by rw [this]; exact hq1, by omega, by omega⟩
      · rename_i hge
        have hge' : ¬ N.val ≤ message.length := by
          simp only [GE.ge, UScalar.le_equiv] at hge; omega
        step as ⟨st, hst⟩
        have : st.val = N.val * (message.length / N.val) := by omega
        exact ⟨by rw [this]; exact hq, by omega, by omega⟩
    · rename_i hc
      have hc' : ¬ message.length % N.val + 1 + L.val ≤ N.val := by
        simp only [UScalar.le_equiv] at hc; omega
      step as ⟨st, hst⟩
      have : st.val = N.val * (message.length / N.val) := by omega
      exact ⟨by rw [this]; exact hq, by omega, by omega⟩
  · intro start ⟨hs0, hs1, hs2⟩
    step*
    apply WP.spec_bind (Pₘ := fun s1 => R (p ++ blocks.val) s1)
    · split
      · rename_i hb0
        have : blocks.val = [] := by
          rw [b_post] at hb0; exact List.eq_nil_of_length_eq_zero hb0
        simp only [this, List.append_nil, WP.spec_ok, hR]
      · exact hC _ _ _ hR (by rw [blocks_post]; exact hs0) (by rw [blocks_post]; omega)
    · intro s1 hs1R
      have hpz : padZeros N.val L.val rest.length = padZeros N.val L.val message.length := by
        rw [blocks_post1]; exact padZeros_sub hs0 hs1
      step with pad_spec rest length hN hN2 hL (by rw [blocks_post1]; omega) as ⟨s, _, hs⟩
      have hsl : s.length = rest.length + 1 + L.val + padZeros N.val L.val rest.length := by
        simp only [Slice.length] at *; rw [hs]; simp; omega
      apply WP.spec_mono (hC _ _ _ hs1R ?_ ?_)
      · intro s' h
        rw [hs, hpz, blocks_post3, blocks_post2] at h
        simp only [List.append_assoc] at h ⊢
        rw [← List.append_assoc (List.take _ _), List.take_append_drop] at h
        exact h
      · rw [hsl]; exact pad_mod _ hN
      · have h1 := blocks_post
        have h2 := blocks_post1
        have h3 := hsl
        have h4 := hpz
        simp only [List.length_append, Slice.length] at *
        omega

theorem pad_message_spec {N L : Usize} (message : Slice U8) (length : Std.Array U8 L)
    (hN : 0 < N.val) (hN2 : 2 * N.val ≤ Usize.max) (hL : L.val + 1 ≤ N.val) :
    low.generic.blockwise.pad_message message length
      (Std.Array.repeat 2#usize (Std.Array.repeat N 0#u8)) ⦃ r _ =>
      r.1.length % N.val = 0 ∧ r.2.length % N.val = 0 ∧
      r.1.val ++ r.2.val = message.val ++ [128#u8] ++
        List.replicate (padZeros N L message.length) 0#u8 ++ length.val ⦄ := by
  unfold low.generic.blockwise.pad_message
  have hlen : message.len.val = message.length := by simp [Slice.len, Slice.length]
  have hmod := Nat.mod_add_div message.length N.val
  have hlt := Nat.mod_lt message.length hN
  have hdm := Nat.div_mul_le_self message.length N.val
  step*
  have hst : i2.val = N.val * (message.length / N.val) := by
    rw [i2_post, i1_post, hlen, Nat.mul_comm]
  have hpz : padZeros N.val L.val rest.length = padZeros N.val L.val message.length := by
    rw [blocks_post1, hst]
    exact padZeros_sub (Nat.mul_mod_right _ _) (by omega)
  step with pad_spec rest length hN hN2 hL (by rw [blocks_post1, hst]; omega) as ⟨s, _, hs⟩
  refine ⟨by rw [blocks_post, hst]; exact Nat.mul_mod_right _ _, ?_, ?_⟩
  · have : s.length = rest.length + 1 + L.val + padZeros N.val L.val rest.length := by
      simp only [Slice.length] at *; rw [hs]; simp; omega
    rw [this]; exact pad_mod _ hN
  · rw [hs, hpz, blocks_post2, blocks_post3]
    simp only [List.append_assoc]
    rw [← List.append_assoc (List.take _ _), List.take_append_drop]

end rind.x86_64
