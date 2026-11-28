import Rind.Aarch64.MlKemKeygen
import Rind.Aarch64.CtEqual
open Aeneas Aeneas.Std Result rind.spec Spec Spec.MLKEM rind.spec.mlkem rind.spec.s2n

/-!
# ML-KEM-768's key encapsulation on aarch64

FIPS 203's `ML-KEM.KeyGen_internal`, `Encaps_internal`, and `Decaps_internal`
for ML-KEM-768, and the encapsulation key check, over K-PKE's proofs,
SHA-3's contexts and sponge, and the constant-time compare: `encaps_rind`
and `decaps_rind` are the Fujisaki-Okamoto transform (`encaps_rind_fips`,
`decaps_rind_fips`), and the `_mitigated` entry points each `Params` method
calls reach them where rind's arithmetic runs. aarch64 never runs
pyca/verified-garbage's key generation or decapsulation, and runs its
encapsulation only on the SHA-3 instructions, so the encapsulation theorems
assume `low::aarch64::mlkem768_vg::Encaps::check` finds none
(`NoVgEncaps`). Each theorem that samples a matrix assumes `SampleNTT`
finishes on its inputs (`Halts`), which no proof shows for every input.
-/

namespace rind.aarch64

namespace MlKemKem

open MlKemCoding MlKemRoutines MlKemPoly MlKemPke MlKemEncrypt MlKemSample MlKemKeygen
open MlKemCbd (toVec_toList shake256_congr)

/-! ## The constant-time copy and compare -/

