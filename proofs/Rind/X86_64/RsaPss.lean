import Rind.X86_64.RsaVerify
import Rind.X86_64.CtEqual
open Aeneas Aeneas.Std Result rind.spec rind.spec.rsa

/-!
# RSA-PSS verification on x86_64

`mgf1_xor` is RFC 8017's MGF1, and `verify_pss_sig` its EMSA-PSS-VERIFY, over
any hash meeting `HashSpec`.
-/

namespace rind.x86_64

theorem getElem!_set_of_lt {α : Type} [Inhabited α] (l : List α) (i p : Nat) (a : α) (hp : p < l.length) :
    (l.set i a)[p]! = if p = i then a else l[p]! := by
  simp only [List.getElem!_eq_getElem?_getD, List.getElem?_set]
  by_cases h : i = p
  · subst h; simp [hp]
  · simp [h, Ne.symm h]

/-- `mgf1_xor`'s inner loop XORs `term` into `out` from `done`. -/
theorem mgf1_xor_inner_spec (o0 term : Slice U8) (done : Usize) (iter : core.ops.range.Range Usize)
    (hend : done.val + iter.end.val ≤ o0.length) (hterm : iter.end.val ≤ term.length)
    (hstart : iter.start.val ≤ iter.end.val) (o : Slice U8)
    (hinv : o.length = o0.length ∧ ∀ p < o0.length, o.val[p]! =
      if done.val ≤ p ∧ p < done.val + iter.start.val then o0.val[p]! ^^^ term.val[p - done.val]! else o0.val[p]!) :
    high.pkcs1.mgf1_xor_loop0_loop0 iter o done term ⦃ o' => o'.length = o0.length ∧
      ∀ p < o0.length, o'.val[p]! =
        if done.val ≤ p ∧ p < done.val + iter.end.val then o0.val[p]! ^^^ term.val[p - done.val]! else o0.val[p]! ⦄ := by
  unfold high.pkcs1.mgf1_xor_loop0_loop0
  apply loop.spec_decr_nat (fun x => x.1.end.val - x.1.start.val)
    (fun x : core.ops.range.Range Usize × Slice U8 => x.1.end = iter.end ∧ x.1.start.val ≤ x.1.end.val ∧
      x.2.length = o0.length ∧ ∀ p < o0.length, x.2.val[p]! =
        if done.val ≤ p ∧ p < done.val + x.1.start.val then o0.val[p]! ^^^ term.val[p - done.val]! else o0.val[p]!)
  · rintro ⟨it, x⟩ ⟨he, hs, hxl, hx⟩
    simp only at he hs hxl hx
    have h2 : it.end.val = iter.end.val := by rw [he]
    unfold high.pkcs1.mgf1_xor_loop0_loop0.body
    step as ⟨op, iter1, hop, hend1⟩
    cases op with
    | none =>
      have : it.start.val = iter.end.val := by
        split at hop
        · simp at hop
        · omega
      simp only [WP.spec_ok]
      rw [this] at hx
      exact ⟨hxl, hx⟩
    | some i =>
      have hlt : it.start.val < it.end.val := by
        by_contra hc; simp [hc] at hop
      simp only [hlt, ↓reduceIte, Option.some.injEq] at hop
      obtain ⟨rfl, hst⟩ := hop
      have h3 : iter1.end.val = it.end.val := by rw [hend1]
      have hxL : x.length = x.val.length := rfl
      have htL : term.length = term.val.length := rfl
      have h0L : o0.length = o0.val.length := rfl
      step as ⟨t, ht⟩
      step as ⟨q, hq⟩
      step as ⟨y, hy⟩
      step as ⟨z, hz⟩
      step as ⟨x1, hx1⟩
      refine ⟨by rw [hend1, he], by omega, by rw [hx1]; simpa using hxl, ?_, by omega⟩
      intro p hp
      rw [hx1, Slice.set_val_eq, getElem!_set_of_lt _ _ _ _ (by omega), hst]
      by_cases hpq : p = q.val
      · have hz' : z = y ^^^ t := by rw [UScalar.eq_equiv]; exact hz
        rw [ite_eq_left hpq, ite_eq_left (by omega), hz', hy, ht, ← getElem!_pos, ← getElem!_pos, hx _ (by omega),
          ite_eq_right (by omega), show p - done.val = it.start.val by omega, hpq]
      · rw [ite_eq_right hpq, hx p hp]
        by_cases hin : done.val ≤ p ∧ p < done.val + it.start.val
        · rw [ite_eq_left hin, ite_eq_left (by omega)]
        · rw [ite_eq_right hin, ite_eq_right (by omega)]
  · exact ⟨rfl, hstart, hinv⟩

/-- MGF1's hashes of `seed` and each counter below `c`, concatenated. -/
def mgfStream (H : List Byte → List Byte) (seed : List Byte) (c : Nat) : List Byte :=
  (List.range c).flatMap fun i => H (seed ++ (BitVec.ofNat 32 i).toBEBytes)

theorem mgfStream_succ (H : List Byte → List Byte) (seed : List Byte) (c : Nat) :
    mgfStream H seed (c + 1) = mgfStream H seed c ++ H (seed ++ (BitVec.ofNat 32 c).toBEBytes) := by
  simp [mgfStream, List.range_succ, List.flatMap_append]

theorem mgfStream_length (H : List Byte → List Byte) (L : Nat) (hH : ∀ m, (H m).length = L)
    (seed : List Byte) (c : Nat) : (mgfStream H seed c).length = c * L := by
  induction c with
  | zero => simp [mgfStream]
  | succ c ih => rw [mgfStream_succ, List.length_append, ih, hH]; ring

