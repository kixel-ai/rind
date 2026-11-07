import Rind.X86_64.ValeAesGcm
import Rind.ValeBytes
open Aeneas Aeneas.Std Result rind.vale rind.simd

/-!
# GHASH's partial blocks

`ghash::load_partial` zero-pads fewer than 16 bytes to a block from
overlapping 8-, 4-, and 1-byte loads, and `store_partial` writes a block's
first bytes back with overlapping stores. These prove them so, at every length,
first bit by bit and then as the bytes Vale's routines read and write.
-/

namespace rind.x86_64

/-- Bit `k` of the bytes `l`, least significant first, and zero past them. -/
def bit (l : List U8) (k : Nat) : Bool := (l[k / 8]!).bv.getLsbD (k % 8)

theorem bit_of_ge (l : List U8) {k : Nat} (h : l.length ≤ k / 8) : bit l k = false := by
  simp [bit, List.getElem!_eq_getElem?_getD, List.getElem?_eq_none h]

theorem getLsbD_fromLEBytes (m : List (BitVec 8)) (k : Nat) :
    (BitVec.fromLEBytes m).getLsbD k = (m[k / 8]!).getLsbD (k % 8) := by
  have := BitVec.fromLEBytes_getElem! m k
  rw [BitVec.getElem!_eq_testBit_toNat] at this
  rw [← BitVec.testBit_toNat, this]
  rfl

theorem bvs_slice_getElem! (l : List U8) {j t w : Nat} (ht : t < w) :
    (bvs (List.slice j (j + w) l))[t]! = (l[j + t]!).bv := by
  simp only [bvs, List.slice]
  rw [List.getElem!_eq_getElem?_getD, List.getElem!_eq_getElem?_getD]
  simp [List.getElem?_drop, ht]
  rfl

/-- The `w` bytes at `j`, read little-endian: bit `t` is the bytes' bit
`8 j + t`, and zero past them. -/
theorem getLsbD_window (l : List U8) (a : List U8) {j w : Nat} (ha : a = List.slice j (j + w) l)
    (h : j + w ≤ l.length) (t : Nat) :
    (BitVec.fromLEBytes (bvs a)).getLsbD t = (t < 8 * w && bit l (8 * j + t)) := by
  subst ha
  rw [getLsbD_fromLEBytes]
  by_cases ht : t < 8 * w
  · rw [bvs_slice_getElem! l (by omega), bit]
    simp only [ht, decide_true, Bool.true_and]
    rw [show (8 * j + t) / 8 = j + t / 8 by omega, show (8 * j + t) % 8 = t % 8 by omega]
  · simp only [ht, decide_false, Bool.false_and]
    have : (bvs (List.slice j (j + w) l)).length = w := by simp [bvs, List.slice]; omega
    rw [List.getElem!_eq_getElem?_getD, List.getElem?_eq_none (by omega)]
    show BitVec.getLsbD 0 _ = false
    simp

@[step]
theorem le64_step (bytes : Slice U8) (j : Usize) (h : j.val + 8 ≤ bytes.length) :
    low.x86_64.ghash.load_partial.closure.Insts.CoreOpsFunctionFnTupleUsizeU64.call bytes j ⦃ r =>
      ∀ t, r.bv.getLsbD t = (t < 64 && bit bytes.val (8 * j.val + t)) ⦄ := by
  unfold low.x86_64.ghash.load_partial.closure.Insts.CoreOpsFunctionFnTupleUsizeU64.call
  step*
  · cases r <;> simp_all
  · have ha : a.val = s.val := by subst r_post; simp_all
    intro t
    have := getLsbD_window bytes.val a.val (j := j.val) (w := 8) (by rw [ha, s_post, i_post]) h t
    simp only [core.num.U64.from_le_bytes]
    show (BitVec.cast (by simp) (BitVec.fromLEBytes (List.map U8.bv a.val))).getLsbD t = _
    rw [BitVec.getLsbD_cast]
    exact this