theorem sel_true (a b : U8) : b ^^^ (255#u8 &&& (a ^^^ b)) = a := by
  apply UScalar.eq_of_val_eq
  have hx : a.val ^^^ b.val < 2 ^ 8 := Nat.xor_lt_two_pow (by scalar_tac) (by scalar_tac)
  simp only [UScalar.val_xor, UScalar.val_and]
  rw [show (255#u8 : U8).val = 2 ^ 8 - 1 from rfl, Nat.and_comm, Nat.and_two_pow_sub_one_eq_mod,
    Nat.mod_eq_of_lt hx, Nat.xor_comm a.val, ← Nat.xor_assoc, Nat.xor_self, Nat.zero_xor]

theorem sel_false (a b : U8) : b ^^^ (0#u8 &&& (a ^^^ b)) = b := by
  apply UScalar.eq_of_val_eq
  simp only [UScalar.val_xor, UScalar.val_and]
  rw [show (0#u8 : U8).val = 0 from rfl, Nat.zero_and, Nat.xor_zero]

/-- The copying loop of `ct_copy`: each byte `mask`'s choice of the output's
and `if_false`'s. -/
theorem ct_copy_loop_spec {N : Usize} (output if_false : Std.Array U8 N) (mask : U8) (cond : Bool)
    (hm : mask = if cond then 255#u8 else 0#u8) (it : core.ops.range.Range Usize) (hs : it.start.val = 0)
    (he : it.end.val = N.val) :
    low.generic.ct_copy.ct_copy_loop it output if_false mask ⦃ r =>
      r = if cond then output else if_false ⦄ := by
  unfold low.generic.ct_copy.ct_copy_loop
  apply WP.spec_mono (range_loop N.val (fun c (s : Std.Array U8 N) => ∀ p < N.val,
    s.val[p]! = if p < c then (if cond then output.val[p]! else if_false.val[p]!) else output.val[p]!)
    _ ?_ it output he (by omega) (fun p hp => by simp [hs]))
  · intro r hr
    have hl : r.val.length = N.val := r.property
    cases cond <;> simp only [Bool.false_eq_true, ↓reduceIte] at hr ⊢
    · apply Aeneas.Std.Array.ext
      exact ext_getElem! (by rw [hl, if_false.property]) fun i hi => by
        rw [hr i (by omega), MlKemPoly.ite_pos (by omega)]
    · apply Aeneas.Std.Array.ext
      exact ext_getElem! (by rw [hl, output.property]) fun i hi => by
        rw [hr i (by omega), MlKemPoly.ite_pos (by omega)]
  · intro it s he hs' hinv
    simp only
    unfold low.generic.ct_copy.ct_copy_loop.body
    step as ⟨o', it1, ho, he1⟩
    split_ifs at ho with hlt
    · obtain ⟨rfl, hst⟩ := ho
      simp only
      step as ⟨x, hx⟩
      step as ⟨y, hy⟩
      simp only [lift, bind_ok]
      step as ⟨a2, ha2⟩
      refine ⟨by rw [he1]; exact he, hst, by omega, fun p hp => ?_⟩
      rw [ha2, Std.Array.set_val_eq]
      by_cases hpi : p = it.start.val
      · subst hpi
        rw [getElem!_set_self _ _ _ (by have : s.val.length = N.val := s.property; omega),
          MlKemPoly.ite_pos (show it.start.val < it1.start.val by omega), hx, hy, ← getElem!_pos, ← getElem!_pos, hinv _ hp,
          MlKemPoly.ite_neg (show ¬it.start.val < it.start.val by omega), hm]
        split
        · exact sel_true _ _
        · exact sel_false _ _
      · rw [getElem!_set_ne _ _ _ _ (Ne.symm hpi), hinv p hp]
        by_cases hpc : p < it.start.val
        · rw [MlKemPoly.ite_pos hpc, MlKemPoly.ite_pos (show p < it1.start.val by omega)]
        · rw [MlKemPoly.ite_neg hpc, MlKemPoly.ite_neg (show ¬p < it1.start.val by omega)]
    · obtain ⟨rfl, hst⟩ := ho
      apply (WP.spec_ok _).2
      have : it.start.val = N.val := by omega
      rw [this] at hinv
      exact hinv

/-- `ct_copy` keeps `output` if `cond`, and takes `if_false` if not. -/
theorem ct_copy_spec {N : Usize} (cond : Bool) (output if_false : Std.Array U8 N) :
    low.generic.ct_copy.ct_copy cond output if_false ⦃ r => r = if cond then output else if_false ⦄ := by
  unfold low.generic.ct_copy.ct_copy core.hint.black_box core.num.I16.wrapping_neg
  cases cond
  · simp [lift]
    step as ⟨i3, hv, hbv⟩
    have h3 : i3 = 0#i16 := by
      apply IScalar.eq_of_val_eq; rw [hv]; decide
    subst h3
    exact ct_copy_loop_spec output if_false _ false (by decide) _ rfl rfl
  · simp [lift]
    step as ⟨i3, hv, hbv⟩
    have h3 : i3 = (-1)#i16 := by
      apply IScalar.eq_of_val_eq; rw [hv]; decide
    subst h3
    exact ct_copy_loop_spec output if_false _ true (by decide) _ rfl rfl

/-! ## `Encaps_internal` -/

open scoped Spec.Notations

theorem bv_append32 (m h : Std.Array U8 32#usize) :
    bv (m.val ++ h.val) = (toVec 32 m.val m.property ‖ toVec 32 h.val h.property).toList := by
  rw [vappend_toList, toVec_toList, toVec_toList]
  simp [bv]

/-- `K-PKE.Encrypt`'s view of an encapsulation key `E`: `t̂`'s polynomials and
the transposed matrix, as `DecodedHolds` takes them. -/
abbrev EkDecoded {X : Type} (D : mid.mlkem.Decoded X Vec Mat EkBytes CtBytes DkBytes Cache Enc) (E : 𝔹 1184) :
    Prop :=
  DecodedHolds D (fun j => (PolyVector.ByteDecode (k := k .ML_KEM_768) 12 (slice E 0 1152))[j]!)
    (fun i j => SampleNTT (slice E 1152 32 ‖ #v[(i : Byte)] ‖ #v[(j : Byte)]))

/-- `encaps_rind` is FIPS 203's `ML-KEM.Encaps_internal` for ML-KEM-768, given
the key's hash `H(E)` and a decoded form whose `t̂` and transposed matrix are
those `E` encodes. -/
theorem encaps_rind_fips (h : RunsSha3) {X : Type}
    (P : mid.mlkem.Params X Vec Mat EkBytes CtBytes DkBytes Cache Enc) (hP : Is768 P)
    (ek : mid.mlkem.EncapKey X Vec Mat EkBytes CtBytes DkBytes Cache Enc) (E : 𝔹 1184)
    (hh : toVec 32 ek.h_ek.val ek.h_ek.property = H E)
    (D : mid.mlkem.Decoded X Vec Mat EkBytes CtBytes DkBytes Cache Enc) (hD : EkDecoded D E)
    (m : mid.mlkem.Message) :
    mid.mlkem.EncapKey.encaps_rind P ek D m ⦃ r =>
      toVec 32 r.1.val r.1.property = (Encaps_internal .ML_KEM_768 E (toVec 32 m.val m.property)).1 ∧
        toVec 1088 r.2.val r.2.property = (Encaps_internal .ML_KEM_768 E (toVec 32 m.val m.property)).2 ⦄ := by
  unfold mid.mlkem.EncapKey.encaps_rind
  step with sha3ctx_new_spec 72#usize 64#usize (by decide) (by decide) as ⟨g, hg⟩
  step as ⟨s, hs⟩
  step with sha3ctx_update_spec h (by decide) g [] hg s as ⟨g1, hg1⟩
  step as ⟨s1, hs1⟩
  step with sha3ctx_update_spec h (by decide) g1 _ hg1 s1 as ⟨g2, hg2⟩
  step with sha3ctx_finish_spec h (by decide) g2 _ hg2 as ⟨kr, hkr⟩
  step as ⟨s2, hs2⟩
  step as ⟨k1, r1, hkl, hrl, hkv, hrv⟩
  have hkrl : kr.val.length = 64 := kr.property
  have hs2v : s2.val = kr.val := by rw [hs2, Std.Array.val_to_slice]
  have hrl' : r1.length = 32 := by rw [hrl]; show s2.val.length - 32 = 32; rw [hs2v, hkrl]
  rw [try_copy_eq 32#usize _ k1 hkl, try_copy_eq 32#usize _ r1 hrl']
  simp only [core.result.Result.unwrap, low.ct.into_public, bind_ok]
  have hM : bv ([] ++ s.val ++ s1.val) = (toVec 32 m.val m.property ‖ H E).toList := by
    rw [List.nil_append, hs, hs1, Std.Array.val_to_slice, Std.Array.val_to_slice, ← hh]
    exact bv_append32 m ek.h_ek
  rw [hM] at hkr
  obtain ⟨hK, hR⟩ := g_eq kr.val hkrl _ hkr
  have hr : toVec 32 (Std.Array.from (n := 32#usize) r1.val hrl').val (Std.Array.property _) =
      (G (toVec 32 m.val m.property ‖ H E)).2 := by
    rw [← hR]
    apply toVec_congr
    rw [Std.Array.from_val, hrv, hs2v]
    simp [sub, List.take_of_length_le, hkrl]
  step with kpke_encrypt_fips h P hP D E hD m _ as ⟨c, hc⟩
  refine ⟨?_, ?_⟩
  · rw [show (Encaps_internal .ML_KEM_768 E (toVec 32 m.val m.property)).1 =
      (G (toVec 32 m.val m.property ‖ H E)).1 from rfl, ← hK]
    apply toVec_congr
    rw [Std.Array.from_val, hkv, hs2v]
    rfl
  · rw [hc, hr]
    rfl

/-! ## `Decaps_internal` -/

/-- FIPS 203's encoding of a decapsulation key from its fields:
`dkPKE ‖ ek ‖ h ‖ z`. -/
def dkBytes (dkp : Enc) (ek : EkBytes) (hh z : Std.Array U8 32#usize) : 𝔹 2400 :=
  toVec 2400 (dkp.val.flatMap (·.val) ++ ek.val ++ hh.val ++ z.val) (by
    simp only [List.length_append, flat_length, dkp.property, ek.property, hh.property, z.property]; rfl)

theorem toVec_inj (n : ℕ) (l l' : List U8) (h : l.length = n) (h' : l'.length = n) :
    toVec n l h = toVec n l' h' ↔ l = l' := by
  constructor
  · intro e
    have e' := congrArg Vector.toList e
    rw [toVec_toList, toVec_toList] at e'
    exact List.map_injective_iff.mpr (fun a b hab => by cases a; cases b; simp_all) e'
  · intro e
    exact toVec_congr n l l' h h' e

/-- Bytes that are SHAKE256's first 32 of `M` are `J(M)`. -/
theorem j_eq {n : ℕ} (x : List U8) (hl : x.length = 32) (M : 𝔹 n) (hx : bv x = shake256 M.toList 32) :
    toVec 32 x hl = J M := by
  apply Vector.toList_inj.mp
  rw [toVec_toList, hx, shake256_eq]
  unfold J
  rw [shake256_congr (toB M.toList) M (by simp [toB])]

/-- `Decaps_internal` for ML-KEM-768 on the encoding of a key's fields. -/
theorem decaps_eq (dkp : Enc) (ek : EkBytes) (hh z : Std.Array U8 32#usize) (c : 𝔹 1088) :
    Decaps_internal .ML_KEM_768 (dkBytes dkp ek hh z) c =
      if c ≠ K_PKE.Encrypt .ML_KEM_768 (toVec 1184 ek.val ek.property) (K_PKE.Decrypt .ML_KEM_768 (dkPke dkp) c)
          (G (K_PKE.Decrypt .ML_KEM_768 (dkPke dkp) c ‖ toVec 32 hh.val hh.property)).2
      then J (toVec 32 z.val z.property ‖ c)
      else (G (K_PKE.Decrypt .ML_KEM_768 (dkPke dkp) c ‖ toVec 32 hh.val hh.property)).1 := by
  have hf : (dkp.val.flatMap (·.val)).length = 1152 := by rw [flat_length, dkp.property]; rfl
  have he : ek.val.length = 1184 := ek.property
  have hl : hh.val.length = 32 := hh.property
  have e0 : slice (dkBytes dkp ek hh z) 0 1152 (by omega) = dkPke dkp := by
    unfold dkBytes dkPke
    rw [slice_toVec]
    apply toVec_congr
    simp [sub, hf]
  have e1 : slice (dkBytes dkp ek hh z) 1152 1184 (by omega) = toVec 1184 ek.val ek.property := by
    unfold dkBytes
    rw [slice_toVec]
    apply toVec_congr
    simp [sub, hf, he]
  have e2 : slice (dkBytes dkp ek hh z) 2336 32 (by omega) = toVec 32 hh.val hh.property := by
    unfold dkBytes
    rw [slice_toVec]
    apply toVec_congr
    simp [sub, List.drop_append, hf, he, hl]
  have e3 : slice (dkBytes dkp ek hh z) 2368 32 (by omega) = toVec 32 z.val z.property := by
    unfold dkBytes
    rw [slice_toVec]
    apply toVec_congr
    have hz : z.val.length = 32 := z.property
    simp [sub, List.drop_append, hf, he, hl, hz]
  unfold Decaps_internal
  dsimp only [k, Nat.reduceMul, Nat.reduceAdd]
  rw [e0, e1, e2, e3]

/-- `decaps_rind` is FIPS 203's `ML-KEM.Decaps_internal` for ML-KEM-768 on the
encoding of the key's fields, given the decoded form of its encapsulation key. -/
theorem decaps_rind_fips (h : RunsSha3) {X : Type}
    (P : mid.mlkem.Params X Vec Mat EkBytes CtBytes DkBytes Cache Enc) (hP : Is768 P)
    (key : mid.mlkem.DecapKey X Vec Mat EkBytes CtBytes DkBytes Cache Enc)
    (D : mid.mlkem.Decoded X Vec Mat EkBytes CtBytes DkBytes Cache Enc) (hD : key.ek_pke.decoded = some D)
    (hDH : EkDecoded D (toVec 1184 key.ek_pke.bytes.val key.ek_pke.bytes.property)) (c : CtBytes) :
    mid.mlkem.DecapKey.decaps_rind P key c ⦃ k =>
      toVec 32 k.val k.property =
        Decaps_internal .ML_KEM_768 (dkBytes key.dk_pke key.ek_pke.bytes key.ek_pke.h_ek key.z)
          (toVec 1088 c.val c.property) ⦄ := by
  rw [decaps_eq]
  unfold mid.mlkem.DecapKey.decaps_rind
  simp only [hP.ct.as_ref, hD]
  -- `m' ← K-PKE.Decrypt(dkPKE, c)`.
  step with kpke_decrypt_fips P hP key c as ⟨m', hm'⟩
  -- `(K', r') ← G(m' ‖ h)`.
  step with sha3ctx_new_spec 72#usize 64#usize (by decide) (by decide) as ⟨g, hg⟩
  step as ⟨s, hs⟩
  step with sha3ctx_update_spec h (by decide) g [] hg s as ⟨g1, hg1⟩
  step as ⟨s1, hs1⟩
  step with sha3ctx_update_spec h (by decide) g1 _ hg1 s1 as ⟨g2, hg2⟩
  step with sha3ctx_finish_spec h (by decide) g2 _ hg2 as ⟨kr, hkr⟩
  step as ⟨s2, hs2⟩
  step as ⟨k1, r1, hkl, hrl, hkv, hrv⟩
  have hkrl : kr.val.length = 64 := kr.property
  have hs2v : s2.val = kr.val := by rw [hs2, Std.Array.val_to_slice]
  have hrl' : r1.length = 32 := by rw [hrl]; show s2.val.length - 32 = 32; rw [hs2v, hkrl]
  rw [try_copy_eq 32#usize _ k1 hkl, try_copy_eq 32#usize _ r1 hrl']
  simp only [core.result.Result.unwrap, bind_ok]
  have hM : bv ([] ++ s.val ++ s1.val) =
      (toVec 32 m'.val m'.property ‖ toVec 32 key.ek_pke.h_ek.val key.ek_pke.h_ek.property).toList := by
    rw [List.nil_append, hs, hs1, Std.Array.val_to_slice, Std.Array.val_to_slice]
    exact bv_append32 m' key.ek_pke.h_ek
  rw [hM] at hkr
  obtain ⟨hK, hR⟩ := g_eq kr.val hkrl _ hkr
  have hk : toVec 32 (Std.Array.from (n := 32#usize) k1.val hkl).val (Std.Array.property _) =
      (G (toVec 32 m'.val m'.property ‖ toVec 32 key.ek_pke.h_ek.val key.ek_pke.h_ek.property)).1 := by
    rw [← hK]
    apply toVec_congr
    rw [Std.Array.from_val, hkv, hs2v]
    rfl
  have hr : toVec 32 (Std.Array.from (n := 32#usize) r1.val hrl').val (Std.Array.property _) =
      (G (toVec 32 m'.val m'.property ‖ toVec 32 key.ek_pke.h_ek.val key.ek_pke.h_ek.property)).2 := by
    rw [← hR]
    apply toVec_congr
    rw [Std.Array.from_val, hrv, hs2v]
    simp [sub, List.take_of_length_le, hkrl]
  -- `K̄ ← J(z ‖ c)`.
  step with sponge_new_spec 136#usize (by decide) 31#u8 as ⟨j, hj⟩
  step as ⟨s3, hs3⟩
  step with sponge_absorb_spec h (by decide) j [] hj s3 as ⟨j1, hj1⟩
  step as ⟨s4, hs4⟩
  step with sponge_absorb_spec h (by decide) j1 _ hj1 s4 as ⟨j2, hj2⟩
  step with sponge_finish_spec (by decide) j2 _ hj2 as ⟨ss, hss⟩
  step as ⟨s5, back, hs5, hback⟩
  step with squeezing_squeeze_spec h (by decide) ss _ _ 0 hss s5 as ⟨ss', s6, hs6l, hs6, _⟩
  -- `c' ← K-PKE.Encrypt(ek, m', r')`.
  step with kpke_encrypt_fips h P hP D _ hDH m' _ as ⟨c', hc'⟩
  step as ⟨s7, hs7⟩
  step with ct_equal_spec h.2.1 s4 s7 as ⟨b, hb⟩
  step with ct_copy_spec b _ _ as ⟨a4, ha4⟩
  have hs5l : s5.length = 32 := by show s5.val.length = _; rw [hs5]; rfl
  have hbs : (back s6).val = s6.val := by
    rw [hback, Std.Array.from_slice_val _ _ (by show s6.length = _; rw [hs6l, hs5l]; rfl)]
  have hkbar : toVec 32 (back s6).val (Std.Array.property _) =
      J (toVec 32 key.z.val key.z.property ‖ toVec 1088 c.val c.property) := by
    rw [toVec_congr 32 _ s6.val _ (by show s6.length = 32; rw [hs6l, hs5l]) hbs]
    apply j_eq
    rw [hs6, hs5l, vappend_toList, toVec_toList, toVec_toList, Nat.mul_zero, List.drop_zero, Nat.zero_add,
      List.nil_append, hs3, hs4, Std.Array.val_to_slice]
    rfl
  rw [← hm', ← hr, ← hc', ← hk]
  have hcmp : (toVec 1088 c.val c.property ≠ toVec 1088 c'.val c'.property) ↔ ¬ c.val = c'.val := by
    rw [ne_eq, toVec_inj]
  by_cases hcc : c.val = c'.val
  · have hbt : b = true := by rw [hb, hs4, hs7]; simp [hcc]
    rw [ha4, hbt, MlKemPoly.ite_pos rfl, MlKemPoly.ite_neg (by rw [hcmp]; exact not_not.mpr hcc)]
  · have hbf : b = false := by rw [hb, hs4, hs7]; simp [hcc]
    rw [ha4, hbf, MlKemPoly.ite_neg (by simp), MlKemPoly.ite_pos (by rw [hcmp]; exact hcc), hkbar]

end MlKemKem

end rind.aarch64