theorem getElem!_append' {α : Type} [Inhabited α] (a b : List α) (p : Nat) :
    (a ++ b)[p]! = if p < a.length then a[p]! else b[p - a.length]! := by
  simp only [List.getElem!_eq_getElem?_getD, List.getElem?_append]
  split <;> rfl

theorem mgfStream_stable (H : List Byte → List Byte) (L : Nat) (hH : ∀ m, (H m).length = L)
    (seed : List Byte) (a n p : Nat) (hp : p < a * L) :
    (mgfStream H seed (a + n))[p]! = (mgfStream H seed a)[p]! := by
  induction n with
  | zero => rfl
  | succ n ih =>
    rw [← Nat.add_assoc, mgfStream_succ, getElem!_append', mgfStream_length H L hH,
      ite_eq_left (lt_of_lt_of_le hp (Nat.mul_le_mul_right _ (by omega))), ih]

theorem bv_getElem! (l : List U8) (p : Nat) (hp : p < l.length) : (bv l)[p]! = (l[p]!).bv := by
  simp [bv, getElem!_pos l p hp, getElem!_pos (l.map (·.bv)) p (by simpa using hp)]

section
variable {Self C S : Type} {inst : high.hash.Hash Self C S} {H : List Byte → List Byte}
  {B L max : Nat} {Abs : List U8 → S → Prop} {CAbs : List U8 → C → Prop}

/-- What `mgf1_xor`'s loop keeps after `c` hashes: `done` is the bytes they
cover, and those are XORed with MGF1's output. -/
def Mgf1Inv (H : List Byte → List Byte) (L : Nat) (seed : List Byte) (out o : Slice U8) (c : U32)
    (done : Usize) : Prop :=
  done.val = min (c.val * L) out.length ∧ o.length = out.length ∧
    ∀ p < out.length, (o.val[p]!).bv =
      if p < c.val * L then (out.val[p]!).bv ^^^ (mgfStream H seed c.val)[p]! else (out.val[p]!).bv

