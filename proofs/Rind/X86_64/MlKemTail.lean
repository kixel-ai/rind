import Rind.X86_64.MlKemCoding
import Rind.X86_64.Sha3
import Rind.MlKemSample
open Aeneas Aeneas.Std Result rind.spec Spec Spec.MLKEM rind.spec.mlkem

/-!
# What ML-KEM's matrix sampling runs on every target

`tail_case` fills a polynomial's rest from SHAKE128 a block at a time
(`tail_case_spec`), and `shake_input` and `next_index` lay out each
polynomial's SHAKE128 input (`shake_input_pos`, `next_index_spec`):
the Rust that `Rind.Aarch64.MlKemSample` proves aarch64's `sample_ntt` from
and `Rind.X86_64.MlKemSample8x` x86_64's eight-way sampling.
`admin/prove` writes aarch64's copy from this file by renaming the target.
-/

namespace rind.x86_64

namespace MlKemTail

open MlKemCoding

/-! ## Filling an output with candidates -/

/-- `out` holds `done` candidates of `W` from `base`: every one `W` has past
`base`, or as many as `out` holds. -/
def Filled (W : List ℕ) (base : ℕ) (out : List I16) (done : ℕ) : Prop :=
  done ≤ out.length ∧ base + done = min (base + out.length) W.length ∧
    ∀ k < done, (out[k]!).val = ((W[base + k]! : ℕ) : ℤ)

/-- A candidate written where there is room. -/
theorem filled_push (W : List ℕ) (base : ℕ) (out : List I16) (done x : ℕ) (v : I16) (hv : v.val = x)
    (h : Filled W base out done) (hd : done < out.length) :
    Filled (W ++ [x]) base (out.set done v) (done + 1) := by
  obtain ⟨h1, h2, h3⟩ := h
  have hW : W.length = base + done := by omega
  refine ⟨by simp; omega, by simp; omega, fun k hk => ?_⟩
  by_cases hkd : k = done
  · subst hkd
    rw [getElem!_pos _ k (by simp; omega), List.getElem_set_self, hv,
      show base + k = W.length + 0 by omega]
    simp
  · rw [getElem!_pos _ k (by simp; omega), List.getElem_set_ne (Ne.symm hkd), ← getElem!_pos _ k (by omega),
      h3 k (by omega), getElem!_pos _ (base + k) (by omega), getElem!_pos _ (base + k) (by simp; omega),
      List.getElem_append_left]

/-- Candidates past a full `out`. -/
theorem filled_full (W K : List ℕ) (base : ℕ) (out : List I16) (done : ℕ)
    (h : Filled W base out done) (hd : ¬ done < out.length) : Filled (W ++ K) base out done := by
  obtain ⟨h1, h2, h3⟩ := h
  refine ⟨h1, by simp; omega, fun k hk => ?_⟩
  rw [h3 k hk, getElem!_pos _ (base + k) (by omega), getElem!_pos _ (base + k) (by simp; omega),
    List.getElem_append_left]

/-! ## `tail_case` -/

theorem q_eq : mid.mlkem.Q = 3329#i16 := by unfold mid.mlkem.Q; rfl

/-- A `u16` below `2 ^ 15`, as an `i16`, holds its value. -/
theorem hcast16 (x : U16) (h : x.val < 2 ^ 15) : (UScalar.hcast .I16 x).val = x.val := by
  rw [UScalar.hcast_val_eq]
  exact Int.bmod_eq_of_le (by simp) (by simp; omega)

