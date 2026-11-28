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

theorem bv_inj (l l' : List U8) : bv l = bv l' ↔ l = l' := by
  constructor
  · exact fun e => List.map_injective_iff.mpr (fun a b hab => by cases a; cases b; simp_all) e
  · intro e; rw [e]

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

/-! ## The entry points -/

theorem vg_key_pair_none {X : Type} (P : mid.mlkem.Params X Vec Mat EkBytes CtBytes DkBytes Cache Enc)
    (hP : Is768 P) : mid.mlkem.vg_key_pair P = ok none := by
  unfold mid.mlkem.vg_key_pair
  simp only [hP.K, bind_ok]
  rfl

/-- The seed's `d`, its first 32 bytes. -/
abbrev seedD (seed : Std.Array U8 64#usize) : 𝔹 32 :=
  toVec 32 (sub seed.val 0 32) (sub_length _ _ _ (by have : seed.val.length = 64 := seed.property; omega))

/-- The seed's `z`, its last 32 bytes. -/
abbrev seedZ (seed : Std.Array U8 64#usize) : 𝔹 32 :=
  toVec 32 (sub seed.val 32 32) (sub_length _ _ _ (by have : seed.val.length = 64 := seed.property; omega))

theorem keygen_internal_snd (d z : 𝔹 32) :
    (KeyGen_internal .ML_KEM_768 d z).2.toList =
      (K_PKE.KeyGen .ML_KEM_768 d).2.toList ++ (K_PKE.KeyGen .ML_KEM_768 d).1.toList ++
        (H (K_PKE.KeyGen .ML_KEM_768 d).1).toList ++ z.toList := by
  unfold KeyGen_internal
  simp only [Vector.toList_cast, vappend_toList]

/-- `keygen_mitigated`, which `Params::keygen` runs, is FIPS 203's
`ML-KEM.KeyGen_internal` for ML-KEM-768 on aarch64, which runs rind's
arithmetic, from the seed `d ‖ z`: the key's encapsulation key holds `ek`
(`EkHolds`) and its fields encode `dk`, given that `SampleNTT` finishes on each
of the matrix's inputs. -/
theorem keygen_mitigated_fips (h : RunsSha3) {X : Type}
    (P : mid.mlkem.Params X Vec Mat EkBytes CtBytes DkBytes Cache Enc) (hP : Is768 P) (seed : Std.Array U8 64#usize)
    (hH : ∀ i : ℕ, i < 3 → ∀ j : ℕ, j < 3 → Halts ((kgG (seedD seed)).1 ‖ #v[(j : Byte)] ‖ #v[(i : Byte)]).toList) :
    mid.mlkem.DecapKey.keygen_mitigated P seed ⦃ key =>
      toVec 1184 key.ek_pke.bytes.val key.ek_pke.bytes.property =
          (KeyGen_internal .ML_KEM_768 (seedD seed) (seedZ seed)).1 ∧
        dkBytes key.dk_pke key.ek_pke.bytes key.ek_pke.h_ek key.z =
          (KeyGen_internal .ML_KEM_768 (seedD seed) (seedZ seed)).2 ∧
        EkHolds key.ek_pke (toVec 1184 key.ek_pke.bytes.val key.ek_pke.bytes.property) ⦄ := by
  have hsl : seed.val.length = 64 := seed.property
  unfold mid.mlkem.DecapKey.keygen_mitigated
  simp only [vg_key_pair_none P hP, bind_ok]
  step as ⟨s, hs⟩
  step as ⟨d1, z1, hdl, hzl, hdv, hzv⟩
  have hzl' : z1.length = 32 := by rw [hzl]; show s.val.length - 32 = 32; rw [hs, Std.Array.val_to_slice, hsl]
  rw [try_copy_eq 32#usize _ d1 hdl, try_copy_eq 32#usize _ z1 hzl']
  simp only [core.result.Result.unwrap, low.ct.into_secret, bind_ok]
  have hd : toVec 32 (Std.Array.from (n := 32#usize) d1.val hdl).val (Std.Array.property _) = seedD seed := by
    apply toVec_congr
    rw [Std.Array.from_val, hdv, hs, Std.Array.val_to_slice]
    simp [sub]
  have hz : toVec 32 (Std.Array.from (n := 32#usize) z1.val hzl').val (Std.Array.property _) = seedZ seed := by
    apply toVec_congr
    rw [Std.Array.from_val, hzv, hs, Std.Array.val_to_slice]
    simp [sub, List.take_of_length_le, hsl]
  step with kpke_keygen_fips h P hP _ (by rw [hd]; exact hH) as ⟨ek, dk, hek, hdk, hk⟩
  rw [hd] at hek hdk
  refine ⟨hek, ?_, hk⟩
  apply Vector.toList_inj.mp
  unfold dkBytes
  rw [toVec_toList, keygen_internal_snd, ← hdk, ← hek, ← hk.h_ek, ← hz]
  unfold dkPke
  simp only [bv, List.map_append, toVec_toList]

/-- `decaps_mitigated`, which `Params::decaps` runs, is FIPS 203's
`ML-KEM.Decaps_internal` for ML-KEM-768 on aarch64, which runs rind's
arithmetic, for a key whose encapsulation key holds its decoded form, as every
key rind makes on aarch64 does. -/
theorem decaps_mitigated_fips (h : RunsSha3) {X : Type}
    (P : mid.mlkem.Params X Vec Mat EkBytes CtBytes DkBytes Cache Enc) (hP : Is768 P)
    (key : mid.mlkem.DecapKey X Vec Mat EkBytes CtBytes DkBytes Cache Enc)
    (D : mid.mlkem.Decoded X Vec Mat EkBytes CtBytes DkBytes Cache Enc) (hD : key.ek_pke.decoded = some D)
    (hDH : EkDecoded D (toVec 1184 key.ek_pke.bytes.val key.ek_pke.bytes.property)) (c : CtBytes) :
    mid.mlkem.DecapKey.decaps_mitigated P key c ⦃ k =>
      toVec 32 k.val k.property =
        Decaps_internal .ML_KEM_768 (dkBytes key.dk_pke key.ek_pke.bytes key.ek_pke.h_ek key.z)
          (toVec 1088 c.val c.property) ⦄ := by
  unfold mid.mlkem.DecapKey.decaps_mitigated
  simp only [hD, core.option.Option.is_some, Option.isSome_some, ↓reduceIte]
  exact decaps_rind_fips h P hP key D hD hDH c

theorem decoded_clone {X : Type} (P : mid.mlkem.Params X Vec Mat EkBytes CtBytes DkBytes Cache Enc) (hP : Is768 P)
    (D : mid.mlkem.Decoded X Vec Mat EkBytes CtBytes DkBytes Cache Enc) :
    mid.mlkem.Decoded.Insts.CoreCloneClone.clone P D = ok D := by
  obtain ⟨⟨t1, ⟨⟩⟩, ⟨t2, ⟨⟩⟩⟩ := D
  unfold mid.mlkem.Decoded.Insts.CoreCloneClone.clone mid.mlkem.Coeffs.Insts.CoreCloneClone.clone
  simp only [hP.vec.clone, hP.mat.clone, bind_ok]
  erw [bind_ok, bind_ok]

/-- pyca/verified-garbage's encapsulation does not run here: the CPU lacks the
SHA-3 instructions it needs, so its check finds no token. -/
def NoVgEncaps : Prop := low.aarch64.mlkem768_vg.Encaps.check = ok none

theorem vg_encaps_none (hvg : NoVgEncaps) {X : Type}
    (P : mid.mlkem.Params X Vec Mat EkBytes CtBytes DkBytes Cache Enc) (hP : Is768 P) :
    mid.mlkem.vg_encaps P = ok none := by
  unfold mid.mlkem.vg_encaps
  simp only [hP.K, bind_ok]
  exact hvg

/-- `encaps_mitigated`, which `Params::encaps` runs, is FIPS 203's
`ML-KEM.Encaps_internal` for ML-KEM-768 on aarch64 without the SHA-3
instructions, where rind's arithmetic runs, for an encapsulation key whose
bytes are `E`: through its decoded form and hash, if it holds them, and
otherwise through `Decoded::new`, given that `SampleNTT` finishes on each of
the matrix's inputs. -/
theorem encaps_mitigated_fips (h : RunsSha3) (hvg : NoVgEncaps) {X : Type}
    (P : mid.mlkem.Params X Vec Mat EkBytes CtBytes DkBytes Cache Enc) (hP : Is768 P)
    (ek : mid.mlkem.EncapKey X Vec Mat EkBytes CtBytes DkBytes Cache Enc) (E : 𝔹 1184)
    (hE : toVec 1184 ek.bytes.val ek.bytes.property = E)
    (hdec : ∀ D, ek.decoded = some D → EkDecoded D E ∧ toVec 32 ek.h_ek.val ek.h_ek.property = H E)
    (hH : ek.decoded = none → ∀ i : ℕ, i < 3 → ∀ j : ℕ, j < 3 →
      Halts (slice E 1152 32 ‖ #v[(i : Byte)] ‖ #v[(j : Byte)]).toList)
    (m : mid.mlkem.Message) :
    mid.mlkem.EncapKey.encaps_mitigated P ek m ⦃ r =>
      toVec 32 r.1.val r.1.property = (Encaps_internal .ML_KEM_768 E (toVec 32 m.val m.property)).1 ∧
        toVec 1088 r.2.val r.2.property = (Encaps_internal .ML_KEM_768 E (toVec 32 m.val m.property)).2 ⦄ := by
  unfold mid.mlkem.EncapKey.encaps_mitigated
  simp only [low.ct.secret_slice, lift, bind_ok]
  cases hd : ek.decoded with
  | some D =>
    obtain ⟨hD, hh⟩ := hdec D hd
    exact encaps_rind_fips h P hP ek E hh D hD m
  | none =>
    simp only [vg_encaps_none hvg P hP, hP.ek.clone, bind_ok]
    subst hE
    step with decoded_new_spec h P hP ek.bytes (hH hd) as ⟨D, hD⟩
    simp only [decoded_clone P hP, bind_ok]
    step with encap_key_new_spec h P hP ek.bytes _ as ⟨ek', hb', hh', hs', hd'⟩
    exact encaps_rind_fips h P hP ek' _ (h_eq _ _ _ (by rw [toVec_toList]; exact hh')) _ hD m

/-! ## The encapsulation key check -/

theorem slice_ne_spec (x y : Slice U8) :
    core.cmp.impls.PartialEqShared.ne (Slice.Insts.CoreCmpPartialEqSlice core.cmp.PartialEqU8) x y ⦃ b =>
      b ↔ x.val ≠ y.val ⦄ := by
  unfold core.cmp.impls.PartialEqShared.ne
  apply WP.spec_mono (core.cmp.PartialEq.ne.trait_default.spec (Slice.Insts.CoreCmpPartialEqSlice core.cmp.PartialEqU8) x y
    (core.slice.cmp.PartialEqSlice.eq_homo_spec core.cmp.PartialEqU8 x y (fun a b => by simp [liftFun2])))
  intro b hb
  rw [hb, ne_eq, ne_eq, Slice.eq_iff]

/-- `Encaps.KeyCheck`'s body, for every parameter set: unfolding it at
ML-KEM-768's lengths makes the kernel recurse too deep. -/
theorem keyCheck_def (p : ParameterSet) (E : 𝔹 (384 * k p + 32)) :
    Encaps.KeyCheck p E = decide (PolyVector.ByteEncode 12 (PolyVector.ByteDecode (k := k p) 12
      (slice E 0 (384 * k p) (by omega)) (by omega)) (by omega) = (slice E 0 (384 * k p) (by omega)).cast (by
        cases p <;> rfl)) := rfl

/-- FIPS 203's encapsulation key check for ML-KEM-768: `ByteEncode_12` of the
decoded `t̂` is the key's first 1152 bytes. -/
theorem keycheck_iff (E : 𝔹 1184) :
    Encaps.KeyCheck .ML_KEM_768 E = true ↔
      enc3 (fun j => (PolyVector.ByteDecode (k := k .ML_KEM_768) 12 (slice E 0 1152))[j]!) =
        (slice E 0 1152).toList := by
  rw [keyCheck_def, decide_eq_true_iff, ← Vector.toList_inj, Vector.toList_cast, encode12_3]
  unfold enc3
  simp (disch := decide) only [vget!]

/-- `parse_mitigated`, which `Params::parse` runs, is FIPS 203's encapsulation
key check for ML-KEM-768 on aarch64 without the SHA-3 instructions, where
rind's arithmetic runs: it accepts the key exactly when `Encaps.KeyCheck` does,
and the key it returns holds its bytes, their hash, and its decoded form
(`EkHolds`), given that `SampleNTT` finishes on each of the matrix's inputs,
which it samples before the check. -/
theorem parse_mitigated_fips (h : RunsSha3) (hvg : NoVgEncaps) {X : Type}
    (P : mid.mlkem.Params X Vec Mat EkBytes CtBytes DkBytes Cache Enc) (hP : Is768 P) (input : EkBytes)
    (hH : ∀ i : ℕ, i < 3 → ∀ j : ℕ, j < 3 →
      Halts (slice (toVec 1184 input.val input.property) 1152 32 ‖ #v[(i : Byte)] ‖ #v[(j : Byte)]).toList) :
    mid.mlkem.EncapKey.parse_mitigated P input ⦃ r => match r with
      | .Ok ek => Encaps.KeyCheck .ML_KEM_768 (toVec 1184 input.val input.property) = true ∧
          EkHolds ek (toVec 1184 input.val input.property)
      | .Err _ => Encaps.KeyCheck .ML_KEM_768 (toVec 1184 input.val input.property) = false ⦄ := by
  have hil : input.val.length = 1184 := input.property
  unfold mid.mlkem.EncapKey.parse_mitigated
  simp only [vg_encaps_none hvg P hP, hP.K, hP.ek.as_ref, hP.enc.as_ref, hP.ek.clone, bind_ok]
  step with decoded_new_spec h P hP input hH as ⟨D, hD⟩
  obtain ⟨⟨th, ⟨⟩⟩, ta⟩ := D
  step as ⟨s, hs⟩
  step as ⟨i1, hi1⟩
  step as ⟨t_hat, ht1, ht2⟩
  refine WP.spec_bind (to_bytes_spec P.VectorInst hP.vec hP.enc th _ hD.t_hat) ?_
  intro enc henc
  step as ⟨s1, hs1⟩
  step with as_flattened_spec s1 (by rw [array_length s1 enc hs1]; scalar_tac) as ⟨s2, hs2⟩
  step with slice_ne_spec t_hat s2 as ⟨b, hb⟩
  have hts : bv t_hat.val = (slice (toVec 1184 input.val input.property) 0 1152).toList := by
    rw [slice_toVec, toVec_toList, ht1, hi1, hs]
    simp [List.slice, sub]
  have hencb : bv s2.val = enc3 (fun j =>
      (PolyVector.ByteDecode (k := k .ML_KEM_768) 12 (slice (toVec 1184 input.val input.property) 0 1152))[j]!) := by
    rw [hs2, hs1]
    exact bv_flat3 enc.val enc.property _ (fun j hj => henc j hj)
  have hkc : b = true ↔ Encaps.KeyCheck .ML_KEM_768 (toVec 1184 input.val input.property) = false := by
    rw [hb, ← Bool.not_eq_true, keycheck_iff, ← hts, ← hencb, ne_eq, bv_inj, eq_comm]
  split
  · rename_i hbt
    have hk := hkc.mp hbt
    unfold error.Error.Insts.CoreConvertFromKeyFormatError.from
    simp only [bind_ok, WP.spec_ok]
    exact hk
  · rename_i hbf
    have hk : Encaps.KeyCheck .ML_KEM_768 (toVec 1184 input.val input.property) = true := by
      cases hc : Encaps.KeyCheck .ML_KEM_768 (toVec 1184 input.val input.property)
      · exact absurd (hkc.mpr hc) hbf
      · rfl
    step with encap_key_new_spec h P hP input _ as ⟨ek, hb', hh', hs', hd'⟩
    have hh2 : bv ek.h_ek.val = sha3_256 (toVec 1184 ek.bytes.val ek.bytes.property).toList := by
      rw [toVec_toList, hb']; exact hh'
    refine ⟨hk, ⟨by rw [hb'], ?_, hs', _, hd', hD⟩⟩
    rw [h_eq _ _ _ hh2]
    congr 1
    rw [hb']

end MlKemKem

end rind.aarch64
