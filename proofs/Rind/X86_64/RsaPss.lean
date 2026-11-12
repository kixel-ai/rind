import Rind.X86_64.RsaVerify
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
        rw [if_pos hpq, if_pos (by omega), hz', hy, ht, ← getElem!_pos, ← getElem!_pos, hx _ (by omega),
          if_neg (by omega), show p - done.val = it.start.val by omega, hpq]
      · rw [if_neg hpq, hx p hp]
        by_cases hin : done.val ≤ p ∧ p < done.val + it.start.val
        · rw [if_pos hin, if_pos (by omega)]
        · rw [if_neg hin, if_neg (by omega)]
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
      if_pos (lt_of_lt_of_le hp (Nat.mul_le_mul_right _ (by omega))), ih]

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
      · rw [if_neg (by omega), hx p hp, if_pos hpd, if_pos (by omega), mgfStream_succ, getElem!_append',
          mgfStream_length H L hHL, if_pos hpd]
      · by_cases hpn : p < cx.val * L + L
        · have hdl2 : dx.val + len.val = min (cx.val * L + L) out.length := by rw [hlen', hdc]; omega
          rw [if_pos (by omega)]
          have hxp := hx p (by omega)
          rw [if_neg hpd] at hxp
          simp only [UScalar.bv_xor, hxp]
          rw [if_pos hpn, mgfStream_succ,
            getElem!_append', mgfStream_length H L hHL, if_neg hpd, ← hterm, bv_getElem! _ _ (by
              have : term.length = term.val.length := rfl; omega), hdc]
        · rw [if_neg (by omega), hx p hp, if_neg hpd, if_neg hpn]
    · rename_i hge
      simp only [WP.spec_ok]
      have hge' : out.length ≤ dx.val := by scalar_tac
      refine ⟨cx.val, by omega, hxl, fun p hp => ?_⟩
      rw [hx p hp, if_pos (by omega)]
  · exact hinv

theorem mgf1_eq (H : List Byte → List Byte) (L : Nat) (seed : List Byte) (n : Nat) :
    mgf1 H L seed n = (mgfStream H seed ((n + L - 1) / L)).take n := rfl

theorem bv_length (l : List U8) : (bv l).length = l.length := by simp [bv]

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

end rind.x86_64
