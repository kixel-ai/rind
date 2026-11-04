import Rind.X86_64.S2nBignum
import Rind.X86_64.SignatureDispatch
import Rind.X86_64.Sha512
import Rind.X86_64.X25519
open Aeneas Aeneas.Std Result rind.spec

/-!
# Ed25519, proven from rind's signature API to s2n-bignum's contracts

The `ed25519_*` theorems state what the signature API returns for Ed25519, in
terms of `Rind.Ed25519`'s spec, through the dispatch
`Rind.X86_64.SignatureDispatch` models, and SHA-512 as `Rind.X86_64.Sha512`
proves it. `admin/prove` writes the aarch64 proof from this file by renaming
the target.
-/

namespace rind.x86_64

/-! ## Bytes and limbs -/

theorem leBytesOf_succ (k n : Nat) :
    leBytesOf (k + 1) n = @UScalar.mk UScalarTy.U8 (BitVec.ofNat 8 n) :: leBytesOf k (n / 256) := by
  simp only [leBytesOf, List.range_succ_eq_map, List.map_cons, List.map_map]
  refine congrArg₂ _ (by simp) (List.map_congr_left fun i _ => ?_)
  simp only [Function.comp, Nat.pow_succ, Nat.div_div_eq_div_mul, Nat.mul_comm]

/-- Bytes are the little-endian bytes of the number they encode. -/
theorem leBytesOf_leNat : ∀ b : List U8, leBytesOf b.length (leNat b) = b
  | [] => rfl
  | x :: xs => by
    have h : leNat (x :: xs) = x.val + 256 * leNat xs := by simp [leNat, Nat.ofDigits_cons]
    have hx : x.val < 256 := x.hBounds
    rw [List.length_cons, leBytesOf_succ, h, show (x.val + 256 * leNat xs) / 256 = leNat xs by omega,
      leBytesOf_leNat xs]
    congr 1
    cases x with
    | mk bv =>
      congr 1
      apply BitVec.eq_of_toNat_eq
      simp only [BitVec.toNat_ofNat] at hx ⊢
      simp only [UScalar.val] at hx ⊢
      omega

/-- Bytes of one length are equal when the numbers they encode are. -/
theorem leNat_inj (a b : List U8) (hl : a.length = b.length) (h : leNat a = leNat b) : a = b := by
  rw [← leBytesOf_leNat a, ← leBytesOf_leNat b, hl, h]

theorem leNat_lt (b : List U8) : leNat b < 256 ^ b.length := by
  unfold leNat
  have := Nat.ofDigits_lt_base_pow_length (b := 256) (l := b.map (·.val)) (by norm_num)
    (fun x hx => by
      obtain ⟨y, -, rfl⟩ := List.mem_map.mp hx
      exact y.hBounds)
  simpa using this

theorem wordsNat_lt (w : List U64) : wordsNat w < 2 ^ (64 * w.length) := by
  unfold wordsNat
  have := Nat.ofDigits_lt_base_pow_length (b := 2 ^ 64) (l := w.map (·.val)) (by norm_num)
    (fun x hx => by
      obtain ⟨y, -, rfl⟩ := List.mem_map.mp hx
      exact y.hBounds)
  simpa [pow_mul] using this

