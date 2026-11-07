import Rind.X86_64.Hkdf
open Aeneas Aeneas.Std Result rind.spec

/-!
# PBKDF2's API, `high::pbkdf2`

`Secret::derive` writes RFC 8018's PBKDF2 and `Secret::verify` accepts exactly
it, over HMAC with any of `high::hmac`'s hashes, down to
`Rind.X86_64.HmacApi`. `Secret` is translated in the second Aeneas pass.
`admin/prove` writes the aarch64 proof from this file by renaming the target.
-/

namespace rind.x86_64.kdf

/-! ## PBKDF2's blocks -/

section
variable (prf : List Byte → List Byte → List Byte) (P S : List Byte)

/-- One PBKDF2 iteration: `U_j` from `U_(j-1)`, XORed into the sum. -/
def pbStep (acc : List Byte × List Byte) : List Byte × List Byte :=
  let u := prf P acc.1
  (u, List.zipWith (· ^^^ ·) acc.2 u)

/-- `U_1` of block `i`. -/
def pbU1 (i : Nat) : List Byte := prf P (S ++ (BitVec.ofNat 32 i).toBEBytes)

/-- `k` iterations from `acc`. -/
def pbIter (k : Nat) (acc : List Byte × List Byte) : List Byte × List Byte :=
  (List.range k).foldl (fun acc _ => pbStep prf P acc) acc

/-- Block `T_i` after `c` iterations. -/
def pbT (c i : Nat) : List Byte := (pbIter prf P (c - 1) (pbU1 prf P S i, pbU1 prf P S i)).2

theorem pbkdf2_eq (n c L : Nat) :
    pbkdf2 prf n P S c L = (blocksOut (pbT prf P S c) ((L + n - 1) / n)).take L := rfl

theorem pbIter_succ (k : Nat) (acc : List Byte × List Byte) :
    pbIter prf P (k + 1) acc = pbStep prf P (pbIter prf P k acc) := by
  simp [pbIter, List.range_succ, List.foldl_append]

theorem pbIter_length (n : Nat) (hn : ∀ x, (prf P x).length = n) (k : Nat)
    (acc : List Byte × List Byte) (h1 : acc.1.length = n) (h2 : acc.2.length = n) :
    (pbIter prf P k acc).1.length = n ∧ (pbIter prf P k acc).2.length = n := by
  induction k with
  | zero => exact ⟨h1, h2⟩
  | succ k ih =>
    rw [pbIter_succ]
    simp only [pbStep, List.length_zipWith, hn, ih.2, min_self, and_self]

theorem pbT_length (n : Nat) (hn : ∀ x, (prf P x).length = n) (c i : Nat) :
    (pbT prf P S c i).length = n :=
  (pbIter_length prf P n hn _ _ (hn _) (hn _)).2

end

/-! ## `Secret::block` -/

/-- `S` with its bytes before `k` XORed with `N`'s. -/
def xorUpTo (S N : List U8) (k : Nat) : List U8 :=
  S.mapIdx fun j x => if j < k then x ^^^ N[j]! else x

theorem xorUpTo_step (S N : List U8) (i : Nat) (hi : i < S.length) :
    (xorUpTo S N i).set i (S[i] ^^^ N[i]!) = xorUpTo S N (i + 1) := by
  simp only [xorUpTo]
  apply List.ext_getElem (by simp)
  intro j h1 h2
  rw [List.getElem_set]
  by_cases h : i = j
  · subst h; simp
  · rw [ite_eq_right h, List.getElem_mapIdx, List.getElem_mapIdx]
    by_cases hj : j < i
    · rw [ite_eq_left hj, ite_eq_left (by omega)]
    · rw [ite_eq_right hj, ite_eq_right (by omega)]

theorem xorUpTo_zero (S N : List U8) : xorUpTo S N 0 = S := by
  apply List.ext_getElem (by simp [xorUpTo])
  intro j h1 h2
  simp [xorUpTo]