/-- `u16::from_le_bytes` of two bytes. -/
theorem u16_of_bytes (b0 b1 : U8) (y : U16) {h}
    (hy : y.bv = (BitVec.fromLEBytes ((Std.Array.make 2#usize [b0, b1]).val.map U8.bv)).cast h) :
    y.val = b0.val + 256 * b1.val := by
  show y.bv.toNat = _
  rw [hy, BitVec.toNat_cast, toNat_fromLEBytes]
  simp [Std.Array.make, Nat.ofDigits_cons]

/-- Block `c` of SHAKE128's output on `M`. -/
def Block (M : List Byte) (c : ℕ) (bytes : List U8) : Prop :=
  ∀ i < 168, (bytes[i]!).bv = xofByte M (168 * c + i)

/-- `keep` of three bytes, as `tail_case` reads them. -/
theorem keep_bv (b0 b1 b2 : U8) :
    keep b0.bv b1.bv b2.bv =
      (if b0.val + 256 * (b1.val % 16) < q then [b0.val + 256 * (b1.val % 16)] else []) ++
        (if b1.val / 16 + 16 * b2.val < q then [b1.val / 16 + 16 * b2.val] else []) := by
  simp only [keep, Byte.val, UScalar.bv_toNat]

/-- The inner loop of `tail_case` writes the candidates of one block. -/
theorem tail_inner_spec (M : List Byte) (c : ℕ) (bytes : Std.Array U8 168#usize) (hb : Block M c bytes.val)
    (base : ℕ) (iter : core.ops.range.Range Usize) (he : iter.end.val = 56) (hs : iter.start.val ≤ 56)
    (output : Slice I16) (done : Usize)
    (hf : Filled (acc M (3 * (56 * c + iter.start.val))) base output.val done.val) :
    mid.mlkem.sample_ntt.tail_case_loop0_loop0 iter output done bytes ⦃ r =>
      r.1.length = output.length ∧ Filled (acc M (3 * (56 * c + 56))) base r.1.val r.2.val ⦄ := by
  unfold mid.mlkem.sample_ntt.tail_case_loop0_loop0
  apply WP.spec_mono (range_loop 56 (fun i (s : Slice I16 × Usize) =>
    s.1.length = output.length ∧ Filled (acc M (3 * (56 * c + i))) base s.1.val s.2.val) _ ?_
    iter (output, done) he hs ⟨rfl, hf⟩)
  · intro r hr; exact hr
  · rintro it ⟨out, d⟩ he' hs' ⟨hl, hinv⟩
    simp only at hl hinv ⊢
    unfold mid.mlkem.sample_ntt.tail_case_loop0_loop0.body
    step as ⟨o', it1, ho, he1⟩
    split_ifs at ho with hlt
    · obtain ⟨rfl, hst⟩ := ho
      simp only
      step as ⟨i, hi⟩
      step as ⟨b0, hb0⟩
      step as ⟨i1, hi1⟩
      step as ⟨b1, hb1⟩
      step as ⟨i2, hi2⟩
      step as ⟨b2, hb2⟩
      step as ⟨i3, hi3⟩
      step as ⟨i4, hi4⟩
      step as ⟨d1, hd1⟩
      step as ⟨i5, hi5⟩
      step as ⟨i6, hi6⟩
      step as ⟨d2, hd2⟩
      have ht : it.start.val < 56 := by omega
      have hx (k : ℕ) (hk : k < 3) (b : U8) (hb' : b = bytes.val[3 * it.start.val + k]!) :
          b.bv = xofByte M (3 * (56 * c + it.start.val) + k) := by
        rw [hb', hb _ (by omega)]
        congr 1
        ring
      have hx0 := hx 0 (by omega) b0 (by rw [hb0, getElem!_pos bytes.val _ (by simp; omega)]; simp [hi])
      have hx1 := hx 1 (by omega) b1 (by rw [hb1, getElem!_pos bytes.val _ (by simp; omega)]; simp [hi1, hi])
      have hx2 := hx 2 (by omega) b2 (by rw [hb2, getElem!_pos bytes.val _ (by simp; omega)]; simp [hi2, hi])
      simp only [Nat.add_zero] at hx0
      have hsucc := acc_succ M (56 * c + it.start.val)
      rw [← hx0, ← hx1, ← hx2, keep_bv] at hsucc
      have h0 : b0.val < 256 := b0.hBounds
      have h1 : b1.val < 256 := b1.hBounds
      have h2 : b2.val < 256 := b2.hBounds
      have hi3v := u16_of_bytes b0 b1 i3 hi3
      have hi5v := u16_of_bytes b1 b2 i5 hi5
      have hi4v : i4.val = b0.val + 256 * (b1.val % 16) := by
        rw [hi4, UScalar.val_and, show (4095#u16).val = 2 ^ 12 - 1 from rfl, Nat.and_two_pow_sub_one_eq_mod, hi3v]
        omega
      have hi6v : i6.val = b1.val / 16 + 16 * b2.val := by
        rw [hi6, hi5v, Nat.shiftRight_eq_div_pow]
        omega
      have hd1v : d1.val = ((b0.val + 256 * (b1.val % 16) : ℕ) : ℤ) := by
        rw [hd1, hcast16 _ (by omega), hi4v]
      have hd2v : d2.val = ((b1.val / 16 + 16 * b2.val : ℕ) : ℤ) := by
        rw [hd2, hcast16 _ (by omega), hi6v]
      generalize hW : acc M (3 * (56 * c + it.start.val)) = W at hinv hsucc
      generalize b0.val + 256 * (b1.val % 16) = x1 at hd1v hsucc
      generalize b1.val / 16 + 16 * b2.val = x2 at hd2v hsucc
      apply WP.spec_bind (Pₘ := fun (r : Slice I16 × Usize × core.ops.range.Range Usize) =>
        r.2.2 = it1 ∧ r.1.length = output.length ∧
          Filled (W ++ if x1 < q then [x1] else []) base r.1.val r.2.1.val)
      · split
        · rename_i hq
          rw [q_eq] at hq
          have hc : x1 < q := by
            have : d1.val < 3329 := by scalar_tac
            show x1 < 3329; omega
          simp only [hc, ite_true]
          split
          · rename_i hdl
            have hdl' : d.val < out.length := by scalar_tac
            step as ⟨s1, hs1⟩
            step as ⟨d3, hd3⟩
            refine ⟨by rw [hs1, Slice.set_length]; exact hl, ?_⟩
            rw [hs1, Slice.set_val_eq, hd3]
            exact filled_push W base out.val d.val x1 d1 hd1v hinv hdl'
          · rename_i hdl
            have hdl' : ¬ d.val < out.length := by scalar_tac
            simp only [bind_ok]
            exact (WP.spec_ok _).2 ⟨rfl, hl, filled_full W [x1] base out.val d.val hinv hdl'⟩
        · rename_i hq
          rw [q_eq] at hq
          have hc : ¬ x1 < q := by
            have : ¬ d1.val < 3329 := by scalar_tac
            show ¬ x1 < 3329; omega
          simp only [hc, ite_false, List.append_nil]
          exact (WP.spec_ok _).2 ⟨rfl, hl, hinv⟩
      · rintro ⟨out1, d', it2⟩ ⟨hit, hl1, hf1⟩
        simp only at hit hl1 hf1 ⊢
        subst it2
        simp only [uncurry_apply_pair]
        have hfin (out2 : Slice I16) (d'' : Usize) (hl2 : out2.length = output.length)
            (hf2 : Filled (W ++ (if x1 < q then [x1] else []) ++ if x2 < q then [x2] else []) base out2.val d''.val) :
            it1.end.val = 56 ∧ it1.start.val = it.start.val + 1 ∧ it.start.val < 56 ∧
              out2.length = output.length ∧
              Filled (acc M (3 * (56 * c + it1.start.val))) base out2.val d''.val := by
          refine ⟨by rw [he1]; exact he', hst, ht, hl2, ?_⟩
          rw [hst, show 56 * c + (it.start.val + 1) = 56 * c + it.start.val + 1 by ring, hsucc, ← List.append_assoc]
          exact hf2
        split
        · rename_i hq
          rw [q_eq] at hq
          have hc : x2 < q := by
            have : d2.val < 3329 := by scalar_tac
            show x2 < 3329; omega
          split
          · rename_i hdl
            have hdl' : d'.val < out1.length := by scalar_tac
            step as ⟨s1, hs1⟩
            step as ⟨d3, hd3⟩
            refine hfin s1 d3 (by rw [hs1, Slice.set_length]; exact hl1) ?_
            rw [hs1, Slice.set_val_eq, hd3]
            simp only [hc, ↓reduceIte]
            exact filled_push _ base out1.val d'.val x2 d2 hd2v hf1 hdl'
          · rename_i hdl
            have hdl' : ¬ d'.val < out1.length := by scalar_tac
            apply (WP.spec_ok _).2
            refine hfin _ _ hl1 ?_
            simp only [hc, ↓reduceIte]
            exact filled_full _ [x2] base out1.val d'.val hf1 hdl'
        · rename_i hq
          rw [q_eq] at hq
          have hc : ¬ x2 < q := by
            have : ¬ d2.val < 3329 := by scalar_tac
            show ¬ x2 < 3329; omega
          apply (WP.spec_ok _).2
          refine hfin _ _ hl1 ?_
          simp only [hc, ↓reduceIte, List.append_nil]
          exact hf1
    · obtain ⟨rfl, hst⟩ := ho
      apply (WP.spec_ok _).2
      have : it.start.val = 56 := by omega
      rw [this] at hinv
      exact ⟨hl, hinv⟩

/-- The block `SqueezingSponge::squeeze` reads after `c` blocks. -/
theorem block_of_squeeze (M : List Byte) (c : ℕ) (out : List U8)
    (hout : bv out = (sponge 168 shakePad M (168 * c + 168)).drop (168 * c)) : Block M c out := by
  intro i hi
  rw [← getElem!_bv, hout, show sponge 168 shakePad M (168 * c + 168) =
    (List.range (168 * c + 168)).map (xofByte M) from rfl, getElem!_pos _ i (by simp; omega)]
  simp

/-- What a turn of `tail_case`'s loop after block `c` leaves: the next
block's candidates, or `output` filled. -/
def TailStep (M : List Byte) (T base c : ℕ) (output : Slice I16) :
    ControlFlow (mid.sha3.SqueezingSponge 168#usize × Slice I16 × Usize)
      (mid.sha3.SqueezingSponge 168#usize × Slice I16) → Prop
  | .cont x => Squeezing x.1 shakePad M (c + 1) ∧ x.2.1.length = output.length ∧
      Filled (acc M (168 * (c + 1))) base x.2.1.val x.2.2.val ∧ 56 * c < T
  | .done y => y.2.length = output.length ∧
      ∀ k < output.length, (y.2.val[k]!).val = (((acc M (3 * T))[base + k]! : ℕ) : ℤ)

/-- `tail_case`'s loop, from block `c` of SHAKE128 on `M`, fills `output`
with the candidates past `base`, given that the first `3 * T` bytes hold
enough of them. -/
theorem tail_loop_spec (h : RunsSha3) (M : List Byte) (T base : ℕ) (n : ℕ) :
    ∀ c, T - 56 * c = n → ∀ (sponge : mid.sha3.SqueezingSponge 168#usize) (output : Slice I16) (done : Usize),
      Squeezing sponge shakePad M c → Filled (acc M (168 * c)) base output.val done.val →
      base + output.length ≤ (acc M (3 * T)).length →
      mid.mlkem.sample_ntt.tail_case_loop0 sponge output done ⦃ r =>
        r.2.length = output.length ∧
          ∀ k < output.length, (r.2.val[k]!).val = (((acc M (3 * T))[base + k]! : ℕ) : ℤ) ⦄ := by
  induction n using Nat.strong_induction_on with
  | _ n ih =>
  intro c hn sponge output done hs hf hT
  unfold mid.mlkem.sample_ntt.tail_case_loop0
  unfold loop
  apply WP.spec_bind (Pₘ := TailStep M T base c output)
  · unfold mid.mlkem.sample_ntt.tail_case_loop0.body
    dsimp only
    split
    · rename_i hlt
      have hlt' : done.val < output.length := by scalar_tac
      step with Std.Array.to_slice_mut_spec as ⟨s, back, hsv, hback⟩
      have hsl : s.length = 168 := by simp [Slice.length, hsv]
      step with squeezing_squeeze_spec h (R := 168#usize) (by decide) sponge shakePad M c hs s
        as ⟨sp1, s1, hl1, hout1, hsq1⟩
      step with shake128_r_bytes as ⟨i1, hi1⟩
      step as ⟨i2, hi2⟩
      have hbv : (back s1).val = s1.val := by
        rw [hback, Std.Array.from_slice_val _ _ (by rw [← Slice.length, hl1, hsl]; rfl)]
      have hb : Block M c (back s1).val := by
        rw [hbv]
        refine block_of_squeeze M c s1.val ?_
        rw [hout1, hsl]
      have hf0 : Filled (acc M (3 * (56 * c + 0))) base output.val done.val := by
        rw [show 3 * (56 * c + 0) = 168 * c by ring]; exact hf
      step with tail_inner_spec M c (back s1) hb base { start := 0#usize, «end» := i2 }
        (by simp; omega) (by simp) output done hf0 as ⟨out1, d1, hl2, hf2⟩
      refine ⟨?_, hl2, ?_, ?_⟩
      · rw [hsl] at hsq1; exact hsq1
      · rw [show 168 * (c + 1) = 3 * (56 * c + 56) by ring]; exact hf2
      · by_contra hc
        have := acc_length_mono M (show 3 * T ≤ 168 * c by omega)
        have hol : output.length = output.val.length := rfl
        obtain ⟨_, hf2', _⟩ := hf
        omega
    · rename_i hlt
      have hlt' : ¬ done.val < output.length := by scalar_tac
      apply (WP.spec_ok _).2
      obtain ⟨hd, hb, hv⟩ := hf
      have hol : output.length = output.val.length := rfl
      refine ⟨rfl, fun k hk => ?_⟩
      rw [hv k (by omega), acc_agree M (168 * c) (3 * T) (base + k) (by omega) (by omega)]
  · rintro (⟨s', out', d'⟩ | ⟨s', out'⟩) hr
    · obtain ⟨hs', hl', hf', hc⟩ := hr
      have := ih (T - 56 * (c + 1)) (by omega) (c + 1) rfl s' out' d' hs' hf' (by rw [hl']; exact hT)
      unfold mid.mlkem.sample_ntt.tail_case_loop0 at this
      rw [hl'] at this
      exact this
    · exact (WP.spec_ok _).2 hr

/-- `tail_case` fills `output` with the candidates after those of the first
`c` blocks. -/
theorem tail_case_spec (h : RunsSha3) (M : List Byte) (T c : ℕ) (sponge : mid.sha3.SqueezingSponge 168#usize)
    (hs : Squeezing sponge shakePad M c) (output : Slice I16)
    (hT : (acc M (168 * c)).length + output.length ≤ (acc M (3 * T)).length) :
    mid.mlkem.sample_ntt.tail_case sponge output ⦃ r =>
      r.2.length = output.length ∧ ∀ k < output.length,
        (r.2.val[k]!).val = (((acc M (3 * T))[(acc M (168 * c)).length + k]! : ℕ) : ℤ) ⦄ :=
  tail_loop_spec h M T _ _ c rfl sponge output 0#usize hs ⟨by simp, by simp, fun k hk => by simp at hk⟩ hT


/-- `out` holds SHAKE128's first 256 candidates below `q` on `M`. -/
def Sampled (M : List Byte) (out : List I16) : Prop :=
  ∀ k < 256, (out[k]!).val = (((sampled M)[k]! : ℕ) : ℤ)

/-- `shake_input` lays out `ρ`, the two indices, and SHAKE128's padding. -/
theorem shake_input_spec (rho : Std.Array U8 32#usize) (transposed : Bool) (i j : U8) :
    mid.mlkem.sample_ntt.shake_input rho transposed i j ⦃ input =>
      bv input.val = (bv rho.val ++ if transposed then [i.bv, j.bv] else [j.bv, i.bv]) ++
        shakePad :: List.replicate 5 0 ⦄ := by
  unfold mid.mlkem.sample_ntt.shake_input
  step as ⟨s, back, hs, hsl, hback⟩
  step as ⟨s1, hs1⟩
  step as ⟨s2, hs2⟩
  have hr : rho.val.length = 32 := rho.property
  have hb : (back s2).val = rho.val ++ List.replicate 8 0#u8 := by
    rw [hback, hs2, hs1, Std.Array.val_to_slice]
    simp [List.setSlice!, hr]
  split
  · step as ⟨a, ha⟩
    step as ⟨a1, ha1⟩
    step as ⟨a2, ha2⟩
    rw [ha2, ha1, ha, shake_pad_byte_eq]
    simp only [Std.Array.set_val_eq, hb]
    simp [hr, bv, List.replicate]
    rfl
  · step as ⟨a, ha⟩
    step as ⟨a1, ha1⟩
    step as ⟨a2, ha2⟩
    rw [ha2, ha1, ha, shake_pad_byte_eq]
    simp only [Std.Array.set_val_eq, hb]
    simp [hr, bv, List.replicate]
    rfl

/-- The SHAKE128 input of polynomial `p` of a `k` by `k` matrix, row by row:
`ρ`, then its column and row, or its row and column for the transpose. -/
def matMsg (rho : List Byte) (transposed : Bool) (k p : ℕ) : List Byte :=
  rho ++ if transposed then [((p / k : ℕ) : Byte), ((p % k : ℕ) : Byte)]
    else [((p % k : ℕ) : Byte), ((p / k : ℕ) : Byte)]

theorem matMsg_length (rho : List Byte) (transposed : Bool) (k p : ℕ) :
    (matMsg rho transposed k p).length = rho.length + 2 := by
  unfold matMsg; split <;> simp

theorem u8_bv (x : U8) (n : ℕ) (h : x.val = n) : x.bv = (n : Byte) := by
  apply BitVec.eq_of_toNat_eq
  show x.val = _
  rw [BitVec.natCast_eq_ofNat, BitVec.toNat_ofNat, ← h]
  exact (Nat.mod_eq_of_lt (by scalar_tac)).symm

/-- The position after `p`: the next column, or the next row's first. -/
theorem next_pos (k p : ℕ) (hk : 0 < k) :
    (p + 1) / k = (if p % k + 1 = k then p / k + 1 else p / k) ∧
      (p + 1) % k = (if p % k + 1 = k then 0 else p % k + 1) := by
  have hdm := Nat.div_add_mod p k
  split
  · have : p + 1 = k * (p / k + 1) := by rw [Nat.mul_add, Nat.mul_one]; omega
    rw [this, Nat.mul_div_cancel_left _ hk, Nat.mul_mod_right]
    exact ⟨rfl, rfl⟩
  · have hlt : p % k + 1 < k := by have := Nat.mod_lt p hk; omega
    have : p + 1 = (p % k + 1) + k * (p / k) := by omega
    rw [this, Nat.add_mul_div_left _ _ hk, Nat.div_eq_of_lt hlt, Nat.add_mul_mod_self_left,
      Nat.mod_eq_of_lt hlt]
    exact ⟨by omega, rfl⟩

/-- `next_index` steps from position `p` of a `k` by `k` matrix to `p + 1`. -/
theorem next_index_spec (k : Usize) (hk : 0 < k.val ∧ k.val ≤ 4) (p : ℕ) (hp : p < k.val * k.val)
    (i j : U8) (hi : i.val = p / k.val) (hj : j.val = p % k.val) :
    mid.mlkem.sample_ntt.next_index k i j ⦃ r =>
      r.1.val = (p + 1) / k.val ∧ r.2.val = (p + 1) % k.val ⦄ := by
  unfold mid.mlkem.sample_ntt.next_index
  have hik : p / k.val < k.val := Nat.div_lt_of_lt_mul hp
  have hjk : p % k.val < k.val := Nat.mod_lt p hk.1
  obtain ⟨hn1, hn2⟩ := next_pos k.val p hk.1
  step as ⟨i1, hi1⟩
  have hi1' : i1.val = j.val := by
    rw [hi1, UScalar.cast_val_eq]
    exact Nat.mod_eq_of_lt (by have := j.hBounds; scalar_tac)
  step as ⟨i2, hi2⟩
  split
  · rename_i he
    have he' : p % k.val + 1 = k.val := by
      have : i2.val = k.val := by rw [he]
      omega
    simp only [he', ↓reduceIte] at hn1 hn2
    step as ⟨i3, hi3⟩
    exact ⟨by rw [hn1]; omega, by rw [hn2]; rfl⟩
  · rename_i he
    have he' : ¬ p % k.val + 1 = k.val := by
      intro h'
      exact he (by scalar_tac)
    simp only [he', ↓reduceIte] at hn1 hn2
    step as ⟨i3, hi3⟩
    exact ⟨by rw [hn1]; omega, by rw [hn2]; omega⟩

/-- `shake_input` of position `p`'s row and column. -/
theorem shake_input_pos (rho : Std.Array U8 32#usize) (transposed : Bool) (k p : ℕ) (i j : U8)
    (hi : i.val = p / k) (hj : j.val = p % k) :
    mid.mlkem.sample_ntt.shake_input rho transposed i j ⦃ input =>
      bv input.val = matMsg (bv rho.val) transposed k p ++ shakePad :: List.replicate 5 0 ⦄ := by
  apply WP.spec_mono (shake_input_spec rho transposed i j)
  intro input h'
  rw [h', u8_bv i _ hi, u8_bv j _ hj]
  rfl

/-- `out`'s first `n` polynomials are those `SampleNTT` gives the matrix's. -/
def MatSampled (rho : List Byte) (transposed : Bool) (k n : ℕ) (out : List (Std.Array I16 256#usize)) : Prop :=
  ∀ p < n, Sampled (matMsg rho transposed k p) (out[p]!).val

end MlKemTail

end rind.x86_64
