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
  simp only [List.setSlice!, ← hX, List.drop_append]
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

/-! ## Points, `Rind.Ed25519` -/

theorem edModEncode_lt (x : Int) : edModEncode x < p25519 := by
  unfold edModEncode
  have h0 := Int.emod_nonneg x (show (p25519 : Int) ≠ 0 by decide)
  have h1 := Int.emod_lt_of_pos x (show (0 : Int) < p25519 by decide)
  omega

theorem edModEncode_of_onCurve (x : Int) (h0 : 0 ≤ x) (h1 : x < p25519) : (edModEncode x : Int) = x := by
  unfold edModEncode
  rw [Int.emod_eq_of_lt h0 h1]
  omega

/-- The negation of a point of the group is in the group. -/
theorem edOnCurve_neg (P : EdPoint) (h : edOnCurve P) : edOnCurve (edNeg P) := by
  obtain ⟨x, y⟩ := P
  obtain ⟨-, -, hy0, hy1, he⟩ := h
  have hq : (-x) % (p25519 : Int) ≡ -x [ZMOD p25519] := Int.mod_modEq _ _
  have hq2 : ((-x) % (p25519 : Int)) ^ 2 ≡ x ^ 2 [ZMOD p25519] := by
    simpa [neg_sq] using hq.pow 2
  refine ⟨Int.emod_nonneg _ (by decide), Int.emod_lt_of_pos _ (by decide), hy0, hy1, ?_⟩
  show e25519 * ((-x) % (p25519 : Int)) ^ 2 + y ^ 2 ≡
    1 + d25519 * ((-x) % (p25519 : Int)) ^ 2 * y ^ 2 [ZMOD p25519]
  calc _ ≡ e25519 * x ^ 2 + y ^ 2 [ZMOD p25519] := (hq2.mul_left _).add_right _
    _ ≡ 1 + d25519 * x ^ 2 * y ^ 2 [ZMOD p25519] := he
    _ ≡ _ [ZMOD p25519] := ((hq2.symm.mul_left _).mul_right _).add_left _

/-- A valid encoding decodes to a point of the group that encodes as it. -/
theorem edDecode_spec (n : Nat) (h : edValidEncode n) :
    edOnCurve (edDecode n) ∧ edEncode (edDecode n) = n :=
  Classical.epsilon_spec h

/-- The coordinates `negate` writes for a point of the group are its
negation's. -/
theorem neg_decode (A : EdPoint) (hA : edOnCurve A) :
    edModDecodePair ((p25519 - edModEncode A.1) % p25519, edModEncode A.2) = edNeg A := by
  obtain ⟨x, y⟩ := A
  obtain ⟨hx0, hx1, hy0, hy1, -⟩ := hA
  have hx := edModEncode_of_onCurve x hx0 hx1
  have hy := edModEncode_of_onCurve y hy0 hy1
  have hp : p25519 = 57896044618658097711785492504343953926634992332820282019728792003956564819949 := by
    norm_num [p25519]
  simp only [edModDecodePair, edNeg, Prod.mk.injEq]
  simp only at hx1 hy1
  have he : edModEncode x < p25519 := edModEncode_lt x
  rw [hp] at hx1 hy1 he ⊢
  constructor <;> omega

/-! ## Hashing, `mid::ed25519::ed25519_digest` -/

theorem context_new_spec : mid.sha2.Sha512Context.new ⦃ c => Hashed sha512Iv c [] ⦄ := by
  unfold mid.sha2.Sha512Context.new
  step with sha512_initial_spec as ⟨st, hh, hn⟩
  exact resume_spec _ st hh hn

@[step]
theorem ed25519_digest_spec (h : RunsSha512) (x1 x2 x3 : Slice U8)
    (hl : x1.length + x2.length + x3.length < 2 ^ 64) :
    mid.ed25519.ed25519_digest x1 x2 x3 ⦃ d => d.val = sha512 (x1.val ++ x2.val ++ x3.val) ⦄ := by
  unfold mid.ed25519.ed25519_digest
  simp only [Slice.length] at hl
  step with context_new_spec as ⟨c, hc⟩
  step with context_update_spec h _ c [] x1 hc (by simp [Slice.length]; omega) as ⟨c1, hc1⟩
  step with context_update_spec h _ c1 _ x2 hc1 (by simp [Slice.length]; omega) as ⟨c2, hc2⟩
  step with context_update_spec h _ c2 _ x3 hc2 (by simp [Slice.length]; omega) as ⟨c3, hc3⟩
  step with context_finish_spec h _ c3 _ hc3 as ⟨d, hd⟩
  simpa [sha512] using hd