theorem le_to_u64x8_loop_spec
    (z : core.iter.adapters.zip.Zip (core.ops.range.Range Std.Usize) (core.slice.iter.ChunksExact Std.U8))
    (r : Std.Array Std.U64 8#usize) (F : List Nat)
    (hs : z.fst.start.val ≤ 8) (he : z.fst.end.val = 8)
    (hc : z.snd.chunks.length = 8 - z.fst.start.val)
    (h8 : ∀ c ∈ z.snd.chunks, c.length = 8)
    (hF : (r.val.take z.fst.start.val).map (·.val) ++ z.snd.chunks.map (leNat ·.val) = F) :
    mid.util.little_endian_to_u64x8_loop z r ⦃ r' => r'.val.map (·.val) = F ⦄ := by
  unfold mid.util.little_endian_to_u64x8_loop
  apply loop.spec_decr_nat (fun x => 8 - x.1.fst.start.val)
    (fun x => x.1.fst.start.val ≤ 8 ∧ x.1.fst.end.val = 8 ∧
      x.1.snd.chunks.length = 8 - x.1.fst.start.val ∧ (∀ c ∈ x.1.snd.chunks, c.length = 8) ∧
      (x.2.val.take x.1.fst.start.val).map (·.val) ++ x.1.snd.chunks.map (leNat ·.val) = F)
  · rintro ⟨⟨rg, ce⟩, r⟩ ⟨hs, he, hc, h8, hF⟩
    simp only at hs he hc h8 hF ⊢
    unfold mid.util.little_endian_to_u64x8_loop.body
    unfold core.iter.adapters.zip.Zip.Insts.CoreIterTraitsIteratorIteratorPair.next
    step*
    obtain ⟨o, rg'⟩ := x
    simp only at x_post x_post1
    split_ifs at x_post with hlt
    · obtain ⟨rfl, hst⟩ := x_post
      rcases hch : ce.chunks with _ | ⟨c, rest⟩
      · simp [hch] at hc; omega
      simp only [core.slice.iter.IteratorChunksExact.next, hch]
      have hc8 : c.length = 8 := h8 c (by simp [hch])
      step*
      · rcases r1 with a | _
        · exact ⟨a, rfl⟩
        · exact absurd hc8 r1_post
      · subst r1_post
        obtain ⟨hac, -⟩ := r1_post
        have hi : i.val = leNat c.val := by rw [val_of_fromLEBytes _ i i_post, hac]
        have hlen : (r.val).length = 8 := r.property
        refine ⟨by omega, by simp [x_post1, he], by simp [hch] at hc; omega,
          fun c' hc' => h8 c' (by simp [hch, hc']), ?_, by omega⟩
        rw [hst, a1_post, Std.Array.set_val_eq, List.take_add_one, List.getElem?_set_self (by omega),
          List.take_set_of_le (by omega)]
        rw [hch] at hF
        simp only [List.map_append, List.map_cons, Option.toList_some, List.map_nil, hi] at hF ⊢
        simpa using hF
    · obtain ⟨rfl, hst⟩ := x_post
      have hst4 : rg.start.val = 8 := by omega
      have hnil : ce.chunks = [] := List.eq_nil_of_length_eq_zero (by omega)
      have hlen : (r.val).length = 8 := r.property
      rw [hnil, hst4, List.take_of_length_le (by omega)] at hF
      simpa [WP.spec_ok] using hF
  · exact ⟨hs, he, hc, h8, hF⟩