@[step]
theorem le32_step (bytes : Slice U8) (j : Usize) (h : j.val + 4 ≤ bytes.length) :
    low.x86_64.ghash.load_partial.closure_1.Insts.CoreOpsFunctionFnTupleUsizeU64.call bytes j ⦃ r =>
      ∀ t, r.bv.getLsbD t = (t < 32 && bit bytes.val (8 * j.val + t)) ⦄ := by
  unfold low.x86_64.ghash.load_partial.closure_1.Insts.CoreOpsFunctionFnTupleUsizeU64.call
  step*
  · cases r <;> simp_all
  · have ha : a.val = s.val := by subst r_post; simp_all
    intro t
    have := getLsbD_window bytes.val a.val (j := j.val) (w := 4) (by rw [ha, s_post, i_post]) h t
    simp only [core.convert.num.FromU64U32.from, i1_post]
    erw [this]

@[step]
theorem byte_step (bytes : Slice U8) (j : Usize) (h : j.val < bytes.length) (h8 : j.val < 8) :
    low.x86_64.ghash.load_partial.closure_2.Insts.CoreOpsFunctionFnTupleUsizeU64.call bytes j ⦃ r =>
      ∀ t, r.bv.getLsbD t = (8 * j.val ≤ t && t < 8 * j.val + 8 && bit bytes.val t) ⦄ := by
  unfold low.x86_64.ghash.load_partial.closure_2.Insts.CoreOpsFunctionFnTupleUsizeU64.call
  simp only [lift, bind_ok, core.convert.num.FromU64U8.from]
  step*
  have hb : (bytes.val[j.val]!) = i := by rw [i_post]; simp [h]
  have hr : r.bv = BitVec.setWidth 64 i.bv <<< i2.val := r_post1
  simp only [hr]
  rw [BitVec.getLsbD_shiftLeft, BitVec.getLsbD_setWidth, i2_post, bit]
  by_cases ht : 8 * j.val ≤ t ∧ t < 8 * j.val + 8
  · rw [show t / 8 = j.val by omega, hb, show t % 8 = t - 8 * j.val by omega]
    have h1 : ¬ t < 8 * j.val := by omega
    have h2 : t - 8 * j.val < 64 := by omega
    simp [ht.1, ht.2, show t < 64 by omega, show t - 8 * j.val < 8 by omega, h1, h2]
  · by_cases h1 : t < 8 * j.val
    · simp [h1]
    · have h2 : ¬ t < 8 * j.val + 8 := by omega
      simp [h1, h2, BitVec.getLsbD_of_ge i.bv (t - 8 * j.val) (by omega)]

theorem getLsbD_set_epi64x (hi lo : U64) (k : Nat) :
    ((UScalar.hcast IScalarTy.I64 hi).bv ++ (UScalar.hcast IScalarTy.I64 lo).bv).getLsbD k =
      if k < 64 then lo.bv.getLsbD k else hi.bv.getLsbD (k - 64) := by
  simp only [UScalar.hcast_bv_eq]
  rw [BitVec.getLsbD_append]
  by_cases h : k < 64 <;> simp [h]

