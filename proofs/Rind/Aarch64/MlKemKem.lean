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

end MlKemKem

end rind.aarch64