@[step]
theorem le_to_u64x8_spec (b : Std.Array U8 64#usize) :
    mid.util.little_endian_to_u64x8 b ⦃ w => wordsNat w.val = leNat b.val ⦄ := by
  unfold mid.util.little_endian_to_u64x8
  simp only [core.slice.Slice.chunks_exact, show (8#usize).val > 0 by decide, ↓reduceDIte]
  step*
  simp only [core.iter.traits.collect.IntoIterator.Blanket.into_iter, ok.injEq] at iter_post
  subst s_post iter_post
  have hflat := toChunksExact_flatten 8 (by decide) b.val
  have hlen8 := toChunksExact_length 8 (by decide) b.val
  have hrem := toChunksExact_remainder 8 (by decide) b.val
  set C := (List.toChunksExact 8 (by decide) b.val).1
  have hb : b.val.length = 64 := b.property
  have hfl := length_flatten_of_length C 8 hlen8
  have hC : C.length = 8 := by
    have := congrArg List.length hflat
    simp only [List.length_append, hfl, hb] at this
    omega
  have hR : (List.toChunksExact 8 (by decide) b.val).2 = [] := by
    have := congrArg List.length hflat
    simp only [List.length_append, hfl, hb, hC] at this
    exact List.eq_nil_of_length_eq_zero (by omega)
  rw [hR, List.append_nil] at hflat
  apply WP.spec_mono (le_to_u64x8_loop_spec iter _ (C.map leNat) ?_ ?_ ?_ ?_ ?_)
  · intro w hw
    rw [wordsNat, hw, ← leNat_flatten C hlen8, hflat]
  · simp [iter_post1]
  · simp [iter_post1]
  · simpa [iter_post1, other'_post, C] using hC
  · simp only [other'_post, List.mem_map, List.mem_attach, true_and, Subtype.exists]
    rintro _ ⟨c, hc, rfl⟩
    simpa [C] using hlen8 c (by simpa [C] using hc)
  · simp [iter_post1, other'_post, C]

/-! ## Clamping and encoding, `mid::ed25519` -/

theorem clear_low3 (a : U64) : (a &&& ~~~7#u64).val = a.val / 8 * 8 := by
  have hb : a.bv &&& ~~~7#64 = (a.bv >>> 3) <<< 3 := by bv_decide
  have h : (a &&& ~~~7#u64).val = ((a.bv >>> 3) <<< 3).toNat := by
    rw [← hb]; rfl
  rw [h, BitVec.toNat_shiftLeft, BitVec.toNat_ushiftRight, Nat.shiftLeft_eq, Nat.shiftRight_eq_div_pow]
  have : a.bv.toNat = a.val := rfl
  have ha : a.val < 2 ^ 64 := a.hBounds
  rw [this]
  omega

theorem set_bit254 (d i3 i7 : U64) (h3 : i3.bv = 1#64 <<< 63) (h7 : i7.bv = 1#64 <<< 62) :
    ((d &&& ~~~i3) ||| i7).val = 2 ^ 62 + d.val % 2 ^ 62 := by
  have hb : (d.bv &&& ~~~i3.bv) ||| i7.bv = (d.bv &&& 0x3fffffffffffffff#64) + 0x4000000000000000#64 := by
    rw [h3, h7]; bv_decide
  have h : ((d &&& ~~~i3) ||| i7).val = ((d.bv &&& 0x3fffffffffffffff#64) + 0x4000000000000000#64).toNat := by
    rw [← hb]; rfl
  have : d.bv.toNat = d.val := rfl
  rw [h, BitVec.toNat_add, BitVec.toNat_and, this,
    show (0x3fffffffffffffff#64).toNat = 2 ^ 62 - 1 by decide, Nat.and_two_pow_sub_one_eq_mod]
  simp only [BitVec.toNat_ofNat]
  omega

@[step]
theorem clamp_spec (x : Std.Array U8 32#usize) :
    mid.ed25519.UnreducedScalar.clamp_from_le_bytes x ⦃ s => wordsNat s.val = edClamp (leNat x.val) ⦄ := by
  unfold mid.ed25519.UnreducedScalar.clamp_from_le_bytes
  step*
  have hl4 : x1.val.length = 4 := x1.property
  obtain ⟨l, hl⟩ : ∃ l, x1.val = l := ⟨_, rfl⟩
  rcases l with _ | ⟨a, _ | ⟨b, _ | ⟨c, _ | ⟨d, _ | ⟨e, l⟩⟩⟩⟩⟩ <;> simp [hl] at hl4
  have h2 : i2.val = a.val / 8 * 8 := by
    rw [i2_post, i_post, i1_post]; simp only [hl]; exact clear_low3 a
  have h8 : i8 = (d &&& ~~~i3) := by
    rw [i8_post, x3_post, ← i4_post]
    apply UScalar.eq_of_val_eq
    simp [Std.Array.set_val_eq, i6_post, i5_post, x2_post, hl]
  have h9 : i9.val = 2 ^ 62 + d.val % 2 ^ 62 := by
    rw [i9_post, h8]
    exact set_bit254 d i3 i7 (by simpa using i3_post1) (by simpa using i7_post1)
  have hW : leNat x.val = a.val + 2 ^ 64 * (b.val + 2 ^ 64 * (c.val + 2 ^ 64 * d.val)) := by
    rw [← x1_post, wordsNat_four _ (by simp [hl])]; simp [hl]
  have hX : wordsNat x4.val = i2.val + 2 ^ 64 * (b.val + 2 ^ 64 * (c.val + 2 ^ 64 * i9.val)) := by
    rw [wordsNat_four _ (by simp)]
    simp [x4_post, x3_post, x2_post, Std.Array.set_val_eq, hl]
  rw [hX, hW, edClamp, h2, h9]
  have ha : a.val < 2 ^ 64 := a.hBounds
  have hb : b.val < 2 ^ 64 := b.hBounds
  have hc : c.val < 2 ^ 64 := c.hBounds
  have hd : d.val < 2 ^ 64 := d.hBounds
  omega

theorem leNat_append (a b : List U8) : leNat (a ++ b) = leNat a + 256 ^ a.length * leNat b := by
  simp [leNat, Nat.ofDigits_append]

theorem setSlice!_at {α : Type _} (X R S : List α) (i : Nat) (hX : X.length = i)
    (h : S.length ≤ R.length) : (X ++ R).setSlice! i S = X ++ S ++ R.drop S.length := by
  have hmin : min S.length ((X ++ R).length - i) = S.length := by simp; omega
  simp only [List.setSlice!, hmin, ← hX, List.drop_append]
  simp [min_eq_left h]

theorem splice_top_bit (y3 xb i i1 y31 : U64) (hy : y3.val < 2 ^ 63)
    (hi : i.bv = y3.bv &&& 0x7fffffffffffffff#64) (hi1 : i1.bv = xb.bv <<< 63)
    (hy31 : y31.bv = i.bv ||| i1.bv) : y31.val = y3.val + 2 ^ 63 * (xb.val % 2) := by
  have hb : y31.bv = (y3.bv &&& 0x7fffffffffffffff#64) + ((xb.bv &&& 1#64) <<< 63) := by
    rw [hy31, hi, hi1]; bv_decide
  have h : y31.val = y31.bv.toNat := rfl
  have hy3 : y3.bv.toNat = y3.val := rfl
  have hxb : xb.bv.toNat = xb.val := rfl
  rw [h, hb, BitVec.toNat_add, BitVec.toNat_and, BitVec.toNat_shiftLeft, BitVec.toNat_and, hy3, hxb,
    show (0x7fffffffffffffff#64).toNat = 2 ^ 63 - 1 by decide, show (1#64).toNat = 2 ^ 1 - 1 by decide,
    Nat.and_two_pow_sub_one_eq_mod, Nat.and_two_pow_sub_one_eq_mod, Nat.shiftLeft_eq]
  have : xb.val % 2 < 2 := Nat.mod_lt _ (by norm_num)
  omega

/-- `compress` writes s2n-bignum's `ed25519_encode` of the point's coordinates,
for a y-coordinate below 2²⁵⁵. -/
@[step]
theorem point_compress_spec (p : Std.Array U64 8#usize) (hy : (pairNat p.val).2 < 2 ^ 255) :
    mid.ed25519.EdwardsPoint.compress p ⦃ c =>
      leNat c.val = 2 ^ 255 * ((pairNat p.val).1 % 2) + (pairNat p.val).2 ⦄ := by
  unfold mid.ed25519.EdwardsPoint.compress
  step*
  have hl8 : p.val.length = 8 := p.property
  obtain ⟨l, hl⟩ : ∃ l, p.val = l := ⟨_, rfl⟩
  rcases l with _ | ⟨x0, _ | ⟨x1, _ | ⟨x2, _ | ⟨x3, _ | ⟨w0, _ | ⟨w1, _ | ⟨w2, _ | ⟨w3, _ | ⟨e, l⟩⟩⟩⟩⟩⟩⟩⟩⟩ <;>
    simp [hl] at hl8
  simp only [hl, List.getElem_cons_succ, List.getElem_cons_zero] at xb_post y0_post y1_post y2_post y3_post
  subst xb_post y0_post y1_post y2_post y3_post
  have hp : pairNat p.val = (wordsNat [xb, x1, x2, x3], wordsNat [y0, y1, y2, y3]) := by
    simp [pairNat, hl]
  rw [hp] at hy ⊢
  simp only [wordsNat, List.map_cons, List.map_nil, Nat.ofDigits_cons, Nat.ofDigits_nil] at hy ⊢
  have h0 : y0.val < 2 ^ 64 := y0.hBounds
  have h1 : y1.val < 2 ^ 64 := y1.hBounds
  have h2 : y2.val < 2 ^ 64 := y2.hBounds
  have hw3 : y3.val < 2 ^ 63 := by omega
  have hy31 := splice_top_bit y3 xb i i1 y31 hw3 i_post1 i1_post1 y31_post1
  have hz : (Array.repeat 32#usize 0#u8).val = [] ++ List.replicate 32 0#u8 := by simp [Array.repeat]
  have ha : ∀ a : Std.Array U8 8#usize, a.val.length = 8 := fun a => a.property
  have hout : (index_mut_back3 s11).val = a1.val ++ a3.val ++ a5.val ++ a7.val := by
    rw [s9_post2, s6_post2, s3_post2, s_post2, hz, s11_post, s10_post, s8_post, s7_post, s5_post,
      s4_post, s2_post, s1_post]
    simp only [Array.val_to_slice]
    rw [setSlice!_at [] _ _ 0 rfl (by simp [ha])]
    rw [setSlice!_at _ _ _ 8 (by simp [ha]) (by simp [ha])]
    rw [setSlice!_at _ _ _ 16 (by simp [ha]) (by simp [ha])]
    rw [setSlice!_at _ _ _ 24 (by simp [ha]) (by simp [ha])]
    simp [ha]
  rw [hout, leNat_append, leNat_append, leNat_append]
  simp only [List.length_append, ha]
  rw [a1_post, a3_post, a5_post, a7_post, leNat_toLEBytes, leNat_toLEBytes, leNat_toLEBytes,
    leNat_toLEBytes, hy31]
  have : xb.val % 2 < 2 := Nat.mod_lt _ (by norm_num)
  omega

end rind.x86_64