/-- `load_partial` zero-pads its fewer than 16 bytes to a block: bit `k` is the
bytes' bit `k`. -/
theorem load_partial_bits (bytes : Slice U8) (hn : bytes.length < 16) :
    low.x86_64.ghash.load_partial bytes ⦃ v => ∀ k < 128, v.getLsbD k = bit bytes.val k ⦄ := by
  have hlen : bytes.len.val = bytes.length := Slice.len_val _
  unfold low.x86_64.ghash.load_partial
  step*
  by_cases h9 : 9#usize ≤ bytes.len
  · rw [ite_eq_left h9]
    step as ⟨lo, hlo⟩
    step as ⟨m, hm, hm1⟩
    step as ⟨hr, hhr⟩
    step as ⟨s16, hs16, hs161⟩
    step as ⟨s, hs⟩
    step as ⟨hi, hhi, hhi1⟩
    simp only [lift, bind_ok, core.core_arch.x86.sse2._mm_set_epi64x, WP.spec_ok]
    intro k hk
    rw [getLsbD_set_epi64x _ _ _]
    split
    · rw [hlo]; simp [*]
    · have hh : hi.bv = hr.bv >>> s.val := hhi1
      simp only [hh, BitVec.getLsbD_ushiftRight, hhr]
      by_cases hkn : k / 8 < bytes.length
      · rw [show 8 * m.val + (s.val + (k - 64)) = k by omega]
        simp [show s.val + (k - 64) < 64 by omega]
      · have : ¬ s.val + (k - 64) < 64 := by omega
        simp only [this, decide_false, Bool.false_and]
        rw [bit_of_ge _ (by simp only [Slice.length] at hkn; omega)]
  · rw [ite_eq_right h9]
    have hl : bytes.val.length = bytes.length := rfl
    by_cases h4 : 4#usize ≤ bytes.len
    · have h8 : bytes.len ≤ 8#usize := by scalar_tac
      rw [ite_eq_left h4, ite_eq_left h8]
      step as ⟨a, ha⟩
      step as ⟨m, hm, hm1⟩
      step as ⟨b, hb⟩
      step as ⟨sh, hsh⟩
      step as ⟨c, hc, hc1⟩
      simp only [lift, bind_ok, core.core_arch.x86.sse2._mm_set_epi64x, WP.spec_ok]
      intro k hk
      rw [getLsbD_set_epi64x _ _ _]
      have hcc : c.bv = b.bv <<< sh.val := hc1
      split
      · simp only [UScalar.bv_or, BitVec.getLsbD_or, hcc, BitVec.getLsbD_shiftLeft, ha, hb]
        by_cases hks : k < sh.val
        · simp [hks, show k < 32 by scalar_tac]
        · rw [show 8 * m.val + (k - sh.val) = k by omega]
          cases hbk : bit bytes.val k
          · simp [hbk]
          · have : k / 8 < bytes.length := by
              by_contra hc
              rw [bit_of_ge _ (by omega)] at hbk
              exact absurd hbk (by simp)
            simp [hks, show k - sh.val < 32 by scalar_tac, show k < 64 by omega]
      · rw [bit_of_ge _ (by scalar_tac)]
        simp
    · rw [ite_eq_right h4]
      by_cases h1 : 1#usize ≤ bytes.len
      · have h3 : bytes.len ≤ 3#usize := by scalar_tac
        rw [ite_eq_left h1, ite_eq_left h3]
        step as ⟨a, ha⟩
        step as ⟨d, hd⟩
        step as ⟨b, hb⟩
        step as ⟨e, he, he1⟩
        step as ⟨c, hc, hc1⟩
        step as ⟨f, hf⟩
        simp only [lift, bind_ok, core.core_arch.x86.sse2._mm_set_epi64x, WP.spec_ok]
        intro k hk
        rw [getLsbD_set_epi64x _ _ _]
        have he' : e.bv = a.bv ||| b.bv := he1
        split
        · simp only [UScalar.bv_or, BitVec.getLsbD_or, he', ha, hb, hf]
          cases hbk : bit bytes.val k
          · simp
          · have : k / 8 < bytes.length := by
              by_contra hc
              rw [bit_of_ge _ (by omega)] at hbk
              exact absurd hbk (by simp)
            simp only [Bool.and_true, Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq]
            scalar_tac
        · rw [bit_of_ge _ (by scalar_tac)]
          simp
      · rw [ite_eq_right h1]
        have h0 : bytes.len.val = 0 := by scalar_tac
        simp only [h0, bind_ok, lift, core.core_arch.x86.sse2._mm_set_epi64x]
        refine (WP.spec_ok _).2 fun k hk => ?_
        rw [getLsbD_set_epi64x _ _ _, bit_of_ge _ (by scalar_tac)]
        split <;> simp

@[step]
theorem cvtsi128_si64_step (a : core.core_arch.x86.__m128i) :
    core.core_arch.x86_64.sse2._mm_cvtsi128_si64 a ⦃ r => r.bv = lane64 a 0 ⦄ := by
  simp [core.core_arch.x86_64.sse2._mm_cvtsi128_si64]

@[step]
theorem unpackhi_epi64_step (a : core.core_arch.x86.__m128i) :
    core.core_arch.x86.sse2._mm_unpackhi_epi64 a a ⦃ r => lane64 r 0 = lane64 a 1 ⦄ := by
  simp only [core.core_arch.x86.sse2._mm_unpackhi_epi64, WP.spec_ok]
  apply BitVec.eq_of_getLsbD_eq
  intro i hi
  simp only [lane64]
  rw [BitVec.getLsbD_extractLsb', BitVec.getLsbD_append]
  simp [hi]

/-- Bit `j` of byte `i` of a word's little-endian bytes. -/
theorem le_byte_bit {ty : UScalarTy} (x : UScalar ty) {i j : Nat} (hi : 8 * i < ty.numBits) (hj : j < 8) :
    ((List.map (@UScalar.mk UScalarTy.U8) x.bv.toLEBytes)[i]!).bv.getLsbD j = x.bv.getLsbD (8 * i + j) := by
  have hl : i < x.bv.toLEBytes.length := by rw [BitVec.toLEBytes_length]; omega
  rw [List.getElem!_eq_getElem?_getD, List.getElem?_map, List.getElem?_eq_getElem hl]
  simp only [Option.map_some, Option.getD_some]
  have := BitVec.toLEBytes_getElem!_testBit x.bv i j hj
  rw [List.getElem!_eq_getElem?_getD, List.getElem?_eq_getElem hl, Option.getD_some,
    BitVec.getElem!_eq_testBit_toNat] at this
  rw [← BitVec.testBit_toNat, ← BitVec.testBit_toNat]
  exact this

theorem getLsbD_lane64 (x : BitVec 128) (i t : Nat) :
    (lane64 x i).getLsbD t = (decide (t < 64) && x.getLsbD (64 * i + t)) := by
  simp [lane64, BitVec.getLsbD_extractLsb']

theorem store_partial_bits (out : Slice U8) (block : core.core_arch.x86.__m128i) (hn : out.length < 16) :
    low.x86_64.ghash.store_partial out block ⦃ out' => out'.length = out.length ∧
      ∀ i < out.length, ∀ j < 8, (out'.val[i]!).bv.getLsbD j = block.getLsbD (8 * i + j) ⦄ := by
  have hlen : out.len.val = out.length := Slice.len_val _
  unfold low.x86_64.ghash.store_partial
  step as ⟨_⟩
  step as ⟨x, hx⟩
  step as ⟨lo, hlo⟩
  step as ⟨y, hy⟩
  step as ⟨z, hz⟩
  step as ⟨hi, hhi⟩
  have hlo' : lo.bv = lane64 block 0 := by
    subst hlo; simp [IScalar.hcast_bv_eq, hx]
  have hhi' : hi.bv = lane64 block 1 := by
    subst hhi; simp [IScalar.hcast_bv_eq, hz, hy]
  clear hlo hhi hx hy hz
  have hl : out.val.length = out.length := rfl
  by_cases h9 : 9#usize ≤ out.len
  · rw [ite_eq_left h9]
    step*
    have hb : (index_mut_back1 s5).val = (out.val.setSlice! 0 (List.map UScalar.mk lo.bv.toLEBytes)).setSlice!
        i2.val (List.map UScalar.mk last.bv.toLEBytes) := by
      rw [s3_post2, s5_post, s4_post, s_post2, s2_post, s1_post]
      simp [a_post, a1_post]
    have hlast : last.bv = (lo.bv >>> i3.val) ||| (hi.bv <<< i6.val) := by
      have := last_post1; simp only [i4_post1, i7_post1] at this; exact this
    refine ⟨by simp [Slice.length, hb], fun i hi j hj => ?_⟩
    rw [hb]
    by_cases hi2 : i < i2.val
    · rw [List.getElem!_setSlice!_prefix _ _ _ _ hi2,
        List.getElem!_setSlice!_middle _ _ _ _ ⟨by omega, by simp; omega, by scalar_tac⟩,
        Nat.sub_zero, le_byte_bit lo (by simp; omega) hj]
      simp only [hlo', getLsbD_lane64]
      simp; omega
    · rw [List.getElem!_setSlice!_middle _ _ _ _ ⟨by omega, by simp; scalar_tac, by simp; scalar_tac⟩,
        le_byte_bit last (by simp; scalar_tac) hj]
      simp only [hlast, BitVec.getLsbD_or, BitVec.getLsbD_ushiftRight, BitVec.getLsbD_shiftLeft, hlo', hhi',
        getLsbD_lane64]
      have e1 : i3.val + (8 * (i - i2.val) + j) = 8 * i + j := by scalar_tac
      have hnb : UScalarTy.U64.numBits = 64 := rfl
      by_cases hk : 8 * i + j < 64
      · have : 8 * (i - i2.val) + j < i6.val := by scalar_tac
        simp [e1, hk, this]
      · have e2 : 64 * 1 + (8 * (i - i2.val) + j - i6.val) = 8 * i + j := by scalar_tac
        have : ¬ 8 * (i - i2.val) + j < i6.val := by scalar_tac
        simp [e1, e2, hk, this, hnb, show 8 * (i - i2.val) + j < 64 by scalar_tac,
          show 8 * (i - i2.val) + j - i6.val < 64 by scalar_tac]
  · rw [ite_eq_right h9]
    by_cases h4 : 4#usize ≤ out.len
    · have h8 : out.len ≤ 8#usize := by scalar_tac
      rw [ite_eq_left h4, ite_eq_left h8]
      step*
      have hb : (index_mut_back1 s5).val = (out.val.setSlice! 0 (List.map UScalar.mk i2.bv.toLEBytes)).setSlice!
          i3.val (List.map UScalar.mk i6.bv.toLEBytes) := by
        rw [s3_post2, s5_post, s4_post, s_post2, s2_post, s1_post]
        simp [a_post, a1_post]
      refine ⟨by simp [Slice.length, hb], fun i hi j hj => ?_⟩
      rw [hb]
      have h2 : i2.bv = lo.bv.setWidth 32 := by rw [i2_post]; simp [UScalar.cast_bv_eq]
      have h6 : i6.bv = (lo.bv >>> i4.val).setWidth 32 := by
        rw [i6_post]; simp only [UScalar.cast_bv_eq, i5_post1]; rfl
      by_cases hi3 : i < i3.val
      · rw [List.getElem!_setSlice!_prefix _ _ _ _ hi3,
          List.getElem!_setSlice!_middle _ _ _ _ ⟨by omega, by simp; scalar_tac, by scalar_tac⟩,
          Nat.sub_zero, le_byte_bit i2 (by simp; scalar_tac) hj]
        simp only [h2, hlo']
        erw [BitVec.getLsbD_setWidth, getLsbD_lane64]
        have : 8 * i + j < 32 := by scalar_tac
        simp [this, show 8 * i + j < 64 by omega]
      · rw [List.getElem!_setSlice!_middle _ _ _ _ ⟨by omega, by simp; scalar_tac, by simp; scalar_tac⟩,
          le_byte_bit i6 (by simp; scalar_tac) hj]
        simp only [h6, hlo']
        erw [BitVec.getLsbD_setWidth, BitVec.getLsbD_ushiftRight, getLsbD_lane64,
          show i4.val + (8 * (i - i3.val) + j) = 8 * i + j by scalar_tac]
        simp [show 8 * (i - i3.val) + j < 32 by scalar_tac, show 8 * i + j < 64 by scalar_tac]
    · rw [ite_eq_right h4]
      by_cases h1 : 1#usize ≤ out.len
      · have h3 : out.len ≤ 3#usize := by scalar_tac
        rw [ite_eq_left h1, ite_eq_left h3]
        step*
        have hv : out'.val = ((out.val.set 0 i2).set i3.val i6).set i7.val i10 := by
          simp [out'_post, out2_post, out1_post]
        have hb : ∀ (k : Nat) (v : U8), v.bv = (lo.bv >>> (8 * k)).setWidth 8 → k < 8 →
            ∀ j < 8, v.bv.getLsbD j = block.getLsbD (8 * k + j) := by
          intro k v hv' hk j hj
          simp only [hv', hlo']
          erw [BitVec.getLsbD_setWidth, BitVec.getLsbD_ushiftRight, getLsbD_lane64]
          simp [hj, show 8 * k + j < 64 by omega]
        have v2 : i2.bv = (lo.bv >>> (8 * 0)).setWidth 8 := by
          rw [i2_post]; simp [UScalar.cast_bv_eq]
        have v6 : i6.bv = (lo.bv >>> (8 * i3.val)).setWidth 8 := by
          rw [i6_post]; simp only [UScalar.cast_bv_eq, i5_post1, i4_post]; rfl
        have v10 : i10.bv = (lo.bv >>> (8 * i7.val)).setWidth 8 := by
          rw [i10_post]; simp only [UScalar.cast_bv_eq, i9_post1, i8_post]; rfl
        refine ⟨by simp [Slice.length, hv], fun i hi j hj => ?_⟩
        rw [hv, List.getElem!_eq_getElem?_getD, List.getElem?_set, List.getElem?_set, List.getElem?_set]
        simp only [List.length_set]
        split_ifs with e7 l7 e3 l3 e0 l0 <;> try simp only [Option.getD_some, Option.getD_none]
        · subst e7; exact hb _ _ v10 (by scalar_tac) j hj
        · exfalso; scalar_tac
        · subst e3; exact hb _ _ v6 (by scalar_tac) j hj
        · exfalso; scalar_tac
        · subst e0; exact hb _ _ v2 (by scalar_tac) j hj
        · exfalso; scalar_tac
        · exfalso; scalar_tac
      · rw [ite_eq_right h1]
        have h0 : out.len.val = 0 := by scalar_tac
        simp only [h0]
        refine (WP.spec_ok _).2 ⟨rfl, fun i hi => by scalar_tac⟩

/-- `load_partial`'s block is its bytes, zero-padded to 16. -/
@[step]
theorem load_partial_spec (bytes : Slice U8) (hn : bytes.length < 16) :
    low.x86_64.ghash.load_partial bytes ⦃ v =>
      leQuad32ToBytes v = bvs bytes.val ++ List.replicate (16 - bytes.length) 0#8 ⦄ := by
  apply WP.spec_mono (load_partial_bits bytes hn)
  intro v hv
  have hl : bytes.val.length = bytes.length := rfl
  apply List.ext_getElem (by simp [leQuad32ToBytes]; omega)
  intro i h1 h2
  have hi : i < 16 := by simpa [leQuad32ToBytes] using h1
  simp only [leQuad32ToBytes, List.getElem_map, List.getElem_range]
  apply BitVec.eq_of_getLsbD_eq
  intro j hj
  rw [BitVec.getLsbD_extractLsb', hv _ (by omega), bit, show (8 * i + j) / 8 = i by omega,
    show (8 * i + j) % 8 = j by omega]
  simp only [hj, decide_true, Bool.true_and]
  by_cases hin : i < bytes.length
  · rw [List.getElem_append_left (by simp [bvs]; omega)]
    simp [bvs, List.getElem!_eq_getElem?_getD, List.getElem?_eq_getElem (show i < bytes.val.length by omega)]
  · rw [List.getElem_append_right (by simp [bvs]; omega)]
    simp [List.getElem!_eq_getElem?_getD, List.getElem?_eq_none (show bytes.val.length ≤ i by omega)]

/-- `store_partial` writes the block's first bytes over all of `out`. -/
@[step]
theorem store_partial_spec (out : Slice U8) (block : core.core_arch.x86.__m128i) (hn : out.length < 16) :
    low.x86_64.ghash.store_partial out block ⦃ out' =>
      out'.length = out.length ∧ bvs out'.val = (leQuad32ToBytes block).take out.length ⦄ := by
  apply WP.spec_mono (store_partial_bits out block hn)
  rintro out' ⟨hlen, hb⟩
  have hl' : out'.val.length = out.val.length := hlen
  have hn' : out.val.length < 16 := hn
  refine ⟨hlen, List.ext_getElem (by simp [bvs, leQuad32ToBytes, hl', Slice.length]; omega) ?_⟩
  intro i h1 h2
  have hi : i < out.length := by simpa [bvs, Slice.length, hlen] using h1
  simp only [bvs, List.getElem_map, List.getElem_take, leQuad32ToBytes, List.getElem_range]
  apply BitVec.eq_of_getLsbD_eq
  intro j hj
  rw [BitVec.getLsbD_extractLsb', ← hb i hi j hj]
  simp [hj, List.getElem!_eq_getElem?_getD, List.getElem?_eq_getElem (show i < out'.val.length by
    simp only [Slice.length] at hlen hi; omega)]
