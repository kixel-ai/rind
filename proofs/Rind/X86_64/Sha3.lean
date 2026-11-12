import Rind.X86_64.KeccakDispatch
import Rind.X86_64.Blockwise
import Rind.Sha3
import Rind.Bytes
open Aeneas Aeneas.Std Result rind.spec

/-!
# The SHA-3 sponge, proven from rind's Rust to FIPS 202

`Rind.Sha3` states FIPS 202's sponge over bytes and proves it SymCrypt's
transliteration of the standard. This file proves rind's Rust sponge,
`mid::sha3`, computes it, over the Keccak-f routines
`Rind.X86_64.KeccakDispatch` specifies from s2n-bignum's contracts.
`admin/prove` writes the aarch64 proof from this file by renaming the target.
-/

namespace rind.x86_64

/-! ## The state's bytes -/

/-- Lanes' bytes, little-endian. -/
abbrev sbl (L : List U64) : List Byte := stateBytes (L.map (·.bv))

theorem ext_getElem! {α : Type} [Inhabited α] {l1 l2 : List α} (h : l1.length = l2.length)
    (h' : ∀ i, i < l1.length → l1[i]! = l2[i]!) : l1 = l2 :=
  List.ext_getElem h fun i h1 h2 => by
    have := h' i h1
    rwa [getElem!_pos l1 i h1, getElem!_pos l2 i h2] at this

theorem length_sbl (L : List U64) : (sbl L).length = 8 * L.length := by
  induction L with
  | nil => rfl
  | cons a L ih =>
    simp only [sbl, stateBytes, List.map_cons, List.flatMap_cons, List.length_append,
      BitVec.toLEBytes_length, List.length_cons] at ih ⊢
    rw [ih]; ring

theorem sbl_testBit (L : List U64) (j t : Nat) (ht : t < 8) :
    (sbl L)[j]!.toNat.testBit t = (L[j / 8]!).bv[8 * (j % 8) + t]! := by
  rw [sbl, stateBytes, testBit_flatMap_toLEBytes _ _ _ ht]
  by_cases h : j / 8 < L.length
  · rw [getElem!_pos (L.map (·.bv)) (j / 8) (by simpa using h), getElem!_pos L _ h, List.getElem_map]
  · rw [List.getElem!_eq_getElem?_getD, List.getElem?_eq_none (by simp; omega),
      List.getElem!_eq_getElem?_getD, List.getElem?_eq_none (by omega)]
    rfl

/-- XORing `w` into lane `k` XORs into the state's bytes the bytes `B` that
`w` holds from byte `sh` of the lane on, zero elsewhere. -/
theorem sbl_set_xor (L : List U64) (k : Nat) (hk : k < L.length) (x : U64) (w : BitVec 64)
    (hx : x.bv = (L[k]!).bv ^^^ w) (sh : Nat) (B : List Byte) (hB : sh + B.length ≤ 8)
    (hw : ∀ m t, m < 8 → t < 8 → w[8 * m + t]! =
      if sh ≤ m ∧ m < sh + B.length then B[m - sh]!.toNat.testBit t else false) :
    sbl (L.set k x) = xorAt (sbl L) (8 * k + sh) B := by
  apply ext_getElem! (by simp [length_sbl])
  intro j hj
  rw [length_sbl, List.length_set] at hj
  rw [getElem!_xorAt _ _ _ _ (by rw [length_sbl]; omega)]
  apply Spec.Byte.ext_testBit
  intro t ht
  rw [sbl_testBit _ _ _ ht]
  by_cases hjk : j / 8 = k
  · rw [hjk, getElem!_pos _ k (by simpa using hk), List.getElem_set_self, hx, BitVec.getElem!_eq_testBit_toNat,
      BitVec.toNat_xor, Nat.testBit_xor, ← BitVec.getElem!_eq_testBit_toNat,
      ← BitVec.getElem!_eq_testBit_toNat, hw (j % 8) t (by omega) ht]
    have hc : (8 * k + sh ≤ j ∧ j < 8 * k + sh + B.length) ↔
        (sh ≤ j % 8 ∧ j % 8 < sh + B.length) := by omega
    by_cases hin : sh ≤ j % 8 ∧ j % 8 < sh + B.length
    · rw [if_pos hin, if_pos (hc.2 hin), testBit_xor_byte, sbl_testBit _ _ _ ht, hjk,
        show j - (8 * k + sh) = j % 8 - sh by omega]
    · rw [if_neg hin, if_neg (fun h => hin (hc.1 h)), sbl_testBit _ _ _ ht, hjk]
      simp
  · rw [List.getElem!_eq_getElem?_getD, List.getElem?_set_ne (Ne.symm hjk),
      ← List.getElem!_eq_getElem?_getD, if_neg (by omega), sbl_testBit _ _ _ ht]

/-! ## `partial_lane`, `add_bytes` -/

theorem toLEBytes_fromLEBytes (l : List Byte) (h : l.length = 8) :
    ((BitVec.fromLEBytes l).cast (by rw [h]) : BitVec 64).toLEBytes = l := by
  apply ext_getElem! (by simp [h])
  intro i hi
  simp only [BitVec.toLEBytes_length] at hi
  apply Spec.Byte.ext_testBit
  intro t ht
  have := BitVec.toLEBytes_getElem!_testBit ((BitVec.fromLEBytes l).cast (by rw [h]) : BitVec 64)
    i t ht
  simp only [Byte.testBit] at this
  rw [this, BitVec.getElem!_cast, BitVec.fromLEBytes_getElem!,
    show (8 * i + t) / 8 = i by omega, show (8 * i + t) % 8 = t by omega]

/-- `partial_lane` puts `bytes` in a lane's low bytes. -/
theorem partial_lane_spec (bytes : Slice U8) (h : bytes.length ≤ 8) :
    mid.sha3.partial_lane bytes ⦃ r => ∀ m t, m < 8 → t < 8 →
      r.bv[8 * m + t]! = if m < bytes.length then (bv bytes.val)[m]!.toNat.testBit t else false ⦄ := by
  unfold mid.sha3.partial_lane
  step*
  intro m t hm ht
  have hfl := core.num.U64.from_le_bytes.step_spec (index_mut_back s1)
  simp only [lift, WP.spec_ok] at hfl
  rw [hfl, BitVec.getElem!_cast, BitVec.fromLEBytes_getElem!, show (8 * m + t) / 8 = m by omega,
    show (8 * m + t) % 8 = t by omega, s_post2, s1_post]
  rw [getElem!_pos _ m (by simp [hm]), List.getElem_map, ← getElem!_pos]
  by_cases hmb : m < bytes.length
  · rw [if_pos hmb, List.getElem!_setSlice!_middle _ _ _ _ ⟨by omega, by simpa using hmb, by simp; omega⟩,
      bv, getElem!_pos _ m (by simpa using hmb), List.getElem_map, ← getElem!_pos]
    rfl
  · rw [if_neg hmb, List.getElem!_setSlice!_suffix _ _ _ _ (by simp [Slice.length] at hmb ⊢; omega)]
    have hz : (Array.repeat 8#usize 0#u8).val[m]! = 0#u8 := by
      rw [getElem!_pos _ m (by simp [hm])]; interval_cases m <;> rfl
    rw [hz]; simp [Byte.testBit]

@[simp] theorem xorAt_nil (S : List Byte) (off : Nat) : xorAt S off [] = S := by
  apply ext_getElem! (by simp)
  intro i hi
  rw [getElem!_xorAt S off [] i (by simpa using hi), if_neg (by simp)]

theorem getElem!_append_if {α : Type} [Inhabited α] (l1 l2 : List α) (i : Nat) :
    (l1 ++ l2)[i]! = if i < l1.length then l1[i]! else l2[i - l1.length]! := by
  simp only [List.getElem!_eq_getElem?_getD]
  split
  · rw [List.getElem?_append_left (by omega)]
  · rw [List.getElem?_append_right (by omega)]

/-- XORing two runs of bytes in turn, the second just after the first. -/
theorem xorAt_xorAt (S : List Byte) (off : Nat) (B1 B2 : List Byte) :
    xorAt (xorAt S off B1) (off + B1.length) B2 = xorAt S off (B1 ++ B2) := by
  apply ext_getElem! (by simp)
  intro i hi
  simp only [length_xorAt] at hi
  rw [getElem!_xorAt _ _ _ _ (by simpa using hi), getElem!_xorAt _ _ _ _ hi,
    getElem!_xorAt _ _ _ _ hi, getElem!_append_if, List.length_append]
  by_cases h1 : off ≤ i ∧ i < off + B1.length
  · rw [if_neg (by omega), if_pos h1, if_pos (by omega), if_pos (by omega)]
  · rw [if_neg h1]
    by_cases h2 : off + B1.length ≤ i ∧ i < off + B1.length + B2.length
    · rw [if_pos h2, if_pos (by omega), if_neg (by omega), show i - (off + B1.length) =
        i - off - B1.length by omega]
    · rw [if_neg h2, if_neg (by omega)]

/-- XORing a second run, if any, just after the first. -/
theorem xorAt_xorAt' (S : List Byte) (off o2 : Nat) (B1 B2 : List Byte)
    (h : B2 ≠ [] → o2 = off + B1.length) :
    xorAt (xorAt S off B1) o2 B2 = xorAt S off (B1 ++ B2) := by
  by_cases hB : B2 = []
  · subst hB; simp
  · rw [h hB, xorAt_xorAt]

/-- `as_chunks`: chunk `i` is the `i`-th run of `N`, and the rest follows them. -/
theorem as_chunks_spec {T : Type} [Inhabited T] (N : Usize) (s : Slice T) (hN : 0 < N.val) :
    core.slice.Slice.as_chunks N s ⦃ c r =>
      c.val.length = s.length / N.val ∧
      (∀ i, i < c.val.length → (c.val[i]!).val = (s.val.drop (i * N.val)).take N.val) ∧
      r.val = s.val.drop (s.length / N.val * N.val) ⦄ := by
  simp only [core.slice.Slice.as_chunks, show ¬(N.val = 0) by omega, ↓reduceIte, WP.spec_ok]
  refine ⟨by simp, ?_, by simp⟩
  intro i hi
  simp only [Slice.from_val, List.length_ofFn] at hi
  rw [getElem!_pos _ i (by simpa using hi)]
  simp

theorem setSlice!_set {α : Type} [Inhabited α] (L w : List α) (first c : Nat) (x : α)
    (_h : first + w.length ≤ L.length) (hc : c < w.length) :
    L.setSlice! first (w.set c x) = (L.setSlice! first w).set (first + c) x := by
  apply ext_getElem! (by simp)
  intro j hj
  simp only [List.length_setSlice!] at hj
  rw [List.getElem!_eq_getElem?_getD (l := (L.setSlice! first w).set (first + c) x),
    List.getElem?_set]
  by_cases hjc : first + c = j
  · subst hjc
    rw [List.getElem!_setSlice!_middle _ _ _ _ ⟨by omega, by simp; omega, by omega⟩]
    simp [show first + c - first = c by omega, hc, hj]
  · rw [if_neg hjc, ← List.getElem!_eq_getElem?_getD]
    by_cases hin : first ≤ j ∧ j < first + w.length
    · rw [List.getElem!_setSlice!_middle _ _ _ _ ⟨hin.1, by simp; omega, hj⟩,
        List.getElem!_setSlice!_middle _ _ _ _ ⟨hin.1, by omega, hj⟩,
        List.getElem!_eq_getElem?_getD, List.getElem?_set_ne (by omega),
        ← List.getElem!_eq_getElem?_getD]
    · rw [List.getElem!_setSlice!_same _ _ _ _ (by simp; omega),
        List.getElem!_setSlice!_same _ _ _ _ (by omega)]

theorem setSlice!_slice {α : Type} [Inhabited α] (L : List α) (a b : Nat) (h : a ≤ b ∧ b ≤ L.length) :
    L.setSlice! a (L.slice a b) = L := by
  apply ext_getElem! (by simp)
  intro j hj
  simp only [List.length_setSlice!] at hj
  by_cases hin : a ≤ j ∧ j < b
  · rw [List.getElem!_setSlice!_middle _ _ _ _ ⟨hin.1, by simp [List.slice]; omega, hj⟩]
    simp only [List.slice, List.getElem!_eq_getElem?_getD, List.getElem?_take, List.getElem?_drop]
    rw [if_pos (by omega), show a + (j - a) = j by omega]
  · rw [List.getElem!_setSlice!_same _ _ _ _ (by simp [List.slice]; omega)]

/-- The whole lanes' loop of `add_bytes` XORs lane `i` of `P` into state lane
`first + i`, through the view `L.setSlice! first`. -/
theorem add_bytes_loop_spec (L : List U64) (hL : L.length = 25) (first nl : Nat)
    (hfirst : first + nl ≤ 25) (P : List U8) (hP : 8 * nl ≤ P.length)
    (iter : core.iter.adapters.enumerate.Enumerate (core.slice.iter.Iter (Std.Array U8 8#usize)))
    (hsl : iter.iter.slice.val.length = nl)
    (hel : ∀ i, i < nl → (iter.iter.slice.val[i]!).val = (P.drop (8 * i)).take 8)
    (hi : iter.iter.i = iter.count.val) (hk : iter.count.val ≤ nl)
    (w : Slice U64) (hw : w.length = nl)
    (hst : sbl (L.setSlice! first w.val) = xorAt (sbl L) (8 * first) (bv (P.take (8 * iter.count.val)))) :
    mid.sha3.add_bytes_loop iter w ⦃ w' =>
      w'.length = nl ∧ sbl (L.setSlice! first w'.val) = xorAt (sbl L) (8 * first) (bv (P.take (8 * nl))) ⦄ := by
  unfold mid.sha3.add_bytes_loop
  apply loop.spec_decr_nat (fun x => nl - x.1.count.val)
    (fun x => x.1.iter.slice.val.length = nl ∧
      (∀ i, i < nl → (x.1.iter.slice.val[i]!).val = (P.drop (8 * i)).take 8) ∧
      x.1.iter.i = x.1.count.val ∧ x.1.count.val ≤ nl ∧ x.2.length = nl ∧
      sbl (L.setSlice! first x.2.val) = xorAt (sbl L) (8 * first) (bv (P.take (8 * x.1.count.val))))
  · rintro ⟨it, w⟩ ⟨hsl, hel, hi, hk, hw, hst⟩
    simp only at hsl hel hi hk hw hst ⊢
    unfold mid.sha3.add_bytes_loop.body
    simp only [core.iter.adapters.enumerate.IteratorEnumerate.next,
      core.slice.iter.IteratorSliceIter.next]
    split
    · rename_i hlt
      have hlt' : it.count.val < nl := by
        have : it.iter.slice.len.val = nl := by simp [Slice.len, hsl]
        omega
      step*
      have hc : it.iter.slice[it.iter.i] = it.iter.slice.val[it.count.val]! := by
        rw [getElem!_pos _ _ (by omega)]; simp only [hi]; rfl
      have hwl : w.val.length = nl := hw
      have hcl : ∀ a : Std.Array U8 8#usize, (bv a.val).length = 8 := fun a => by simp [bv]
      refine ⟨hsl, hel, by omega, by omega, by simp [s_post, Slice.length, hw], ?_, by omega⟩
      rw [s_post, Slice.set_val_eq, setSlice!_set _ _ _ _ _ (by rw [hL]; omega) (by omega),
        sbl_set_xor _ (first + it.count.val) (by simp [hL]; omega) i3 i1.bv
          (by refine i3_post1.trans ?_
              rw [i2_post, List.getElem!_setSlice!_middle _ _ _ _
            ⟨by omega, by omega, by simp [hL]; omega⟩, show first + it.count.val - first =
            it.count.val by omega, getElem!_pos w.val _ (by omega)])
          0 (bv (it.iter.slice.val[it.count.val]!).val) (by rw [Nat.zero_add, hcl])
          (by
            intro m t hm ht
            rw [i1_post, hc, BitVec.getElem!_cast, BitVec.fromLEBytes_getElem!,
              show (8 * m + t) / 8 = m by omega, show (8 * m + t) % 8 = t by omega,
              if_pos ⟨Nat.zero_le _, by rw [Nat.zero_add, hcl]; omega⟩, Nat.sub_zero]
            rfl),
        hst, Nat.add_zero, show 8 * (first + it.count.val) = 8 * first + (bv (P.take (8 * it.count.val))).length by
          simp [bv]; omega,
        xorAt_xorAt, hel _ hlt', x_post, show 8 * (it.count.val + 1) = 8 * it.count.val + 8 by ring,
        List.take_add, bv, bv, bv, List.map_append]
    · rename_i hlt
      have hk' : it.count.val = nl := by
        have : it.iter.slice.len.val = nl := by simp [Slice.len, hsl]
        omega
      rw [hk'] at hst
      simpa [WP.spec_ok] using ⟨hw, hst⟩
  · exact ⟨hsl, hel, hi, hk, hw, hst⟩

/-- `add_bytes` XORs `bytes` into the state's bytes from `offset`. -/
theorem add_bytes_spec (s : Std.Array U64 25#usize) (off : Usize) (bytes : Slice U8)
    (h : off.val + bytes.length ≤ 200) :
    mid.sha3.add_bytes s off bytes ⦃ r => sbl r.val = xorAt (sbl s.val) off.val (bv bytes.val) ⦄ := by
  unfold mid.sha3.add_bytes
  step*
  have hlead : lead.val = min ((8 - off.val % 8) % 8) bytes.length := by
    rw [lead_post, core.cmp.impls.OrdUsize.min_val, i1_post, i_post, shift_post]; rfl
  have hbl : (bv bytes.val).length = bytes.length := by simp [bv, Slice.length]
  have hsl : s.val.length = 25 := by simp
  -- The head, up to the next lane boundary.
  have hhead : (if b = true then ok s else do
      let i3 ← mid.sha3.partial_lane head
      let i4 ← 8#usize * shift
      let i5 ← i3 <<< i4
      let i6 ← s.index_usize lane
      let i7 ← lift (i6 ^^^ i5)
      s.update lane i7) ⦃ s1 => sbl s1.val = xorAt (sbl s.val) off.val (bv head.val) ⦄ := by
    by_cases hb : b = true
    · have : head.val = [] := by
        have := b_post ▸ hb; simpa [Slice.length] using this
      simp [hb, this, bv, WP.spec_ok]
    · simp only [hb, Bool.false_eq_true, ↓reduceIte]
      have hne : head.length ≠ 0 := by intro h0; exact hb (b_post ▸ h0)
      have hsh : 0 < off.val % 8 := by
        by_contra h0; apply hne; rw [head_post, hlead]; simp; omega
      have hhl : head.length ≤ 8 - off.val % 8 := by rw [head_post, hlead]; omega
      step with partial_lane_spec head (by omega) as ⟨i3, hi3⟩
      step*
      have hhb : (bv head.val).length = head.length := by simp [bv, Slice.length]
      have hx7 : i7.bv = (s.val[lane.val]!).bv ^^^ i5.bv := by
        simp only [i7_post1, i6_post, getElem!_pos s.val lane.val (by omega)]
      have hw5 : ∀ m t, m < 8 → t < 8 → i5.bv[8 * m + t]! =
          if shift.val ≤ m ∧ m < shift.val + (bv head.val).length then
            (bv head.val)[m - shift.val]!.toNat.testBit t else false := by
        intro m t hm ht
        simp only [i5_post1, i4_post]
        by_cases hm' : shift.val ≤ m
        · rw [BitVec.getElem!_shiftLeft_eq _ _ _ ⟨by omega, by omega⟩,
            show 8 * m + t - 8 * shift.val = 8 * (m - shift.val) + t by omega,
            hi3 (m - shift.val) t (by omega) ht, hhb]
          by_cases hc : m - shift.val < head.length
          · rw [if_pos hc, if_pos ⟨hm', by omega⟩]
          · rw [if_neg hc, if_neg (by omega)]
        · rw [BitVec.getElem!_shiftLeft_false _ _ _ (Or.inl (by omega)), if_neg (by omega)]
      rw [s1_post, Std.Array.set_val_eq, sbl_set_xor s.val lane.val (by omega) i7 i5.bv hx7
        shift.val (bv head.val) (by omega) hw5, show 8 * lane.val + shift.val = off.val by omega]
  step with hhead as ⟨s1, hs1⟩
  have hdc : core.num.Usize.div_ceil off 8#usize ⦃ r => r.val = (off.val + 7) / 8 ⦄ := by
    simp [core.num.Usize.div_ceil, WP.spec_ok]
  step with hdc as ⟨first, hfirst⟩
  step with as_chunks_spec 8#usize bytes1 (by decide) as ⟨lanes, tail, hll, hle, htail⟩
  have hs1l : s1.val.length = 25 := by simp
  have hll' : lanes.val.length = bytes1.length / 8 := by simpa using hll
  have hal : bytes1.length ≠ 0 → off.val + lead.val = 8 * first.val := by
    intro hne; rw [hfirst, hlead]; omega
  have hfl : first.val + lanes.val.length ≤ 25 := by
    by_cases hb1 : bytes1.length = 0
    · rw [hll', hb1]; omega
    · have := hal hb1; rw [hll']; omega
  step*
  have hwl : whole.length = lanes.val.length := by rw [whole_post1, i4_post]; simp [Slice.len]
  have hst0 : sbl (s1.val.setSlice! first.val whole.val) =
      xorAt (sbl s1.val) (8 * first.val) (bv (bytes1.val.take (8 * (0#usize : Usize).val))) := by
    rw [whole_post, setSlice!_slice _ _ _ (by rw [i4_post]; simp [Slice.len]; omega)]
    simp [bv]
  simp only [core.slice.Slice.iter, core.iter.traits.iterator.Iterator.enumerate.trait_default,
    core.iter.traits.iterator.Iterator.enumerate.default, bind_ok]
  have hP : 8 * lanes.val.length ≤ bytes1.val.length := by
    rw [hll']; simp only [Slice.length]; omega
  step with add_bytes_loop_spec s1.val hs1l first.val lanes.val.length hfl bytes1.val hP
    { iter := { slice := lanes, i := 0 }, count := 0#usize } rfl (by
      intro i hi; rw [hle i hi, Nat.mul_comm]) rfl (by simp) whole hwl
    hst0 as ⟨w1, hw1l, hw1⟩
  have hhl : (bv head.val).length = lead.val := by simp [bv, ← head_post, Slice.length]
  have hTl : (bv (bytes1.val.take (8 * lanes.val.length))).length = 8 * lanes.val.length := by
    rw [bv, List.length_map, List.length_take]; omega
  have hcomb : sbl (index_mut_back w1).val =
      xorAt (sbl s.val) off.val (bv head.val ++ bv (bytes1.val.take (8 * lanes.val.length))) := by
    rw [whole_post2, hw1, hs1, xorAt_xorAt' _ _ _ _ _ (by
      intro hne
      have : bytes1.length ≠ 0 := by
        intro h0; apply hne; simp [bv, Slice.length] at h0 ⊢; simp [h0]
      rw [hhl, hal this])]
  have htl : tail.val.length = bytes1.length - 8 * lanes.val.length := by
    rw [htail, hll']; simp only [Slice.length]; simp; omega
  have hsplit : bv bytes.val = bv head.val ++ bv (bytes1.val.take (8 * lanes.val.length)) ++ bv tail.val := by
    rw [htail, hll', head_post2, head_post3, show bytes1.length / 8 * 8 = 8 * (bytes1.length / 8) by ring]
    simp only [bv, ← List.map_append, List.append_assoc, List.take_append_drop]
  step*
  · have ht0 : tail.val = [] := by
      have := b1_post ▸ (by assumption : b1 = true); simpa [Slice.length] using this
    rw [hcomb, hsplit, ht0]; simp [bv]
  · have hne : tail.length ≠ 0 := by
      intro h0; apply (by assumption : ¬b1 = true); exact b1_post ▸ h0
    step with partial_lane_spec tail (by simp only [Slice.length] at hne ⊢; omega) as ⟨i6, hi6⟩
    step*
    have hi8 : i8.val = first.val + lanes.val.length := by rw [i8_post]; simp [Slice.len]
    have htl' : tail.length = tail.val.length := rfl
    have hb1ne : bytes1.length ≠ 0 := by omega
    have hal' := hal hb1ne
    have hk : i8.val < 25 := by rw [hi8, hll']; omega
    have hx : i10.bv = ((index_mut_back w1).val[i8.val]!).bv ^^^ i6.bv := by
      simp only [i10_post1, i9_post, getElem!_pos (index_mut_back w1).val i8.val (by simp; omega)]
    have hbt : (bv tail.val).length = tail.length := by simp [bv, Slice.length]
    have hw : ∀ m t, m < 8 → t < 8 → i6.bv[8 * m + t]! =
        if 0 ≤ m ∧ m < 0 + (bv tail.val).length then (bv tail.val)[m - 0]!.toNat.testBit t
        else false := by
      intro m t hm ht
      rw [hi6 m t hm ht, hbt, Nat.zero_add, Nat.sub_zero]
      by_cases hc : m < tail.length
      · rw [if_pos hc, if_pos ⟨Nat.zero_le _, hc⟩]
      · rw [if_neg hc, if_neg (by omega)]
    rw [r_post, Std.Array.set_val_eq, sbl_set_xor _ i8.val (by simp; omega) i10 i6.bv hx 0
      (bv tail.val) (by rw [hbt]; omega) hw, hcomb, xorAt_xorAt' _ _ _ _ _ (fun _ => by
        simp only [List.length_append, hhl, hTl]; omega), hsplit, List.append_assoc]

/-! ## `store_bytes` -/

theorem getElem!_sbl (L : List U64) (j : Nat) :
    (sbl L)[j]! = (L[j / 8]!).bv.toLEBytes[j % 8]! := by
  apply Spec.Byte.ext_testBit
  intro t ht
  rw [sbl_testBit _ _ _ ht]
  have := BitVec.toLEBytes_getElem!_testBit (L[j / 8]!).bv (j % 8) t ht
  simp only [Byte.testBit] at this
  rw [this]

theorem getElem!_bv (l : List U8) (j : Nat) : (bv l)[j]! = (l[j]!).bv := by
  simp only [bv, List.getElem!_eq_getElem?_getD, List.getElem?_map]
  cases l[j]? <;> rfl

/-- `store_bytes` writes the state's first bytes. -/
theorem store_bytes_spec (s : Std.Array U64 25#usize) (output : Slice U8) (h : output.length ≤ 200) :
    mid.sha3.store_bytes s output ⦃ r =>
      r.length = output.length ∧ bv r.val = (sbl s.val).take output.length ⦄ := by
  unfold mid.sha3.store_bytes mid.sha3.store_bytes_loop
  apply loop.spec_decr_nat (fun x => output.length - x.2.val)
    (fun x => x.1.length = output.length ∧ x.2.val ≤ output.length ∧
      (x.2.val % 8 = 0 ∨ x.2.val = output.length) ∧
      ∀ j, j < x.2.val → (bv x.1.val)[j]! = (sbl s.val)[j]!)
  · rintro ⟨out, done⟩ ⟨hl, hd, hd8, hpre⟩
    simp only at hl hd hd8 hpre ⊢
    unfold mid.sha3.store_bytes_loop.body
    have hlen : out.len.val = output.length := by rw [← hl]; rfl
    have hol : out.val.length = output.length := hl
    have hoL : output.length = output.val.length := rfl
    have hs25 : s.val.length = 25 := by simp
    simp only []
    split
    · rename_i hlt
      have hdl : done.val < output.length := by
        have : done.val < out.len.val := hlt
        omega
      step*
      · rw [s1_post1, s2_post1, i3_post]
        omega
      · have hn : n.val = min 8 (output.length - done.val) := by
          rw [n_post, core.cmp.impls.OrdUsize.min_val, i2_post, hlen]; rfl
        have hd0 : done.val % 8 = 0 := by omega
        refine ⟨by rw [s1_post2]; simp [hl], by omega, by omega, ?_, by omega⟩
        intro j hj
        rw [s1_post2, Slice.setSlice!_val, s3_post]
        by_cases hjd : j < done.val
        · rw [getElem!_bv, List.getElem!_setSlice!_prefix _ _ _ _ hjd, ← getElem!_bv, hpre j hjd]
        · have hs2l : s2.val.length = n.val := s2_post1
          have hi5 : s.val[i4.val]! = i5 := by rw [i5_post, getElem!_pos s.val i4.val (by omega)]
          rw [getElem!_bv, List.getElem!_setSlice!_middle _ _ _ _ ⟨by omega, by omega, by omega⟩,
            s2_post, getElem!_sbl, show j / 8 = i4.val by omega, show j % 8 = j - done.val by omega,
            hi5]
          simp only [List.slice, List.drop_zero, Array.val_to_slice, a_post]
          rw [List.getElem!_eq_getElem?_getD, List.getElem?_take, if_pos (by omega),
            List.getElem?_map, List.getElem?_eq_getElem (by simp; omega),
            List.getElem!_eq_getElem?_getD, List.getElem?_eq_getElem (by simp; omega)]
          rfl
    · rename_i hnd
      have hdl : done.val = output.length := by
        have : ¬ done.val < out.len.val := hnd
        omega
      simp only [WP.spec_ok]
      refine ⟨hl, ?_⟩
      apply ext_getElem! (by
        rw [bv, List.length_map, List.length_take, length_sbl, hs25]; omega)
      intro j hj
      rw [bv, List.length_map] at hj
      rw [hpre j (by omega), List.getElem!_eq_getElem?_getD (l := List.take _ _), List.getElem?_take,
        if_pos (by omega), ← List.getElem!_eq_getElem?_getD]
  · exact ⟨rfl, by simp, by simp, by simp⟩

/-! ## Keccak-f on the state's bytes -/

theorem length_stateBytes (L : List (BitVec 64)) : (stateBytes L).length = 8 * L.length := by
  induction L with
  | nil => rfl
  | cons a L ih =>
    simp only [stateBytes, List.flatMap_cons, List.length_append, BitVec.toLEBytes_length,
      List.length_cons] at ih ⊢
    rw [ih]; ring

theorem stateLanes_stateBytes (L : List (BitVec 64)) (hL : L.length = 25) :
    stateLanes (stateBytes L) = L := by
  apply List.ext_getElem (by simp [stateLanes, hL])
  intro i h1 h2
  simp only [stateLanes, List.getElem_map, List.getElem_range]
  rw [BitVec.eq_iff]
  intro p hp
  rw [BitVec.getElem!_setWidth _ _ _ hp, BitVec.fromLEBytes_getElem!, List.getElem!_eq_getElem?_getD,
    List.getElem?_take, if_pos (by omega), List.getElem?_drop, ← List.getElem!_eq_getElem?_getD]
  have := testBit_flatMap_toLEBytes L (8 * i + p / 8) (p % 8) (by omega)
  rw [← stateBytes] at this
  simp only [Byte.testBit, List.getElem_range]
  rw [this, show (8 * i + p / 8) / 8 = i by omega, show 8 * ((8 * i + p / 8) % 8) + p % 8 = p by omega,
    getElem!_pos L i (by omega)]

theorem keccakF_sbl (a r : Std.Array U64 25#usize) (h : lanes r = keccak 24 (lanes a)) :
    sbl r.val = keccakF (sbl a.val) := by
  rw [keccakF, sbl, stateLanes_stateBytes _ (by simp)]
  exact congrArg stateBytes h

@[simp] theorem length_sbl_array (a : Std.Array U64 25#usize) : (sbl a.val).length = 200 := by
  rw [length_sbl]; simp

/-! ## Squeezing, `SqueezingSponge::squeeze` -/

theorem div_block (R c k : Nat) (_hR : 0 < R) (h1 : R * c ≤ k) (h2 : k < R * c + R) :
    k / R = c ∧ k % R = k - R * c := by
  have hd : k / R = c := by
    apply Nat.div_eq_of_lt_le
    · rw [Nat.mul_comm]; exact h1
    · rw [Nat.add_mul, Nat.one_mul, Nat.mul_comm]; exact h2
  refine ⟨hd, ?_⟩
  have := Nat.mod_add_div k R
  rw [hd] at this
  omega

theorem iterate_keccakF_succ (c : Nat) (S : List Byte) :
    keccakF^[c] (keccakF S) = keccakF^[c + 1] S := by
  rw [Function.iterate_succ_apply]

theorem ceil_div_eq (R L c : Nat) (hR : 0 < R) (h1 : L ≤ R * c) (h2 : c = 0 ∨ R * (c - 1) < L) :
    (L + R - 1) / R = c := by
  rcases Nat.eq_zero_or_pos c with hc | hc
  · subst hc; rw [Nat.mul_zero] at h1
    rw [show L = 0 by omega]; exact Nat.div_eq_of_lt (by omega)
  · have h2' : R * (c - 1) < L := by rcases h2 with h2 | h2 <;> omega
    have key : R * (c - 1) + R = R * c := by
      rw [← Nat.mul_succ]; congr 1; omega
    apply Nat.div_eq_of_lt_le
    · rw [Nat.mul_comm]; omega
    · rw [Nat.add_mul, Nat.one_mul, Nat.mul_comm]; omega

/-- The squeeze loop: block `c` of the output after `c + 1` Keccak-fs. -/
theorem squeeze_loop_spec (h : RunsSha3) {R : Usize} (hR : 0 < R.val ∧ R.val ≤ 200) (S0 : List Byte)
    (L : Nat) (self : mid.sha3.SqueezingSponge R) (output : Slice U8) (done : Usize) (c : Nat)
    (hl : output.length = L) (hd : done.val = min (R.val * c) L) (hc : c = 0 ∨ R.val * (c - 1) < L)
    (hs : sbl self.s.val = keccakF^[c] S0)
    (hpre : ∀ k, k < done.val → (bv output.val)[k]! = (keccakF^[k / R.val + 1] S0)[k % R.val]!) :
    mid.sha3.SqueezingSponge.squeeze_loop self output done ⦃ r =>
      r.2.length = L ∧
      (∀ k, k < L → (bv r.2.val)[k]! = (keccakF^[k / R.val + 1] S0)[k % R.val]!) ∧
      sbl r.1.s.val = keccakF^[(L + R.val - 1) / R.val] S0 ⦄ := by
  unfold mid.sha3.SqueezingSponge.squeeze_loop
  apply loop.spec_decr_nat (fun x => L - x.2.2.val)
    (fun x => ∃ c, x.2.1.length = L ∧ x.2.2.val = min (R.val * c) L ∧ (c = 0 ∨ R.val * (c - 1) < L) ∧
      sbl x.1.s.val = keccakF^[c] S0 ∧
      ∀ k, k < x.2.2.val → (bv x.2.1.val)[k]! = (keccakF^[k / R.val + 1] S0)[k % R.val]!)
  · rintro ⟨self, out, done⟩ ⟨c, hl, hd, hc, hs, hpre⟩
    simp only at hl hd hc hs hpre ⊢
    unfold mid.sha3.SqueezingSponge.squeeze_loop.body
    have hlen : out.len.val = L := by rw [← hl]; rfl
    have hol : out.val.length = L := hl
    simp only []
    split
    · rename_i hlt
      have hdl : done.val < L := by
        have : done.val < out.len.val := hlt
        omega
      have hdc : done.val = R.val * c := by
        rcases Nat.le_total (R.val * c) L with h' | h' <;> simp [h'] at hd <;> omega
      step as ⟨i2, i2_post, i2_post1⟩
      step as ⟨n, n_post⟩
      have hn : n.val = min R.val (L - done.val) := by
        rw [n_post, core.cmp.impls.OrdUsize.min_val, i2_post, hlen]
      step with keccak_f1600_spec h self.s as ⟨a, ha⟩
      have hsa : sbl a.val = keccakF^[c + 1] S0 := by
        rw [keccakF_sbl self.s a ha, hs, Function.iterate_succ_apply']
      step as ⟨i3, hi3⟩
      step as ⟨sl, back, hsl, hsll, hback⟩
      step with store_bytes_spec a sl (by rw [hsll]; omega) as ⟨s1, hs1l, hs1⟩
      have hRc : R.val * (c + 1) = R.val * c + R.val := Nat.mul_succ _ _
      refine ⟨⟨c + 1, by rw [hback]; simp [hl], by rw [hi3, hn, hRc]; omega,
        Or.inr (by rw [Nat.add_sub_cancel]; omega), hsa, ?_⟩, by omega⟩
      intro k hk
      rw [hback, Slice.setSlice!_val]
      by_cases hkd : k < done.val
      · rw [getElem!_bv, List.getElem!_setSlice!_prefix _ _ _ _ hkd, ← getElem!_bv, hpre k hkd]
      · have hs1v : s1.val.length = sl.length := hs1l
        rw [getElem!_bv, List.getElem!_setSlice!_middle _ _ _ _ ⟨by omega, by omega, by omega⟩,
          ← getElem!_bv, hs1, List.getElem!_eq_getElem?_getD, List.getElem?_take, if_pos (by omega),
          ← List.getElem!_eq_getElem?_getD, hsa]
        obtain ⟨hk1, hk2⟩ := div_block R.val c k hR.1 (by omega) (by omega)
        rw [hk1, hk2, hdc]
    · rename_i hnd
      have hdl : done.val = L := by
        have : ¬ done.val < out.len.val := hnd
        omega
      simp only [WP.spec_ok]
      refine ⟨hl, by rw [← hdl]; exact hpre, ?_⟩
      rw [hs, ceil_div_eq R.val L c hR.1 (by omega) hc]
  · exact ⟨c, hl, hd, hc, hs, hpre⟩

/-- `squeeze` writes FIPS 202's output from a state owing its Keccak-f, and
leaves the state as many Keccak-fs on as it took blocks. -/
theorem squeeze_spec (h : RunsSha3) {R : Usize} (hR : 0 < R.val ∧ R.val ≤ 200)
    (self : mid.sha3.SqueezingSponge R) (output : Slice U8) :
    mid.sha3.SqueezingSponge.squeeze self output ⦃ r =>
      r.2.length = output.length ∧
      bv r.2.val = squeeze R.val output.length (keccakF (sbl self.s.val)) ∧
      sbl r.1.s.val = keccakF^[(output.length + R.val - 1) / R.val] (sbl self.s.val) ⦄ := by
  unfold mid.sha3.SqueezingSponge.squeeze
  step with sha3_assert_held_spec h as ⟨u, _hu⟩
  apply WP.spec_mono (squeeze_loop_spec h hR (sbl self.s.val) output.length self output 0#usize 0
    rfl (by simp) (Or.inl rfl) (by simp) (by simp))
  rintro r ⟨h1, h2, h3⟩
  refine ⟨h1, ?_, h3⟩
  apply ext_getElem! (by simp [bv, squeeze]; exact h1)
  intro k hk
  rw [bv, List.length_map] at hk
  have hk' : k < output.length := by rw [← h1]; exact hk
  rw [h2 k hk', squeeze, getElem!_pos _ k (by simp; omega), List.getElem_map, List.getElem_range,
    iterate_keccakF_succ]

/-- Squeezing on: the output past `c` whole blocks is the output of the state
`c` Keccak-fs on. -/
theorem squeeze_append (R c n : Nat) (hR : 0 < R) (T : List Byte) :
    squeeze R (R * c + n) T = squeeze R (R * c) T ++ squeeze R n (keccakF^[c] T) := by
  apply ext_getElem! (by simp [squeeze])
  intro k hk
  simp only [squeeze, List.length_map, List.length_range] at hk
  rw [getElem!_append_if]
  simp only [squeeze, List.length_map, List.length_range]
  by_cases hkc : k < R * c
  · rw [if_pos hkc, getElem!_pos _ k (by simp; omega), getElem!_pos _ k (by simp; omega)]
    simp
  · rw [if_neg hkc, getElem!_pos _ k (by simp; omega), getElem!_pos _ (k - R * c) (by simp; omega)]
    simp only [List.getElem_map, List.getElem_range]
    rw [← Function.iterate_add_apply]
    have h1 : k / R = (k - R * c) / R + c := by
      conv_lhs => rw [show k = (k - R * c) + R * c by omega]
      rw [Nat.add_mul_div_left _ _ hR]
    have h2 : k % R = (k - R * c) % R := by
      conv_lhs => rw [show k = (k - R * c) + R * c by omega]
      exact Nat.add_mul_mod_self_left _ _ _
    rw [h1, h2]

/-! ## Absorbing, `Sponge::absorb` -/

/-- The all-zero state. -/
abbrev zeros : List Byte := List.replicate 200 0

theorem blocks_single (R : Nat) (hR : 0 < R) (B : List Byte) (hB : B.length = R) :
    rind.spec.blocks R B = [B] := by
  rw [blocks_eq_map R hR, hB, Nat.div_self hR]
  simp [← hB]

theorem blocks_short (R : Nat) (hR : 0 < R) (r : List Byte) (hr : r.length < R) :
    rind.spec.blocks R r = [] := by
  rw [blocks_eq_map R hR, Nat.div_eq_of_lt hr]
  rfl

theorem absorb_append_block (R : Nat) (hR : 0 < R) (S P B : List Byte) (hP : P.length % R = 0)
    (hB : B.length = R) : absorb R S (P ++ B) = keccakF (xorAt (absorb R S P) 0 B) := by
  simp only [absorb]
  rw [blocks_append hR _ _ hP, blocks_single R hR B hB, List.foldl_append]
  rfl

theorem absorb_append_short (R : Nat) (hR : 0 < R) (S P r : List Byte) (hP : P.length % R = 0)
    (hr : r.length < R) : absorb R S (P ++ r) = absorb R S P := by
  simp only [absorb]
  rw [blocks_append hR _ _ hP, blocks_short R hR r hr, List.append_nil]

/-- A sponge state that has absorbed `m`: its whole blocks `P` permuted in, and
the `used` bytes after them XORed in. -/
def SpongeAbsorbed (R : Nat) (s : Std.Array U64 25#usize) (used : Nat) (m : List Byte) : Prop :=
  ∃ P r, m = P ++ r ∧ P.length % R = 0 ∧ r.length < R ∧ used = r.length ∧
    sbl s.val = xorAt (absorb R zeros P) 0 r

theorem sbl_zero : sbl (Std.Array.repeat 25#usize 0#u64).val = zeros := by
  apply ext_getElem! (by simp [length_sbl])
  intro j hj
  rw [length_sbl] at hj; simp at hj
  apply Spec.Byte.ext_testBit
  intro t ht
  rw [sbl_testBit _ _ _ ht, getElem!_pos zeros j (by simp; omega), List.getElem_replicate]
  have : (Std.Array.repeat 25#usize 0#u64).val[j / 8]! = 0#u64 := by
    have hr : (Std.Array.repeat 25#usize 0#u64).val = List.replicate 25 0#u64 := rfl
    rw [hr, getElem!_pos _ (j / 8) (by simp; omega), List.getElem_replicate]
  rw [this]
  simp

/-- `Sponge::new` has absorbed nothing. -/
theorem sponge_new_spec (R : Usize) (hR : 0 < R.val) (PAD : U8) :
    mid.sha3.Sponge.new R PAD ⦃ sp => SpongeAbsorbed R.val sp.s sp.used.val [] ⦄ := by
  unfold mid.sha3.Sponge.new
  simp only [WP.spec_ok]
  refine ⟨[], [], rfl, by simp, by simpa using hR, rfl, ?_⟩
  rw [sbl_zero]
  simp [absorb, blocks_nil]

/-- The absorb loop permutes in block after block. -/
theorem absorb_loop_spec (h : RunsSha3) {R : Usize} (hR : 0 < R.val ∧ R.val ≤ 200) (m1 : List Byte)
    (hm1 : m1.length % R.val = 0) (P : List U8) (nb : Nat) (hP : R.val * nb ≤ P.length)
    (iter : core.slice.iter.Iter (Std.Array U8 R)) (hsl : iter.slice.val.length = nb)
    (hel : ∀ i, i < nb → (iter.slice.val[i]!).val = (P.drop (i * R.val)).take R.val)
    (hi : iter.i ≤ nb) (a : Std.Array U64 25#usize)
    (ha : sbl a.val = absorb R.val zeros (m1 ++ bv (P.take (iter.i * R.val)))) :
    mid.sha3.Sponge.absorb_loop iter a ⦃ r =>
      sbl r.val = absorb R.val zeros (m1 ++ bv (P.take (nb * R.val))) ⦄ := by
  unfold mid.sha3.Sponge.absorb_loop
  apply loop.spec_decr_nat (fun x => nb - x.1.i)
    (fun x => x.1.slice.val.length = nb ∧
      (∀ i, i < nb → (x.1.slice.val[i]!).val = (P.drop (i * R.val)).take R.val) ∧ x.1.i ≤ nb ∧
      sbl x.2.val = absorb R.val zeros (m1 ++ bv (P.take (x.1.i * R.val))))
  · rintro ⟨it, a⟩ ⟨hsl, hel, hi, ha⟩
    simp only at hsl hel hi ha ⊢
    unfold mid.sha3.Sponge.absorb_loop.body
    simp only [core.slice.iter.IteratorSliceIter.next]
    split
    · rename_i hlt
      have hlt' : it.i < nb := by
        have : it.i < it.slice.len.val := hlt
        simpa [Slice.len, hsl] using this
      have hblk : (it.slice[it.i]'hlt).val = (P.drop (it.i * R.val)).take R.val := by
        rw [← hel it.i hlt', getElem!_pos it.slice.val it.i (by omega)]; rfl
      have hbl : (it.slice[it.i]'hlt).val.length = R.val := by simp
      simp only [bind_ok]
      step as ⟨sl, hsl'⟩
      step with add_bytes_spec a 0#usize sl (by simp [Slice.length, hsl', hbl]; omega) as ⟨a1, ha1⟩
      step with keccak_f1600_spec h a1 as ⟨a2, ha2⟩
      refine ⟨hsl, hel, by omega, ?_, by omega⟩
      have hRi : R.val * (it.i + 1) ≤ P.length := by
        have := Nat.mul_le_mul_left R.val (show it.i + 1 ≤ nb by omega); omega
      have hRi' : it.i * R.val + R.val ≤ P.length := by
        rw [show it.i * R.val + R.val = R.val * (it.i + 1) by ring]; exact hRi
      rw [keccakF_sbl a1 a2 ha2, ha1, ha,
        ← absorb_append_block R.val hR.1 _ _ _ (by
          rw [List.length_append, bv, List.length_map, List.length_take,
            Nat.min_eq_left (by omega), Nat.add_mod, hm1, Nat.mul_mod_left]; simp)
        (by simp [bv, hsl', hbl]),
        hsl', Array.val_to_slice, hblk, List.append_assoc, bv, bv, bv, ← List.map_append,
        ← List.take_add, show it.i * R.val + R.val = (it.i + 1) * R.val by ring]
    · rename_i hnd
      have hi' : it.i = nb := by
        have : ¬ it.i < it.slice.len.val := hnd
        simp [Slice.len, hsl] at this; omega
      rw [← hi']
      simpa [WP.spec_ok] using ha
  · exact ⟨hsl, hel, hi, ha⟩

/-- `Sponge::absorb` absorbs `bytes` after what the sponge has absorbed. -/
theorem sponge_absorb_spec (h : RunsSha3) {R : Usize} {PAD : U8} (hR : 0 < R.val ∧ R.val ≤ 200)
    (sp : mid.sha3.Sponge R PAD) (m : List Byte) (hm : SpongeAbsorbed R.val sp.s sp.used.val m)
    (bytes : Slice U8) :
    mid.sha3.Sponge.absorb sp bytes ⦃ sp' =>
      SpongeAbsorbed R.val sp'.s sp'.used.val (m ++ bv bytes.val) ⦄ := by
  obtain ⟨P0, r0, hm, hP0, hr0, hu, hs⟩ := hm
  have hbl : (bv bytes.val).length = bytes.length := by simp [bv, Slice.length]
  unfold mid.sha3.Sponge.absorb
  step as ⟨room, hroom⟩
  split
  · rename_i hlt
    have hlt' : bytes.length < room.val := hlt
    step with add_bytes_spec sp.s sp.used bytes (by omega) as ⟨a, ha⟩
    step as ⟨u, hu'⟩
    refine ⟨P0, r0 ++ bv bytes.val, by rw [hm, List.append_assoc], hP0,
      by rw [List.length_append, hbl]; omega, by rw [hu', List.length_append, hbl, hu]; rfl, ?_⟩
    rw [ha, hs, hu, ← xorAt_xorAt, Nat.zero_add]
  · rename_i hge
    have hge' : room.val ≤ bytes.length := by
      have : ¬ bytes.len.val < room.val := hge
      exact Nat.le_of_not_lt this
    step with sha3_new_secret_spec h as ⟨e, _he⟩
    step as ⟨head, bytes1, hhl, hb1l, hhv, hb1v⟩
    step with add_bytes_spec sp.s sp.used head (by omega) as ⟨a, ha⟩
    step with keccak_f1600_spec h a as ⟨a1, ha1⟩
    have hhb : (bv head.val).length = room.val := by simp [bv, Slice.length] at hhl ⊢; exact hhl
    have hblk : (r0 ++ bv head.val).length = R.val := by
      rw [List.length_append, hhb]; omega
    have hsa1 : sbl a1.val = absorb R.val zeros (P0 ++ (r0 ++ bv head.val)) := by
      rw [keccakF_sbl a a1 ha1, ha, hs, hu, xorAt_xorAt' _ 0 _ _ _ (fun _ => by simp),
        absorb_append_block R.val hR.1 _ _ _ hP0 hblk]
    step with as_chunks_spec R bytes1 hR.1 as ⟨blocks, rest, hnb, hbe, hrest⟩
    step as ⟨iter, hit, hit0⟩
    have hm1 : (P0 ++ (r0 ++ bv head.val)).length % R.val = 0 := by
      rw [List.length_append, hblk, Nat.add_mod, hP0, Nat.mod_self]; simp
    have hnbR : R.val * blocks.val.length ≤ bytes1.val.length := by
      rw [hnb, Nat.mul_comm]; exact Nat.div_mul_le_self _ _
    step with absorb_loop_spec h hR _ hm1 bytes1.val blocks.val.length hnbR iter
      (by rw [hit]) (by rw [hit]; exact hbe) (by omega) a1 (by rw [hit0, hsa1]; simp [bv])
      as ⟨a2, ha2⟩
    have hrl : rest.val.length < R.val := by
      have e1 := Nat.div_add_mod' bytes1.length R.val
      have e2 := Nat.mod_lt bytes1.length hR.1
      have e3 : bytes1.val.length = bytes1.length := rfl
      rw [hrest, List.length_drop]; omega
    step with add_bytes_spec a2 0#usize rest (by simp [Slice.length]; omega) as ⟨a3, ha3⟩
    refine ⟨P0 ++ (r0 ++ bv head.val) ++ bv (bytes1.val.take (blocks.val.length * R.val)),
      bv rest.val, ?_, ?_, by simpa [bv] using hrl, by simp [bv, Slice.len], ?_⟩
    · rw [hm, hrest, hhv, hb1v, hnb]
      simp only [bv, List.append_assoc, ← List.map_drop, ← List.map_take]
      rw [← List.map_append, ← List.map_append, List.take_append_drop, List.take_append_drop]
    · have hT : (bv (bytes1.val.take (blocks.val.length * R.val))).length =
          blocks.val.length * R.val := by
        rw [bv, List.length_map, List.length_take]
        exact Nat.min_eq_left (by rw [Nat.mul_comm]; exact hnbR)
      rw [List.length_append, hT, Nat.add_mod, hm1, Nat.mul_mod_left]; simp
    · rw [ha3, ha2]

end rind.x86_64
