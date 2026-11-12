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

end rind.x86_64