theorem xorUpTo_end (S N : List U8) (hN : N.length = S.length) :
    bv (xorUpTo S N S.length) = List.zipWith (· ^^^ ·) (bv S) (bv N) := by
  apply List.ext_getElem (by simp [bv, xorUpTo, hN])
  intro j h1 h2
  simp only [bv, xorUpTo, List.length_map, List.length_mapIdx] at h1
  simp only [bv, xorUpTo, List.getElem_map, List.getElem_mapIdx, List.getElem_zipWith,
    ite_eq_left h1, UScalar.bv_xor]
  rw [getElem!_pos N j (by omega)]

theorem xor_loop_spec (S N : Slice U8) (hN : N.length = S.length) :
    ∀ (j : Usize) (sum : Slice U8), j.val ≤ S.length → sum.val = xorUpTo S.val N.val j.val →
    high.pbkdf2.Secret.block_loop0_loop0 { start := j, «end» := S.len } sum N ⦃ r =>
      bv r.val = List.zipWith (· ^^^ ·) (bv S.val) (bv N.val) ⦄ := by
  intro j sum hj hs
  unfold high.pbkdf2.Secret.block_loop0_loop0
  apply loop.spec_decr_nat (fun x => S.length - x.1.start.val)
    (fun x => x.1.«end» = S.len ∧ x.1.start.val ≤ S.length ∧
      x.2.val = xorUpTo S.val N.val x.1.start.val)
  · rintro ⟨it, sm⟩ ⟨he, hle, hsm⟩
    simp only at he hle hsm ⊢
    unfold high.pbkdf2.Secret.block_loop0_loop0.body
    have hS : it.«end».val = S.length := by rw [he, Slice.len_val]
    step as ⟨o, iter1, ho, hend⟩
    by_cases hlt : it.start.val < it.«end».val
    · simp only [hlt, ↓reduceIte] at ho
      obtain ⟨rfl, hst⟩ := ho
      simp only
      have hNl : N.val.length = S.val.length := hN
      have hSl : S.val.length = S.length := rfl
      have hsml : sm.val.length = S.length := by rw [hsm]; simp [xorUpTo]
      have hk : it.start.val < S.val.length := by rw [hSl, ← hS]; exact hlt
      step as ⟨i1, hi1⟩
      step as ⟨i2, hi2⟩
      step*
      have h2 : i2 = S.val[it.start.val] := by
        rw [hi2]; simp [hsm, xorUpTo]
      have h3 : i3 = S.val[it.start.val] ^^^ N.val[it.start.val]! := by
        apply UScalar.eq_of_val_eq
        rw [i3_post, h2, hi1, getElem!_pos N.val _ (by omega)]
      refine ⟨by rw [hend, he], by omega, ?_, by omega⟩
      rw [s_post, Slice.set_val_eq, hsm, h3, xorUpTo_step _ _ _ hk, hst]
    · simp only [hlt, ↓reduceIte] at ho
      obtain ⟨rfl, hst⟩ := ho
      simp only [WP.spec_ok]
      have : it.start.val = S.val.length := by simp only [Slice.length] at hle hS; omega
      rw [hsm, this]
      exact xorUpTo_end _ _ hN
  · exact ⟨rfl, hj, hs⟩