theorem mgf1_xor_loop_spec (hs : HashSpec inst H B L max Abs CAbs) (hnew : inst.new ⦃ c => CAbs [] c ⦄)
    (hL : 0 < L) (seed : Slice U8) (hseed : seed.length + 4 ≤ max) (h_len : Usize) (hh : h_len.val = L)
    (out : Slice U8) (hout : out.length ≤ 1024) (o : Slice U8) (c : U32) (done : Usize)
    (hinv : Mgf1Inv H L (bv seed.val) out o c done) :
    high.pkcs1.mgf1_xor_loop0 inst seed h_len o c done ⦃ o' =>
      ∃ c' : Nat, out.length ≤ c' * L ∧ o'.length = out.length ∧
        ∀ p < out.length, (o'.val[p]!).bv = (out.val[p]!).bv ^^^ (mgfStream H (bv seed.val) c')[p]! ⦄ := by
  have hHL := hs.out.2.2.2.2
  unfold high.pkcs1.mgf1_xor_loop0
  apply loop.spec_decr_nat (fun x => out.length - x.2.2.val)
    (fun x : Slice U8 × U32 × Usize => Mgf1Inv H L (bv seed.val) out x.1 x.2.1 x.2.2)
  · rintro ⟨x, cx, dx⟩ ⟨hd, hxl, hx⟩
    simp only at hd hxl hx
    dsimp only
    unfold high.pkcs1.mgf1_xor_loop0.body
    have hxL : x.len.val = out.length := hxl
    have hsL : seed.length = seed.val.length := rfl
    dsimp only
    split
    · rename_i hlt
      have hlt' : dx.val < out.length := by scalar_tac
      have hdc : dx.val = cx.val * L := by omega
      step with hnew as ⟨ctx, hctx⟩
      step with hs.update [] ctx seed hctx (by simp; omega) as ⟨ctx1, hctx1⟩
      step as ⟨a, ha⟩
      step as ⟨sa, hsa⟩
      have hsal : sa.length = 4 := by simp [Slice.length, hsa, ha]
      step with hs.update _ ctx1 sa hctx1 (by simp [hsal]; omega) as ⟨ctx2, hctx2⟩
      step with hs.finish _ ctx2 hctx2 (by simp [hsal]; omega) as ⟨d, hdl, hdv⟩
      step with digest_as_ref_spec d as ⟨term, htl, htv⟩
      rw [hdl] at htl
      step as ⟨i2, hi2⟩
      step as ⟨len, hlen⟩
      have hlen' : len.val = min L (out.length - dx.val) := by
        rw [hlen, core.cmp.impls.OrdUsize.min_val, hh, hi2]
        have : x.length = x.val.length := rfl
        omega
      have hxv : x.val.length = out.length := hxl
      have htv' : term.val.length = L := htl
      have hlenL : len.val ≤ L := by rw [hlen']; exact min_le_left _ _
      have hlenR : len.val ≤ out.length - dx.val := by rw [hlen']; exact min_le_right _ _
      step with mgf1_xor_inner_spec x term dx { start := 0#usize, «end» := len } (by simp; omega)
        (by simp; omega) (by simp) x ⟨rfl, fun p hp => by simp⟩ as ⟨x1, hx1l, hx1⟩
      step as ⟨d2, hd2⟩
      step as ⟨c2, hc2⟩
      have hoL : out.length = out.val.length := rfl
      refine ⟨⟨by rw [hd2, hc2, hlen']; simp only [Nat.add_mul, one_mul]; omega, by omega, ?_⟩,
        by rw [hd2]; omega⟩
      intro p hp
      have hterm : bv term.val = H (bv seed.val ++ (BitVec.ofNat 32 cx.val).toBEBytes) := by
        have hbe : bv sa.val = (BitVec.ofNat 32 cx.val).toBEBytes := by
          rw [hsa]; simp [bv, ha, Array.val_to_slice]
        rw [htv, hdv, bv, List.map_append, ← bv, ← bv, hbe, List.nil_append]
      rw [hx1 p (by omega), hc2]
      simp only [Nat.add_mul, one_mul]
      by_cases hpd : p < cx.val * L
      · rw [ite_eq_right (by omega), hx p hp, ite_eq_left hpd, ite_eq_left (by omega), mgfStream_succ, getElem!_append',
          mgfStream_length H L hHL, ite_eq_left hpd]
      · by_cases hpn : p < cx.val * L + L
        · have hdl2 : dx.val + len.val = min (cx.val * L + L) out.length := by rw [hlen', hdc]; omega
          rw [ite_eq_left (by omega)]
          have hxp := hx p (by omega)
          rw [ite_eq_right hpd] at hxp
          simp only [UScalar.bv_xor, hxp]
          rw [ite_eq_left hpn, mgfStream_succ,
            getElem!_append', mgfStream_length H L hHL, ite_eq_right hpd, ← hterm, bv_getElem! _ _ (by
              have : term.length = term.val.length := rfl; omega), hdc]
        · rw [ite_eq_right (by omega), hx p hp, ite_eq_right hpd, ite_eq_right hpn]
    · rename_i hge
      simp only [WP.spec_ok]
      have hge' : out.length ≤ dx.val := by scalar_tac
      refine ⟨cx.val, by omega, hxl, fun p hp => ?_⟩
      rw [hx p hp, ite_eq_left (by omega)]
  · exact hinv

theorem mgf1_eq (H : List Byte → List Byte) (L : Nat) (seed : List Byte) (n : Nat) :
    mgf1 H L seed n = (mgfStream H seed ((n + L - 1) / L)).take n := rfl

theorem mgfStream_agree (H : List Byte → List Byte) (L : Nat) (hH : ∀ m, (H m).length = L)
    (seed : List Byte) (a b p : Nat) (ha : p < a * L) (hb : p < b * L) :
    (mgfStream H seed a)[p]! = (mgfStream H seed b)[p]! := by
  rcases le_total a b with h | h
  · obtain ⟨n, rfl⟩ := Nat.exists_eq_add_of_le h
    exact (mgfStream_stable H L hH seed a n p ha).symm
  · obtain ⟨n, rfl⟩ := Nat.exists_eq_add_of_le h
    exact mgfStream_stable H L hH seed b n p hb

/-- MGF1: `mgf1_xor` XORs MGF1's output, as long as `out`, into it. -/
theorem mgf1_xor_spec (hs : HashSpec inst H B L max Abs CAbs) (hnew : inst.new ⦃ c => CAbs [] c ⦄)
    (hL : 0 < L) (seed : Slice U8) (hseed : seed.length + 4 ≤ max) (h_len : Usize) (hh : h_len.val = L)
    (out : Slice U8) (hout : out.length ≤ 1024) :
    high.pkcs1.mgf1_xor inst seed h_len out ⦃ o => o.length = out.length ∧
      bv o.val = List.zipWith (· ^^^ ·) (bv out.val) (mgf1 H L (bv seed.val) out.length) ⦄ := by
  have hHL := hs.out.2.2.2.2
  unfold high.pkcs1.mgf1_xor
  step with mgf1_xor_loop_spec hs hnew hL seed hseed h_len hh out hout out 0#u32 0#usize
    ⟨by simp, rfl, fun p hp => by simp⟩ as ⟨o, c', hc', hol, ho⟩
  refine ⟨hol, ?_⟩
  have hc''L : out.length ≤ (out.length + L - 1) / L * L := by
    have := Nat.div_add_mod' (out.length + L - 1) L
    have := Nat.mod_lt (out.length + L - 1) hL
    omega
  have hoL : out.length = out.val.length := rfl
  have hoL' : o.length = o.val.length := rfl
  have hml : (mgf1 H L (bv seed.val) out.length).length = out.length := by
    rw [mgf1_eq, List.length_take, mgfStream_length H L hHL]
    omega
  apply List.ext_getElem
  · rw [List.length_zipWith, hml, bv_length, bv_length]; omega
  · intro p h1 h2
    have hp : p < out.length := by rw [bv_length] at h1; omega
    rw [List.getElem_zipWith, ← getElem!_pos (bv o.val) p h1]
    rw [bv_getElem! _ _ (by omega), ho p hp]
    congr 1
    · rw [← getElem!_pos, bv_getElem! _ _ (by omega)]
    · rw [← getElem!_pos, mgf1_eq, List.getElem!_take_of_lt _ _ _ hp]
      exact mgfStream_agree H L hHL _ c' ((out.length + L - 1) / L) p (by omega) (by omega)

end

/-- `leading_zeroes` counts the zero bytes `bytes` starts with: those below
it are zero, and the one at it, if any, is not. -/
theorem leading_zeroes_spec (bytes : Slice U8) :
    high.pkcs1.leading_zeroes bytes ⦃ r => r.val ≤ bytes.length ∧
      (∀ j < r.val, bytes.val[j]! = 0#u8) ∧ (r.val < bytes.length → bytes.val[r.val]! ≠ 0#u8) ⦄ := by
  unfold high.pkcs1.leading_zeroes high.pkcs1.leading_zeroes_loop
  have hbL : bytes.length = bytes.val.length := rfl
  apply loop.spec_decr_nat (fun x => x.1.end.val - x.1.start.val)
    (fun x : core.ops.range.Range Usize × Usize × Bool => x.1.end.val = bytes.length ∧
      x.1.start.val ≤ x.1.end.val ∧ x.2.1.val ≤ x.1.start.val ∧ (∀ j < x.2.1.val, bytes.val[j]! = 0#u8) ∧
      (x.2.2 = true ↔ x.2.1.val = x.1.start.val) ∧
      (x.2.1.val < x.1.start.val → bytes.val[x.2.1.val]! ≠ 0#u8))
  · rintro ⟨it, len, z⟩ ⟨he, hs, hl, hz, hzt, hnz⟩
    simp only at he hs hl hz hzt hnz
    unfold high.pkcs1.leading_zeroes_loop.body
    step as ⟨op, iter1, hop, hend1⟩
    cases op with
    | none =>
      have : it.start.val = bytes.length := by
        split at hop
        · simp at hop
        · omega
      simp only [WP.spec_ok]
      exact ⟨by omega, hz, by rw [← this]; exact hnz⟩
    | some i =>
      have hlt : it.start.val < it.end.val := by
        by_contra hc; simp [hc] at hop
      simp only [hlt, ↓reduceIte, Option.some.injEq] at hop
      obtain ⟨rfl, hst⟩ := hop
      have h3 : iter1.end.val = it.end.val := by rw [hend1]
      step as ⟨b, hb⟩
      have hb' : b = bytes.val[it.start.val]! := by rw [hb, getElem!_pos]
      have hbl : it.start.val < bytes.val.length := by omega
      by_cases hc : z = true ∧ b = 0#u8
      · obtain ⟨rfl, hb0⟩ := hc
        have hlen : len.val = it.start.val := hzt.mp rfl
        simp only [hb0, decide_true, Bool.and_self, core.convert.num.FromUsizeBool.from, lift]
        step as ⟨l1, hl1⟩
        refine ⟨by omega, by omega, by simp at hl1 ⊢; omega, fun j hj => ?_, by simp at hl1 ⊢; omega,
          fun h => by simp at hl1 h ⊢; omega, by omega⟩
        simp at hl1
        by_cases hjs : j < it.start.val
        · exact hz j (by omega)
        · rw [show j = it.start.val by omega, ← hb', hb0]
      · have hf : (z && decide (b = 0#u8)) = false := by
          cases z <;> simp_all
        simp only [hf, core.convert.num.FromUsizeBool.from, lift]
        step as ⟨l1, hl1⟩
        simp at hl1
        refine ⟨by omega, by omega, by omega, fun j hj => hz j (by omega), by simp; omega, fun h => ?_, by omega⟩
        rw [hl1]
        by_cases hls : len.val < it.start.val
        · exact hnz hls
        · have hlen : len.val = it.start.val := by omega
          have hz1 : z = true := hzt.mpr hlen
          rw [hlen, ← hb']
          intro hb0; exact hc ⟨hz1, hb0⟩
  · exact ⟨by simp, by simp, by simp, by simp, by simp, by simp⟩

set_option maxRecDepth 8000 in
theorem land_mask_aux (t : Nat) (ht : t ≤ 7) :
    ∀ x < 256, (x &&& (255 - (255 >>> t)) = 0 ↔ x < 2 ^ (8 - t)) := by
  interval_cases t <;> decide

private theorem bv_take' (x : List U8) (n : Nat) : bv (x.take n) = (bv x).take n := List.map_take ..

theorem shr_mask (t : Nat) (ht : t ≤ 7) : 255 >>> t = 2 ^ (8 - t) - 1 := by
  interval_cases t <;> rfl

/-- EMSA-PSS-VERIFY's steps 3, 4 and 6 hold of any `EM` it accepts. -/
theorem emsaPssVerify_checks (H : List Byte → List Byte) (L : Nat) (M EM : List Byte) (emBits s : Nat)
    (h : emsaPssVerify H L M EM emBits s) :
    L + s + 2 ≤ EM.length ∧ EM.getLast? = some 0xbc ∧
      ((EM.take (EM.length - L - 1)).headD 0).toNat < 2 ^ (8 - (8 * EM.length - emBits)) := by
  unfold emsaPssVerify at h
  exact ⟨h.1, h.2.1, h.2.2.1⟩

/-- EMSA-PSS-VERIFY of an `EM` that passes steps 3, 4 and 6, in terms of
`DB` and `H`, as `verify_pss_sig` computes them. -/
theorem emsaPssVerify_iff (H : List Byte → List Byte) (L : Nat) (M : List Byte) (E : List U8)
    (emBits s : Nat) (h db : List U8) (hc1 : L + s + 2 ≤ E.length) (hc2 : (bv E).getLast? = some 0xbc)
    (hc3 : ((bv (E.take (E.length - L - 1))).headD 0).toNat < 2 ^ (8 - (8 * E.length - emBits)))
    (hh : bv h = ((bv E).drop (E.length - L - 1)).take L)
    (hdb : bv db = (List.zipWith (· ^^^ ·) (bv (E.take (E.length - L - 1)))
      (mgf1 H L (bv h) (E.length - L - 1))).modifyHead
        fun b => b &&& BitVec.ofNat 8 (2 ^ (8 - (8 * E.length - emBits)) - 1)) :
    emsaPssVerify H L M (bv E) emBits s ↔
      (∀ b ∈ db.take (E.length - L - s - 2), b = 0#u8) ∧ db[E.length - L - s - 2]? = some 1#u8 ∧
        H (List.replicate 8 0x00 ++ H M ++ bv (db.drop (E.length - L - s - 1))) = bv h := by
  unfold emsaPssVerify
  dsimp only
  rw [bv_length, ← bv_take', ← hh, ← hdb]
  simp only [hc1, hc2, hc3, true_and]
  have hz : ∀ p, (∀ b ∈ (bv db).take p, b = 0x00) ↔ ∀ b ∈ db.take p, b = 0#u8 := by
    intro p
    rw [← bv_take']
    simp only [bv, List.mem_map, forall_exists_index, and_imp, forall_apply_eq_imp_iff₂]
    refine forall₂_congr fun b _ => ?_
    constructor
    · intro hb; cases b; simp_all; rfl
    · rintro rfl; rfl
  have h1 : ∀ p : Nat, (bv db)[p]? = some 0x01 ↔ db[p]? = some 1#u8 := by
    intro p
    simp only [bv, List.getElem?_map]
    cases db[p]? with
    | none => simp
    | some b =>
      simp only [Option.map_some, Option.some.injEq]
      constructor
      · intro hb; cases b; simp_all; rfl
      · rintro rfl; rfl
  rw [hz, h1, show E.length - L - 1 - s = E.length - L - s - 1 by omega, bv, ← List.map_drop, ← bv]

/-- EMSA-PSS-VERIFY with salt length `sLen`, or with some salt length for
`none`. -/
def PssAccepts (H : List Byte → List Byte) (L : Nat) (M EM : List Byte) (emBits : Nat) :
    Option Nat → Prop
  | some s => emsaPssVerify H L M EM emBits s
  | none => ∃ s, emsaPssVerify H L M EM emBits s

theorem pssAccepts_some (H : List Byte → List Byte) (L : Nat) (M EM : List Byte) (emBits : Nat)
    (o : Option Nat) (h : PssAccepts H L M EM emBits o) : ∃ s, emsaPssVerify H L M EM emBits s := by
  cases o with
  | none => exact h
  | some s => exact ⟨s, h⟩

theorem getLast?_bv (E : List U8) (hn : 0 < E.length) :
    (bv E).getLast? = some (E[E.length - 1]!).bv := by
  rw [List.getLast?_eq_getElem?, bv_length, bv, List.getElem?_map, getElem!_pos E _ (by omega),
    List.getElem?_eq_getElem (by omega)]
  rfl

theorem headD_bv_take (E : List U8) (k : Nat) (hk : 0 < k) (hE : 0 < E.length) :
    ((bv (E.take k)).headD 0).toNat = E[0]!.val := by
  obtain ⟨a, E', rfl⟩ : ∃ a E', E = a :: E' := by
    cases E with
    | nil => simp at hE
    | cons a E' => exact ⟨a, E', rfl⟩
  obtain ⟨k', rfl⟩ : ∃ k', k = k' + 1 := ⟨k - 1, by omega⟩
  simp [bv]

theorem bv_set_head (x : List U8) (hx : 0 < x.length) (m : U8) :
    bv (x.set 0 (x[0]! &&& m)) = (bv x).modifyHead (· &&& m.bv) := by
  cases x with
  | nil => simp at hx
  | cons a x => simp [bv, UScalar.bv_and]

/-- EMSA-PSS-VERIFY's step 10 as `verify_pss_sig` checks it. -/
theorem pss_db_iff (db : List U8) (p : Nat) (P : Prop) :
    ((∀ b ∈ db.take p, b = 0#u8) ∧ db[p]? = some 1#u8 ∧ P) ↔
      ((∀ j < p, db[j]! = 0#u8) ∧ p < db.length ∧ db[p]! = 1#u8 ∧ P) := by
  constructor
  · rintro ⟨hz, h1, hP⟩
    have hp : p < db.length := by
      by_contra hc
      rw [List.getElem?_eq_none (by omega)] at h1
      cases h1
    refine ⟨fun j hj => ?_, hp, ?_, hP⟩
    · have := hz _ (List.getElem_mem (l := db.take p) (n := j) (by simp; omega))
      rw [List.getElem_take] at this
      rw [getElem!_pos db j (by omega)]
      exact this
    · rw [List.getElem?_eq_getElem hp] at h1
      rw [getElem!_pos db p hp]
      exact Option.some.inj h1
  · rintro ⟨hz, hp, h1, hP⟩
    refine ⟨fun b hb => ?_, ?_, hP⟩
    · obtain ⟨j, hj, rfl⟩ := List.mem_iff_getElem.mp hb
      simp only [List.length_take] at hj
      rw [List.getElem_take, ← getElem!_pos]
      exact hz j (by omega)
    · rw [List.getElem?_eq_getElem hp, ← getElem!_pos db p hp, h1]

theorem mask_toNat (t : Nat) (ht : t ≤ 7) : (BitVec.ofNat 8 (2 ^ (8 - t) - 1)).toNat = 255 >>> t := by
  interval_cases t <;> rfl

/-- `Digest::ct_equal` compares the digest's bytes with `other`'s. -/
theorem digest_ct_equal_spec (h : low.entry.Entry.assert_held = ok ()) (d : high.digest.Digest)
    (other : Slice U8) :
    high.digest.Digest.ct_equal d other ⦃ b => b = decide (digestBytes d = bv other.val) ⦄ := by
  unfold high.digest.Digest.ct_equal
  step with digest_as_ref_spec d as ⟨s, _, hsb⟩
  apply WP.spec_bind (ct_equal_spec h s other)
  rintro _ rfl
  simp only [low.ct.into_public, WP.spec_ok, ← hsb, bv_inj]

section
variable {Self C S : Type} {inst : high.hash.Hash Self C S} {H : List Byte → List Byte}
  {B L max : Nat} {Abs : List U8 → S → Prop} {CAbs : List U8 → C → Prop}

set_option maxHeartbeats 1000000 in
/-- EMSA-PSS-VERIFY: `verify_pss_sig` accepts `em` exactly when RFC 8017
does, with the salt length given or, for `None`, with some salt length. -/
theorem verify_pss_sig_spec (hs : HashSpec inst H B L max Abs CAbs) (hnew : inst.new ⦃ c => CAbs [] c ⦄)
    (hL : 0 < L) (hmax : 2048 ≤ max) (hheld : low.entry.Entry.assert_held = ok ())
    (em : Slice U8) (em_bits : Usize) (hem : em.length = (em_bits.val + 7) / 8) (hem1024 : em.length ≤ 1024)
    (m_hash : Slice U8) (M : List Byte) (hmh : bv m_hash.val = H M) (s_len : Option Usize)
    (hsl : ∀ s, s_len = some s → s.val ≤ 65535) :
    high.pkcs1.verify_pss_sig inst em em_bits m_hash s_len ⦃ r _ =>
      r = .Ok () ↔ PssAccepts H L M (bv em.val) em_bits.val (s_len.map (·.val)) ⦄ := by
  have hHL := hs.out.2.2.2.2
  have hmL : m_hash.length = L := by rw [← hHL M, ← hmh, bv_length]
  have hemL : em.length = em.val.length := rfl
  have hn : em.len.val = em.length := rfl
  have hmn : m_hash.len.val = L := hmL
  have hL64 : L ≤ 64 := hs.out.2.1
  have htop : 8 * em.length - em_bits.val ≤ 7 := by omega
  have hsv : (core.option.Option.unwrap_or s_len 0#usize).val ≤ 65535 := by
    cases s_len with
    | none => simp
    | some s => simpa using hsl s rfl
  clear hsl
  unfold high.pkcs1.verify_pss_sig
  step as ⟨i, hi⟩
  step as ⟨i1, hi1, _⟩
  step as ⟨tm, htmb, htmv⟩
  step as ⟨i2, hi2⟩
  step as ⟨i3, hi3⟩
  step as ⟨i4, hi4⟩
  have hi1' : i1.val = 8 * em.length - em_bits.val := by rw [hi1, hi]; rfl
  split
  · rename_i hlt
    have hlt' : em.length < L + i2.val + 2 := by scalar_tac
    simp only [WP.spec_ok, WP.uncurry', reduceCtorEq, false_iff]
    cases s_len with
    | none =>
      simp only [Option.map, PssAccepts]
      rintro ⟨s, h⟩
      have := (emsaPssVerify_checks _ _ _ _ _ _ h).1
      rw [bv_length] at this
      simp [hi2] at hlt'
      omega
    | some s =>
      simp only [Option.map, PssAccepts]
      intro h
      have := (emsaPssVerify_checks _ _ _ _ _ _ h).1
      rw [bv_length] at this
      simp [hi2] at hlt'
      omega
  · rename_i hge
    have hge' : L + i2.val + 2 ≤ em.length := by scalar_tac
    step as ⟨i5, hi5⟩
    step as ⟨i6, hi6⟩
    have hlast : (bv em.val).getLast? = some i6.bv := by
      rw [getLast?_bv _ (by omega), hi6, ← getElem!_pos, hi5, hn, hemL]
    split
    · rename_i hne
      simp only [WP.spec_ok, WP.uncurry', reduceCtorEq, false_iff]
      intro h
      obtain ⟨s, hv⟩ := pssAccepts_some _ _ _ _ _ _ h
      have h2 := (emsaPssVerify_checks _ _ _ _ _ _ hv).2.1
      rw [hlast, Option.some.injEq] at h2
      have : i6 = 188#u8 := by
        rw [UScalar.eq_equiv]; show i6.bv.toNat = 188; rw [h2]; rfl
      simp [this] at hne
    · rename_i heq
      have hbc : i6.val = 188 := by simpa using heq
      have hc2 : (bv em.val).getLast? = some 0xbc := by
        rw [hlast]; congr 1; apply BitVec.eq_of_toNat_eq; exact hbc
      step as ⟨i7, hi7⟩
      step as ⟨i8, hi8⟩
      step as ⟨md, hbc', back, hmdl, hhbcl, hmdv, hhbcv, hback⟩
      have hi8v : i8.val = em.length - L - 1 := by rw [hi8, hi7, hn, hmn]
      step with core.slice.index.SliceIndexRangeToUsizeSlice.index.step_spec ⟨m_hash.len⟩ hbc'
        (by simp only [hhbcl]; omega) as ⟨h, hhv, hhl⟩
      step as ⟨i9, hi9⟩
      step as ⟨i10, hi10⟩
      step as ⟨i11, hi11⟩
      have hi9v : i9.val = em.val[0]!.val := by
        rw [hi9, ← getElem!_pos, hmdv, List.getElem!_take_of_lt _ _ _ (by omega)]
      have hi10v : i10.val = 255 - tm.val := by
        have := congrArg BitVec.toNat (show i10.bv = ~~~tm.bv by subst hi10; rfl)
        rw [BitVec.toNat_not] at this
        exact this
      have hmask : i11.val = 0 ↔ i9.val < 2 ^ (8 - i1.val) := by
        rw [hi11, UScalar.val_and, hi10v, htmb]
        exact land_mask_aux _ (by omega) _ (by scalar_tac)
      have hhd : ((bv (em.val.take (em.length - L - 1))).headD 0).toNat = em.val[0]!.val :=
        headD_bv_take _ _ (by omega) (by omega)
      split
      · rename_i hne
        simp only [WP.spec_ok, WP.uncurry', reduceCtorEq, false_iff]
        intro hp
        obtain ⟨s, hv⟩ := pssAccepts_some _ _ _ _ _ _ hp
        have h3 := (emsaPssVerify_checks _ _ _ _ _ _ hv).2.2
        rw [bv_length, ← bv_take', hhd, ← hi9v, ← hi1', ← hmask] at h3
        have : i11 = 0#u8 := by rw [UScalar.eq_equiv]; exact h3
        simp [this] at hne
      · rename_i hz
        have hz' : i9.val < 2 ^ (8 - i1.val) := by
          rw [← hmask]; simpa using hz
        step with mgf1_xor_spec hs hnew hL h (by omega) m_hash.len hmn md (by omega) as ⟨md1, hmd1l, hmd1v⟩
        step as ⟨i12, hi12⟩
        step as ⟨i13, hi13⟩
        step as ⟨u, back2, hu, hback2⟩
        clear hu u
        set db0 := back2 i13 with hdb0
        have hmd1L : md1.length = md1.val.length := rfl
        have hdb0v : db0.val = md1.val.set 0 i13 := by rw [hdb0, hback2, Slice.set_val_eq]; rfl
        have hdb0l : db0.length = em.length - L - 1 := by
          show db0.val.length = _
          rw [hdb0v, List.length_set, ← hmd1L, hmd1l, hmdl, hi8v]
        have hi13' : i13 = md1.val[0]! &&& tm := by
          rw [UScalar.eq_equiv, hi13, hi12, getElem!_pos]
        have htmbv : tm.bv = BitVec.ofNat 8 (2 ^ (8 - i1.val) - 1) := by
          apply BitVec.eq_of_toNat_eq
          rw [mask_toNat _ (by omega)]
          exact htmb
        have hdb : bv db0.val = (List.zipWith (· ^^^ ·) (bv (em.val.take (em.val.length - L - 1)))
            (mgf1 H L (bv h.val) (em.val.length - L - 1))).modifyHead
              fun b => b &&& BitVec.ofNat 8 (2 ^ (8 - (8 * em.val.length - em_bits.val)) - 1) := by
          rw [hdb0v, hi13', bv_set_head _ (by omega), hmd1v, hmdl, hmdv, htmbv, hi8v, hi1', hemL]
        have hhb : bv h.val = ((bv em.val).drop (em.val.length - L - 1)).take L := by
          rw [hhv, List.slice_zero_j, hhbcv, hmn, hi8v, hemL]
          simp only [bv, List.map_take, List.map_drop]
        apply WP.spec_bind (Pₘ := fun p : Slice U8 × Usize => p.1 = db0 ∧ p.2.val ≤ db0.length ∧
          (∀ s, s_len = some s → p.2.val = em.length - L - s.val - 2) ∧
          (s_len = none → (∀ j < p.2.val, db0.val[j]! = 0#u8) ∧
            (p.2.val < db0.length → db0.val[p.2.val]! ≠ 0#u8)))
        · cases s_len with
          | none =>
            dsimp only
            step with leading_zeroes_spec db0 as ⟨ps, hps1, hps2, hps3⟩
            exact ⟨hps1, by simp, hps2, hps3⟩
          | some s =>
            dsimp only
            simp at hi2
            step as ⟨i14, hi14⟩
            step as ⟨ps, hps⟩
            refine ⟨by rw [hdb0l]; omega, fun s1 h1 => ?_, by simp⟩
            simp only [Option.some.injEq] at h1
            subst h1
            rw [hps, hi14, hi7, hn, hmn]
        · rintro ⟨db, ps⟩ ⟨rfl, hps, hsome, hnone⟩
          simp only at hps hsome hnone
          have hc3' : ((bv (em.val.take (em.val.length - L - 1))).headD 0).toNat <
              2 ^ (8 - (8 * em.val.length - em_bits.val)) := by
            rw [← hemL, hhd, ← hi9v, ← hi1']; exact hz'
          have hacc : PssAccepts H L M (bv em.val) em_bits.val (s_len.map (·.val)) ↔
              (∀ j < ps.val, db0.val[j]! = 0#u8) ∧ ps.val < db0.val.length ∧ db0.val[ps.val]! = 1#u8 ∧
                H (List.replicate 8 0x00 ++ H M ++ bv (db0.val.drop (ps.val + 1))) = bv h.val := by
            have hdbL : db0.val.length = em.val.length - L - 1 := hdb0l
            cases s_len with
            | some s =>
              have hps' := hsome s rfl
              simp only [core.option.Option.unwrap_or] at hi2
              subst hi2
              simp only [Option.map, PssAccepts]
              rw [emsaPssVerify_iff H L M em.val em_bits.val i2.val h.val db0.val (by omega) hc2 hc3' hhb hdb,
                pss_db_iff, show em.val.length - L - i2.val - 2 = ps.val by omega,
                show em.val.length - L - i2.val - 1 = ps.val + 1 by omega]
            | none =>
              obtain ⟨hz0, hnz⟩ := hnone rfl
              simp only [Option.map, PssAccepts]
              constructor
              · rintro ⟨s, hv⟩
                have hc1 := (emsaPssVerify_checks _ _ _ _ _ _ hv).1
                rw [bv_length] at hc1
                rw [emsaPssVerify_iff H L M em.val em_bits.val s h.val db0.val hc1 hc2 hc3' hhb hdb,
                  pss_db_iff] at hv
                obtain ⟨hz1, hlt, h1, hP⟩ := hv
                have : ps.val = em.val.length - L - s - 2 := by
                  by_contra hne
                  rcases Nat.lt_or_gt_of_ne hne with hlt' | hgt
                  · exact hnz (by omega) (hz1 _ hlt')
                  · rw [hz0 _ hgt] at h1; exact absurd h1 (by decide)
                rw [this, show em.val.length - L - s - 2 + 1 = em.val.length - L - s - 1 by omega]
                exact ⟨hz1, hlt, h1, hP⟩
              · rintro ⟨hz1, hlt, h1, hP⟩
                refine ⟨em.val.length - L - 2 - ps.val, ?_⟩
                rw [emsaPssVerify_iff H L M em.val em_bits.val _ h.val db0.val (by omega) hc2 hc3' hhb hdb,
                  pss_db_iff, show em.val.length - L - (em.val.length - L - 2 - ps.val) - 2 = ps.val by omega,
                  show em.val.length - L - (em.val.length - L - 2 - ps.val) - 1 = ps.val + 1 by omega]
                exact ⟨hz1, hlt, h1, hP⟩
          step with core.slice.index.SliceIndexRangeToUsizeSlice.index.step_spec ⟨ps⟩ db0 (by omega)
            as ⟨sl, hslv, hsll⟩
          step with leading_zeroes_spec sl as ⟨z, hz1, hz2, hz3⟩
          have hsl : ∀ j < ps.val, sl.val[j]! = db0.val[j]! := fun j hj => by
            rw [hslv, List.slice_zero_j, List.getElem!_take_of_lt _ _ _ hj]
          have hzero : z = ps ↔ ∀ j < ps.val, db0.val[j]! = 0#u8 := by
            constructor
            · rintro rfl j hj; rw [← hsl j hj]; exact hz2 j hj
            · intro hall
              rw [UScalar.eq_equiv]
              by_contra hne
              exact hz3 (by omega) (by rw [hsl _ (by omega)]; exact hall _ (by omega))
          split
          · rename_i hne
            simp only [WP.spec_ok, WP.uncurry', reduceCtorEq, false_iff]
            rw [hacc]; rintro ⟨hall, -⟩
            simp [hzero.mpr hall] at hne
          · rename_i heq
            have hall := hzero.mp (by rw [UScalar.eq_equiv]; simpa using heq)
            split
            · rename_i hge
              simp only [WP.spec_ok, WP.uncurry', reduceCtorEq, false_iff]
              rw [hacc]; rintro ⟨-, hlt, -⟩
              scalar_tac
            · rename_i hlt
              have hlt' : ps.val < db0.length := by scalar_tac
              step as ⟨i16, hi16⟩
              have hi16' : i16 = db0.val[ps.val]! := by rw [hi16, getElem!_pos]
              split
              · rename_i hne
                simp only [WP.spec_ok, WP.uncurry', reduceCtorEq, false_iff]
                rw [hacc]; rintro ⟨-, -, h1, -⟩
                simp [hi16', h1] at hne
              · rename_i h1
                have h1' : db0.val[ps.val]! = 1#u8 := by rw [← hi16', UScalar.eq_equiv]; simpa using h1
                step as ⟨i17, hi17⟩
                step as ⟨salt, hsaltv, hsaltl⟩
                step with hnew as ⟨ctx, hctx⟩
                step as ⟨s1, hs1⟩
                have hs1v : s1.val = List.replicate 8 0#u8 := by
                  rw [hs1]; simp only [Std.Array.to_slice, Array.repeat_val]; rfl
                have hs1l : s1.length = 8 := by
                  show s1.val.length = 8; rw [hs1v, List.length_replicate]
                have hsaltL : salt.length = salt.val.length := rfl
                have hmhL : m_hash.length = m_hash.val.length := rfl
                step with hs.update [] ctx s1 hctx (by simp only [List.length_nil]; omega) as ⟨ctx1, hctx1⟩
                step with hs.update _ ctx1 m_hash hctx1 (by simp only [List.nil_append, hs1v, List.length_replicate]; omega)
                  as ⟨ctx2, hctx2⟩
                step with hs.update _ ctx2 salt hctx2
                  (by simp only [List.nil_append, List.length_append, hs1v, List.length_replicate]; omega) as ⟨ctx3, hctx3⟩
                step with hs.finish _ ctx3 hctx3
                  (by simp only [List.nil_append, List.length_append, hs1v, List.length_replicate]; omega) as ⟨d, hdl, hdv⟩
                step with digest_ct_equal_spec hheld d h as ⟨b, hb⟩
                subst hb
                have hfin : digestBytes d = bv h.val ↔
                    H (List.replicate 8 0x00 ++ H M ++ bv (db0.val.drop (ps.val + 1))) = bv h.val := by
                  rw [hdv, List.nil_append, bv, List.map_append, List.map_append, ← bv, ← bv,
                    ← bv, hs1v, hmh, hsaltv, hi17]
                  rfl
                rw [hacc]
                by_cases hq : digestBytes d = bv h.val
                · simp only [hq, decide_true, ↓reduceIte, WP.spec_ok, WP.uncurry', true_iff]
                  exact ⟨hall, hlt', h1', hfin.mp hq⟩
                · simp only [hq, decide_false, Bool.false_eq_true, ↓reduceIte, WP.spec_ok, WP.uncurry',
                    reduceCtorEq, false_iff]
                  rintro ⟨-, -, -, hP⟩
                  exact hq (hfin.mpr hP)

end

end rind.x86_64