/-! ## Scalars, `mid::ed25519::Scalar` -/

@[step]
theorem reduce_spec (x : Std.Array U8 64#usize) :
    mid.ed25519.Scalar.reduce_from_le_bytes x ⦃ s => wordsNat s.val = leNat x.val % n25519 ⦄ := by
  unfold mid.ed25519.Scalar.reduce_from_le_bytes
  step*

theorem wordsNat_ORDER : wordsNat mid.ed25519.ORDER.val = n25519 := by
  unfold mid.ed25519.ORDER
  simp [wordsNat, Nat.ofDigits, n25519]

@[step]
theorem try_from_le_bytes_spec (x : Std.Array U8 32#usize) :
    mid.ed25519.Scalar.try_from_le_bytes x ⦃ o =>
      if leNat x.val < n25519 then ∃ s, o = some s ∧ wordsNat s.val = leNat x.val else o = none ⦄ := by
  unfold mid.ed25519.Scalar.try_from_le_bytes
  step*
  rw [s1_post, s2_post, Array.val_to_slice, Array.val_to_slice, s_post, wordsNat_ORDER] at i_post
  simp only [core.bool.Bool.then_some]
  split_ifs at i_post with hlt <;> simp_all

/-! ## Verification, `mid::ed25519::VerifyingKey` -/

/-- `<&[T; N]>::try_from(&[T])`, which Aeneas's library gives no spec. -/
theorem try_from_shared_spec {T : Type} (N : Usize) (s : Slice T) :
    core.array.TryFromSharedArraySlice.try_from N s ⦃ r =>
      if s.length = N.val then ∃ a, r = .Ok a ∧ a.val = s.val else ∃ e, r = .Err e ⦄ := by
  unfold core.array.TryFromSharedArraySlice.try_from
  have hl : s.len = N ↔ s.length = N.val := by
    rw [← Slice.len_val]
    exact ⟨fun h => by rw [h], fun h => UScalar.eq_of_val_eq h⟩
  by_cases h : s.len = N
  · simp [h, hl.mp h]
  · simp [h, mt hl.mpr h]

/-- `<[T; N]>::try_from(&[T])` of a slice of `N` elements. -/
@[step]
theorem try_from_copy_ok {T : Type} (N : Usize) (inst : core.marker.Copy T) (s : Slice T)
    (h : s.length = N.val) :
    core.array.TryFromArrayCopySlice.try_from N inst s ⦃ r => ∃ a, r = .Ok a ∧ a.val = s.val ⦄ := by
  apply WP.spec_mono (core.array.TryFromArrayCopySlice.try_from.step N inst s)
  rintro (a | e) hr
  · exact ⟨a, rfl, hr.1⟩
  · exact absurd h hr

/-- `<&[T; N]>::try_from(&[T])` of a slice of `N` elements. -/
@[step]
theorem try_from_shared_ok {T : Type} (N : Usize) (s : Slice T) (h : s.length = N.val) :
    core.array.TryFromSharedArraySlice.try_from N s ⦃ r => ∃ a, r = .Ok a ∧ a.val = s.val ⦄ := by
  apply WP.spec_mono (try_from_shared_spec N s)
  intro r hr
  simpa [h] using hr

@[step]
theorem negate_spec (p : Std.Array U64 8#usize) (hx : (pairNat p.val).1 ≤ p25519) :
    mid.ed25519.EdwardsPoint.negate p ⦃ q =>
      pairNat q.val = ((p25519 - (pairNat p.val).1) % p25519, (pairNat p.val).2) ⦄ := by
  unfold mid.ed25519.EdwardsPoint.negate
  step*
  simp only [r_post, core.result.Result.Ok.injEq] at *
  have hl8 : p.val.length = 8 := p.property
  have hn4 : x_neg1.val.length = 4 := x_neg1.property
  have hx4 : x.val = p.val.take 4 := by simp_all [List.slice, Array.val_to_slice]
  have hout : (index_mut_back1 s6).val = x_neg1.val ++ p.val.drop 4 := by
    have hz : (Array.repeat 8#usize 0#u64).val = [] ++ List.replicate 8 0#u64 := by simp [Array.repeat]
    rw [s4_post2, s1_post2, s6_post, s5_post, s3_post, s2_post, Array.val_to_slice, hz,
      setSlice!_at [] _ _ 0 rfl (by simp [hn4])]
    simp only [List.nil_append, Array.val_to_slice, hn4]
    rw [setSlice!_at _ _ _ 4 hn4 (by simp)]
    simp
  have hpx : wordsNat x.val = (pairNat p.val).1 := by simp [pairNat, hx4]
  rw [hout]
  simp only [pairNat, List.take_left' hn4, List.drop_left' hn4]
  rw [x_neg1_post (by rw [hpx]; exact hx), hpx]
  simp [pairNat]

/-- `&[u8] == [u8; N]`. -/
@[step]
theorem slice_eq_array_spec {N : Usize} (s : Slice U8) (a : Std.Array U8 N) :
    Shared0Slice.Insts.CoreCmpPartialEqArray.eq core.cmp.PartialEqU8 s a ⦃ b => b ↔ s.val = a.val ⦄ := by
  unfold Shared0Slice.Insts.CoreCmpPartialEqArray.eq
  apply WP.spec_mono (core.slice.cmp.PartialEqSlice.eq_homo_spec _ s a.to_slice
    (fun x y => by simp [core.cmp.PartialEqU8, liftFun2]))
  intro b hb
  rw [hb, Slice.eq_iff, Array.val_to_slice]

/-- `[u8] == [u8]`. -/
@[step]
theorem slice_eq_spec (s t : Slice U8) :
    core.slice.cmp.PartialEqSlice.eq core.cmp.PartialEqU8 s t ⦃ b => b ↔ s.val = t.val ⦄ := by
  apply WP.spec_mono (core.slice.cmp.PartialEqSlice.eq_homo_spec _ s t
    (fun x y => by simp [core.cmp.PartialEqU8, liftFun2]))
  intro b hb
  rw [hb, Slice.eq_iff]

@[step]
theorem scalarmuldouble_spec (h : Runs) (k : Std.Array U64 4#usize) (pt : Std.Array U64 8#usize)
    (b : Std.Array U64 4#usize) :
    mid.ed25519.EdwardsPoint.scalarmuldouble k pt b ⦃ r =>
      ∀ P, edOnCurve P → edModDecodePair (pairNat pt.val) = P →
        pairNat r.val = edModEncodePair (edMul (edPow P (wordsNat k.val)) (edPow edB (wordsNat b.val))) ⦄ := by
  unfold mid.ed25519.EdwardsPoint.scalarmuldouble
  step*

theorem edModEncode_lt_pow (x : Int) : edModEncode x < 2 ^ 255 :=
  lt_of_lt_of_le (edModEncode_lt x) (by norm_num [p25519])

/-- `compress` of the coordinates s2n-bignum writes for a point is its
encoding. -/
theorem compress_point_spec (p : Std.Array U64 8#usize) (P : EdPoint)
    (hp : pairNat p.val = edModEncodePair P) :
    mid.ed25519.EdwardsPoint.compress p ⦃ c => leNat c.val = edEncode P ⦄ := by
  apply WP.spec_mono (point_compress_spec p (by rw [hp]; exact edModEncode_lt_pow _))
  intro c hc
  rw [hc, hp]
  rfl

open Classical in
/-- `verify` with a key whose point is `A`, a point of the group, and whose
bytes are `vk.bytes`: RFC 8032's verification. -/
theorem mid_verify_spec (h : Runs) (hs : RunsSha512) (vk : mid.ed25519.VerifyingKey) (A : EdPoint)
    (hA : edOnCurve A) (hp : pairNat vk.point.val = edModEncodePair A)
    (sig : Std.Array U8 64#usize) (msg : Slice U8) (hm : msg.length + 64 < 2 ^ 64) :
    mid.ed25519.VerifyingKey.verify vk sig msg ⦃ r =>
      r = if ed25519Verifies A vk.bytes.val msg.val sig.val then
        (.Ok () : core.result.Result Unit error.Error) else .Err .BadSignature ⦄ := by
  unfold mid.ed25519.VerifyingKey.verify
  have hsig : sig.val.length = 64 := sig.property
  step*
  simp only [r_post, core.result.Result.Ok.injEq] at *
  have hs2 : s2.val = sig.val.drop 32 := by simp_all [Array.val_to_slice]
  have hr : r_sig.val = sig.val.take 32 := by simp_all [Array.val_to_slice]
  rw [hs2] at o_post
  by_cases hS : leNat (sig.val.drop 32) < n25519
  · simp only [hS, ↓reduceIte] at o_post
    obtain ⟨S, rfl, hSv⟩ := o_post
    simp only [core.option.Option.ok_or, core.result.Result.Insts.CoreOpsTry.branch]
    step as ⟨s3, hs3⟩
    step with ed25519_digest_spec hs r_sig s3 msg (by simp [Slice.length, hs3] at *; omega)
      as ⟨k, hk⟩
    step as ⟨k1, hk1⟩
    step with negate_spec vk.point (by rw [hp]; exact (edModEncode_lt _).le) as ⟨ep, hep⟩
    step as ⟨ep1, hep1⟩
    have hR := hep1 (edNeg A) (edOnCurve_neg A hA) (by rw [hep, hp]; exact neg_decode A hA)
    step with compress_point_spec ep1 _ hR as ⟨r2, hr2⟩
    step as ⟨b, hb⟩
    have hr2l : r2.val.length = 32 := r2.property
    have hiff : r_sig.val = r2.val ↔ ed25519Verifies A vk.bytes.val msg.val sig.val := by
      rw [hk1, hk, hSv, hs3, Array.val_to_slice] at hr2
      rw [ed25519Verifies, ← hr]
      constructor
      · intro he
        refine ⟨hsig, hS, ?_⟩
        rw [← hr2, he]
      · rintro ⟨-, -, he⟩
        exact leNat_inj _ _ (by simp [hr2l, r_sig_post]) (by rw [he, hr2])
    rw [← hiff, ← hb]
    split <;> simp_all
  · simp only [hS, ↓reduceIte] at o_post
    subst o_post
    have hn : ¬ ed25519Verifies A vk.bytes.val msg.val sig.val := fun ⟨_, h, _⟩ => hS h
    simp [core.option.Option.ok_or, core.result.Result.Insts.CoreOpsTry.branch,
      core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual, hn]

/-! ## Parsing keys, `mid::ed25519` and `high::ed25519` -/

open Classical in
@[step]
theorem decompress_from_spec (h : Runs) (c : Std.Array U8 32#usize) :
    mid.ed25519.EdwardsPoint.decompress_from c ⦃ r =>
      if edValidEncode (leNat c.val) then
        ∃ pt, r = .Ok pt ∧ pairNat pt.val = edModEncodePair (edDecode (leNat c.val))
      else r = .Err (.KeyRejected .NotOnCurve) ⦄ := by
  unfold mid.ed25519.EdwardsPoint.decompress_from
  step*
  have hv : ¬ edValidEncode (leNat c.val) := fun hv => ‹¬b = true› (b_post.mpr hv)
  simp [hv, error.Error.Insts.CoreConvertFromKeyFormatError.from]

open Classical in
theorem mid_from_bytes_spec (h : Runs) (hs : RunsSha512) (bytes : Slice U8) :
    mid.ed25519.VerifyingKey.from_bytes bytes ⦃ r =>
      if bytes.length = 32 then
        if edValidEncode (leNat bytes.val) then
          ∃ vk, r = .Ok vk ∧ vk.bytes.val = bytes.val ∧
            pairNat vk.point.val = edModEncodePair (edDecode (leNat bytes.val))
        else r = .Err (.KeyRejected .NotOnCurve)
      else r = .Err (.KeyRejected .WrongLength) ⦄ := by
  unfold mid.ed25519.VerifyingKey.from_bytes
  step
  step with try_from_shared_spec 32#usize bytes as ⟨r, hr⟩
  by_cases hl : bytes.length = 32
  · simp only [hl, ↓reduceIte] at hr ⊢
    obtain ⟨a, rfl, ha⟩ := hr
    simp only
    step as ⟨r1, hr1⟩
    rw [ha] at hr1
    split_ifs at hr1 ⊢ with hv
    · obtain ⟨pt, rfl, hpt⟩ := hr1
      simp [core.result.Result.map,
        mid.ed25519.VerifyingKey.from_bytes.closure.Insts.CoreOpsFunctionFnOnceTupleEdwardsPointVerifyingKey,
        mid.ed25519.VerifyingKey.from_bytes.closure.Insts.CoreOpsFunctionFnOnceTupleEdwardsPointVerifyingKey.call_once,
        ha, hpt]
    · subst hr1
      simp [core.result.Result.map]
  · simp only [hl, ↓reduceIte] at hr ⊢
    obtain ⟨e, rfl⟩ := hr
    simp [core.convert.IntoFrom.into, error.Error.Insts.CoreConvertFromKeyFormatError.from]

@[step]
theorem has_small_order_loop_spec (y : Std.Array U64 4#usize)
    (it : core.slice.iter.Iter (Std.Array U64 4#usize)) (found : Bool) :
    high.ed25519.has_small_order_loop it y found ⦃ b =>
      b = (found || (it.slice.val.drop it.i).any fun c => decide (wordsNat y.val = wordsNat c.val)) ⦄ := by
  unfold high.ed25519.has_small_order_loop
  apply loop.spec_decr_nat (fun x => x.1.slice.val.length - x.1.i)
    (fun x => x.1.slice = it.slice ∧
      (x.2 || (x.1.slice.val.drop x.1.i).any fun c => decide (wordsNat y.val = wordsNat c.val)) =
      (found || (it.slice.val.drop it.i).any fun c => decide (wordsNat y.val = wordsNat c.val)))
  · rintro ⟨it', f⟩ ⟨hsl, hinv⟩
    simp only at hsl hinv ⊢
    unfold high.ed25519.has_small_order_loop.body
    simp only [core.slice.iter.IteratorSliceIter.next]
    split
    · rename_i hlt
      have hlt' : it'.i < it'.slice.val.length := by simpa [Slice.len] using hlt
      step*
      refine ⟨hsl, ?_, by omega⟩
      rw [← hinv, List.drop_eq_getElem_cons hlt', List.any_cons, b_post, s_post, s1_post,
        Array.val_to_slice, Array.val_to_slice, Bool.or_assoc]
      rfl
    · rename_i hge
      have hge' : it'.slice.val.length ≤ it'.i := by simpa [Slice.len] using hge
      rw [← hinv, List.drop_eq_nil_of_le hge']
      simp
  · exact ⟨rfl, rfl⟩

@[step]
theorem small_order_y_spec :
    high.ed25519.has_small_order.SMALL_ORDER_Y ⦃ t => t.val.map (fun c => wordsNat c.val) = edSmallOrderY ⦄ := by
  unfold high.ed25519.has_small_order.SMALL_ORDER_Y high.ed25519.has_small_order.near_p
  step*
  simp_all [Std.Array.make, Std.Array.repeat, wordsNat, Nat.ofDigits, edSmallOrderY, p25519, U64.rMax]

theorem any_eq_mem (l : List (Std.Array U64 4#usize)) (Y : Nat) :
    (l.any fun c => decide (Y = wordsNat c.val)) = decide (Y ∈ l.map fun c => wordsNat c.val) := by
  induction l with
  | nil => simp
  | cons c l ih => simp [ih]

/-- `has_small_order` refuses the 32-byte encodings whose y-coordinate, the
low 255 bits, is in libsodium's list. -/
@[step]
theorem has_small_order_spec (bytes : Slice U8) :
    high.ed25519.has_small_order bytes ⦃ b =>
      b = decide (bytes.length = 32 ∧ leNat bytes.val % 2 ^ 255 ∈ edSmallOrderY) ⦄ := by
  unfold high.ed25519.has_small_order
  step as ⟨o, ho⟩
  split_ifs at ho with hl
  · obtain ⟨y, rfl, hy⟩ := ho
    simp only [SharedArray.Insts.CoreIterTraitsCollectIntoIteratorSharedIter.into_iter]
    step*
    have hi : i.val = 2 ^ 63 - 1 := by rw [i_post]; decide
    have hi2 : i2.val = i1.val % 2 ^ 63 := by
      rw [i2_post, UScalar.val_and, hi, Nat.and_two_pow_sub_one_eq_mod]
    have hl4 : y.val.length = 4 := y.property
    obtain ⟨l, hl'⟩ : ∃ l, y.val = l := ⟨_, rfl⟩
    rcases l with _ | ⟨w0, _ | ⟨w1, _ | ⟨w2, _ | ⟨w3, _ | ⟨e, l⟩⟩⟩⟩⟩ <;> simp [hl'] at hl4
    have ha : wordsNat a.val = leNat bytes.val % 2 ^ 255 := by
      rw [← hy, a_post]
      simp [i1_post, hl'] at hi2
      simp [Std.Array.set_val_eq, hl', wordsNat, Nat.ofDigits, hi2]
      have h0 : w0.val < 2 ^ 64 := w0.hBounds
      have h1 : w1.val < 2 ^ 64 := w1.hBounds
      have h2 : w2.val < 2 ^ 64 := w2.hBounds
      have h3 : w3.val < 2 ^ 64 := w3.hBounds
      omega
    rw [b_post, List.drop_zero, Slice.from_val, Bool.false_or, ← ha, ← «rind.spec.edSmallOrderY_post»,
      any_eq_mem]
    simp [hl]
  · subst ho
    simp [hl]

open Classical in
theorem high_from_bytes_spec (h : Runs) (hs : RunsSha512) (bytes : Slice U8) :
    high.ed25519.Ed25519VerifyingKey.from_bytes bytes ⦃ r =>
      if bytes.length ≠ 32 then r = .Err (.KeyRejected .WrongLength)
      else if leNat bytes.val % 2 ^ 255 ∈ edSmallOrderY then r = .Err (.KeyRejected .SmallOrder)
      else if edValidEncode (leNat bytes.val) then
        ∃ vk, r = .Ok vk ∧ vk.bytes.val = bytes.val ∧
          pairNat vk.point.val = edModEncodePair (edDecode (leNat bytes.val))
      else r = .Err (.KeyRejected .NotOnCurve) ⦄ := by
  unfold high.ed25519.Ed25519VerifyingKey.from_bytes
  step
  step as ⟨b, hb⟩
  by_cases hl : bytes.length = 32
  · by_cases hso : leNat bytes.val % 2 ^ 255 ∈ edSmallOrderY
    · simp only [hb, hl, hso, and_self, decide_true, ↓reduceIte, ne_eq, not_true_eq_false]
      simp [error.Error.Insts.CoreConvertFromKeyFormatError.from]
    · simp only [hb, hl, hso, and_false, decide_false, Bool.false_eq_true, ↓reduceIte, ne_eq,
        not_true_eq_false]
      step with mid_from_bytes_spec h hs bytes as ⟨r, hr⟩
      simp only [hl, ↓reduceIte] at hr
      split_ifs at hr ⊢ with hv
      · obtain ⟨vk, rfl, hvb, hvp⟩ := hr
        simp [core.result.Result.map, P.Insts.CoreOpsFunctionFnOnceTupleVerifyingKeyEd25519VerifyingKey,
          P.Insts.CoreOpsFunctionFnOnceTupleVerifyingKeyEd25519VerifyingKey.call_once,
          high.ed25519.Ed25519VerifyingKey.constructor, hvb, hvp]
      · subst hr
        simp [core.result.Result.map]
  · simp only [hb, hl, false_and, decide_false, Bool.false_eq_true, ↓reduceIte, ne_eq, not_false_eq_true]
    step with mid_from_bytes_spec h hs bytes as ⟨r, hr⟩
    simp only [hl, ↓reduceIte] at hr
    subst hr
    simp [core.result.Result.map]

theorem copy_from_ok (N : Usize) (bytes : Slice U8) (h : bytes.length ≤ N.val) :
    high.signature.Buffer.copy_from N bytes ⦃ r => ∃ b, r = .Ok b ⦄ := by
  unfold high.signature.Buffer.copy_from high.signature.Buffer.new
  step*
  have hle : bytes.len ≤ s.length := by
    have : s.length = N.val := by simp [Slice.length, s_post]
    scalar_tac
  simp only [core.slice.Slice.get_mut, core.slice.index.SliceIndexRangeToUsizeSlice,
    core.slice.index.SliceIndexRangeToUsizeSlice.get_mut, hle, ↓reduceIte]
  step*

/-! ## Signing, `mid::ed25519::SigningKey` -/

@[step]
theorem unreduced_base_mul_spec (h : Runs) (k : Std.Array U64 4#usize) :
    mid.ed25519.UnreducedScalar.base_mul k ⦃ p => pairNat p.val = edModEncodePair (edPow edB (wordsNat k.val)) ⦄ := by
  unfold mid.ed25519.UnreducedScalar.base_mul
  step*

@[step]
theorem base_mul_spec (h : Runs) (k : Std.Array U64 4#usize) :
    mid.ed25519.Scalar.base_mul k ⦃ p => pairNat p.val = edModEncodePair (edPow edB (wordsNat k.val)) ⦄ := by
  unfold mid.ed25519.Scalar.base_mul
  step*

@[step]
theorem madd_spec (h : Runs) (x y c : Std.Array U64 4#usize) :
    mid.ed25519.Scalar.madd_n25519 x y c ⦃ z =>
      wordsNat z.val = (wordsNat x.val * wordsNat y.val + wordsNat c.val) % n25519 ⦄ := by
  unfold mid.ed25519.Scalar.madd_n25519
  step*

/-- A signing key whose private key is the 32-byte `seed`: RFC 8032 5.1.5's
expansion of it, with the public key's point as s2n-bignum writes it. -/
def SeedKey (k : mid.ed25519.SigningKey) (seed : List U8) : Prop :=
  k.seed.val = seed ∧ wordsNat k.s.val = ed25519Scalar seed ∧ k.prefix.val = (sha512 seed).drop 32 ∧
    k.verifying_key.bytes.val = ed25519PublicKey seed ∧
    pairNat k.verifying_key.point.val = edModEncodePair (edPow edB (ed25519Scalar seed))

/-- The bytes `compress` writes for a point are its encoding's. -/
theorem compress_bytes_spec (p : Std.Array U64 8#usize) (P : EdPoint)
    (hp : pairNat p.val = edModEncodePair P) :
    mid.ed25519.EdwardsPoint.compress p ⦃ c => c.val = leBytesOf 32 (edEncode P) ⦄ := by
  apply WP.spec_mono (compress_point_spec p P hp)
  intro c hc
  have := leBytesOf_leNat c.val
  rw [c.property, hc] at this
  exact this.symm

theorem from_seed_spec (h : Runs) (hs : RunsSha512) (seed : Std.Array U8 32#usize) :
    mid.ed25519.SigningKey.from_seed seed ⦃ k => SeedKey k seed.val ⦄ := by
  unfold mid.ed25519.SigningKey.from_seed low.ct.into_public low.ct.secret_slice
  step
  step with context_new_spec as ⟨c, hc⟩
  step as ⟨s1, hs1⟩
  step with context_update_spec hs _ c [] s1 hc (by simp [Slice.length, hs1]) as ⟨c1, hc1⟩
  step with context_finish_spec hs _ c1 _ hc1 as ⟨hh, hhv⟩
  step*
  step with compress_bytes_spec point _ point_post as ⟨cey, hcey⟩
  simp only [r_post, r1_post, core.result.Result.Ok.injEq] at *
  have hH : hh.val = sha512 seed.val := by rw [hhv, hs1]; simp [sha512, Array.val_to_slice]
  have hl64 : (sha512 seed.val).length = 64 := by rw [← hH]; exact hh.property
  have hs3' : wordsNat s3.val = ed25519Scalar seed.val := by
    rw [s3_post, ed25519Scalar]
    simp_all [List.slice, Array.val_to_slice]
  refine ⟨rfl, hs3', ?_, ?_, ?_⟩
  · simp_all [List.slice, Array.val_to_slice]
  · rw [hcey, hs3']; rfl
  · rw [point_post, hs3']

end rind.x86_64