theorem digest_as_mut_spec (d : high.digest.Digest) :
    high.digest.Digest.as_mut d ⦃ s back =>
      s.length = outLen d.algorithm ∧ bv s.val = digestBytes d ∧
        ∀ s' : Slice U8, s'.length = outLen d.algorithm →
          (back s').algorithm = d.algorithm ∧ digestBytes (back s') = bv s'.val ⦄ := by
  obtain ⟨n, hn, hnv, hn64⟩ := output_len_eq d.algorithm
  unfold high.digest.Digest.as_mut
  simp only [hn, bind_ok]
  step*
  have hvl : (d.value.val).length = 64 := d.value.property
  refine ⟨by rw [s_post1, hnv], ?_, ?_⟩
  · rw [digestBytes, s_post, ← hnv]
    simp [List.slice]
  · intro s' hs'
    simp only [digestBytes, s_post2]
    have := take_setSlice! d.value.val s'.val 0 (by simp only [Slice.length] at hs'; omega)
    simp only [List.take_zero, List.nil_append, Nat.zero_add] at this
    simp only [Slice.length] at hs'
    rw [← hs', this]

/-- The iterations after `U_1`: `u` is the last `U_j` and `t` their sum. -/
theorem block_loop_spec (a : high.hmac.Algorithm) (hr : RunsHmac a) (P : List Byte)
    (k : high.hmac.Key) (hk : KeyOf a P k) (c : Nat) (acc : List Byte × List Byte) :
    ∀ (iter : core.ops.range.Range U32) (u t : high.digest.Digest),
      iter.«end».val = c → 1 ≤ iter.start.val → iter.start.val - 1 ≤ c - 1 →
      outLen u.algorithm = tagLen a → outLen t.algorithm = tagLen a →
      digestBytes u = (pbIter (hmacOf a) P (iter.start.val - 1) acc).1 →
      digestBytes t = (pbIter (hmacOf a) P (iter.start.val - 1) acc).2 →
      high.pbkdf2.Secret.block_loop0 iter k u t ⦃ r =>
        outLen r.algorithm = tagLen a ∧ digestBytes r = (pbIter (hmacOf a) P (c - 1) acc).2 ⦄ := by
  intro iter u t he h1 hle hul htl hu ht
  unfold high.pbkdf2.Secret.block_loop0
  apply loop.spec_decr_nat (fun x => c - x.1.start.val)
    (fun x => x.2.1 = k ∧ x.1.«end».val = c ∧ 1 ≤ x.1.start.val ∧ x.1.start.val - 1 ≤ c - 1 ∧
      outLen x.2.2.1.algorithm = tagLen a ∧ outLen x.2.2.2.algorithm = tagLen a ∧
      digestBytes x.2.2.1 = (pbIter (hmacOf a) P (x.1.start.val - 1) acc).1 ∧
      digestBytes x.2.2.2 = (pbIter (hmacOf a) P (x.1.start.val - 1) acc).2)
  · rintro ⟨it, sf, u, t⟩ ⟨rfl, he, h1, hle, hul, htl, hu, ht⟩
    simp only at he h1 hle hul htl hu ht ⊢
    unfold high.pbkdf2.Secret.block_loop0.body
    step as ⟨o, iter1, ho, hend⟩
    by_cases hlt : it.start.val < it.«end».val
    · simp only [hlt, ↓reduceIte] at ho
      obtain ⟨rfl, hst⟩ := ho
      simp only
      step with digest_as_ref_spec u as ⟨s, hsl, hsb⟩
      apply WP.spec_bind (key_tag_spec a hr P sf hk s (by
        have h64 : hmacBlock a + tagLen a ≤ 192 := by cases a <;> decide
        rw [hsl, hul]; unfold maxInput; simp only [U64.max_eq]; omega))
      rintro u1 ⟨hu1l, hu1b⟩
      step with digest_as_mut_spec t as ⟨sum, back, hsuml, hsumb, hback⟩
      step with digest_as_ref_spec u1 as ⟨s1, hs1l, hs1b⟩
      step as ⟨next, hnext, hnextl⟩
      have hnv : next.val = s1.val := by
        rw [hnext, List.slice, List.drop_zero, Nat.sub_zero, Slice.len_val]
        exact List.take_of_length_le (by simp only [Slice.length] at hsuml hs1l ⊢; omega)
      apply WP.spec_bind (xor_loop_spec sum next (by rw [hnextl, Slice.len_val]) 0#usize sum
        (by show (0 : Nat) ≤ _; exact Nat.zero_le _)
        (by show sum.val = xorUpTo sum.val next.val 0; rw [xorUpTo_zero]))
      intro sum1 hsum1
      have hsum1l : sum1.length = outLen t.algorithm := by
        have := congrArg List.length hsum1
        simp only [bv_length, List.length_zipWith] at this
        simp only [Slice.length, hnv] at this hsuml hs1l ⊢
        omega
      obtain ⟨hba, hbb⟩ := hback sum1 hsum1l
      simp only [WP.spec_ok]
      refine ⟨by trivial, by rw [hend]; exact he, by omega, by omega, hu1l, by rw [hba]; exact htl, ?_, ?_,
        by omega⟩
      · rw [hu1b, hsb, hu, hst, Nat.add_sub_cancel, show it.start.val = it.start.val - 1 + 1 by omega,
          pbIter_succ]
        rfl
      · rw [hbb, hsum1, hsumb, hnv, hs1b, hu1b, hsb, hu, ht, hst, Nat.add_sub_cancel,
          show it.start.val = it.start.val - 1 + 1 by omega, pbIter_succ]
        rfl
    · simp only [hlt, ↓reduceIte] at ho
      obtain ⟨rfl, hst⟩ := ho
      simp only [WP.spec_ok]
      have : it.start.val - 1 = c - 1 := by omega
      rw [← this]
      exact ⟨htl, ht⟩
  · exact ⟨rfl, he, h1, hle, hul, htl, hu, ht⟩

theorem bv_toBEBytes (x : U32) :
    bv (x.bv.toBEBytes.map (@UScalar.mk UScalarTy.U8)) = (BitVec.ofNat 32 x.val).toBEBytes := by
  simp only [bv, List.map_map]
  rw [show ((fun x : U8 => x.bv) ∘ @UScalar.mk UScalarTy.U8) = id from rfl, List.map_id]
  congr 1
  apply BitVec.eq_of_toNat_eq
  rw [BitVec.toNat_ofNat]
  exact (Nat.mod_eq_of_lt x.bv.isLt).symm

/-- `Secret::block` is PBKDF2's block `T_index` after `iterations` iterations. -/
theorem block_spec (a : high.hmac.Algorithm) (hr : RunsHmac a) (P : List Byte)
    (k : high.hmac.Key) (hk : KeyOf a P k) (salt : List U8) (salted : high.hmac.Streaming)
    (hs : StreamOf a P salt salted) (hm : hmacBlock a + salt.length + 4 ≤ maxInput)
    (iterations : core.num.nonzero.NonZero U32 core.num.niche_types.NonZeroU32Inner)
    (index : U32) :
    high.pbkdf2.Secret.block k salted iterations index ⦃ r =>
      outLen r.algorithm = tagLen a ∧
        digestBytes r = pbT (hmacOf a) P (bv salt) iterations.val index.val ⦄ := by
  unfold high.pbkdf2.Secret.block
  apply WP.spec_bind (stream_clone_spec a hr P salt salted hs)
  intro ctx hctx
  step as ⟨arr, harr⟩
  step as ⟨sl, hsl⟩
  apply WP.spec_bind (stream_update_spec a hr P salt ctx hctx sl (by
    have : sl.length = 4 := by simp [Slice.length, hsl]
    rw [this]; exact hm))
  intro ctx1 hctx1
  apply WP.spec_bind (stream_finish_spec a hr P _ ctx1 hctx1 (by
    have : sl.val.length = 4 := by simp [hsl]
    simp only [List.length_append, this]; omega))
  rintro u ⟨hul, hub⟩
  simp only [high.digest.Digest.Insts.CoreCloneClone.clone, core.num.nonzero.NonZero.get, bind_ok]
  have hU1 : digestBytes u = pbU1 (hmacOf a) P (bv salt) index.val := by
    rw [hub, pbU1, bv_append, hsl, Array.val_to_slice, harr, bv_toBEBytes]
  apply WP.spec_mono (block_loop_spec a hr P k hk iterations.val
    (pbU1 (hmacOf a) P (bv salt) index.val, pbU1 (hmacOf a) P (bv salt) index.val) _ u u rfl
    (by simp) (by simp) hul hul (by simp [pbIter, hU1]) (by simp [pbIter, hU1]))
  rintro r ⟨hrl, hrb⟩
  exact ⟨hrl, hrb⟩

end rind.x86_64.kdf
