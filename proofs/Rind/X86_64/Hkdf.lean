import Rind.X86_64.Kdf.Funs
import Rind.X86_64.HmacApi
open Aeneas Aeneas.Std Result rind.spec

/-!
# HKDF's API, `high::hkdf`

`Salt::extract` is RFC 5869's HKDF-Extract and `Okm::fill` its HKDF-Expand,
over HMAC with any of `high::hmac`'s hashes, down to `Rind.X86_64.HmacApi`.
`Salt`, `Prk`, and `Okm` are translated in the second Aeneas pass, and
`Prk::expand_into`'s loop is modelled in `Rind.X86_64.HkdfExpand`.
`admin/prove` writes the aarch64 proof from this file by renaming the target.
-/

namespace rind.x86_64.kdf

/-! ## HKDF-Expand's blocks -/

section
variable (prf : List Byte → List Byte → List Byte) (prk info : List Byte)

/-- HKDF-Expand's `T(i)`. -/
def hkdfT : Nat → List Byte
  | 0 => []
  | i + 1 => prf prk (hkdfT i ++ info ++ [BitVec.ofNat 8 (i + 1)])

/-- `T(1) | ... | T(j)`. -/
def hkdfOut (j : Nat) : List Byte := (List.range j).flatMap fun i => hkdfT prf prk info (i + 1)

theorem hkdfOut_succ (j : Nat) :
    hkdfOut prf prk info (j + 1) = hkdfOut prf prk info j ++ hkdfT prf prk info (j + 1) := by
  simp [hkdfOut, List.range_succ, List.flatMap_append]

theorem hkdf_fold (j : Nat) :
    (List.range j).foldl (fun (acc : List Byte × List Byte) i =>
      let t := prf prk (acc.1 ++ info ++ [BitVec.ofNat 8 (i + 1)])
      (t, acc.2 ++ t)) ([], []) = (hkdfT prf prk info j, hkdfOut prf prk info j) := by
  induction j with
  | zero => rfl
  | succ j ih =>
    rw [List.range_succ, List.foldl_append, ih, hkdfOut_succ]
    rfl

theorem hkdfExpand_eq (n L : Nat) :
    hkdfExpand prf n prk info L = (hkdfOut prf prk info ((L + n - 1) / n)).take L := by
  simp only [hkdfExpand, hkdf_fold]

theorem hkdfOut_length (n : Nat) (hn : ∀ x, (prf prk x).length = n) (j : Nat) :
    (hkdfOut prf prk info j).length = j * n := by
  induction j with
  | zero => simp [hkdfOut]
  | succ j ih => rw [hkdfOut_succ, List.length_append, ih, hkdfT, hn]; ring

theorem hkdfOut_take (n : Nat) (hn : ∀ x, (prf prk x).length = n) (L j d : Nat)
    (hj : L ≤ j * n) : (hkdfOut prf prk info (j + d)).take L = (hkdfOut prf prk info j).take L := by
  induction d with
  | zero => rfl
  | succ d ih =>
    rw [← Nat.add_assoc, hkdfOut_succ, List.take_append_of_le_length
      (by rw [hkdfOut_length prf prk info n hn]; nlinarith), ih]

end

/-! ## `Prk::expand_into` -/

theorem bv_append (x y : List U8) : bv (x ++ y) = bv x ++ bv y := List.map_append

theorem bv_take (x : List U8) (n : Nat) : bv (x.take n) = (bv x).take n := List.map_take ..

theorem bv_length (x : List U8) : (bv x).length = x.length := List.length_map ..

/-- `info`'s parts, joined. -/
def infoBytes (info : Slice (Slice U8)) : List U8 := info.val.flatMap (·.val)

theorem stream_updates_spec (a : high.hmac.Algorithm) (hr : RunsHmac a) (key : List Byte)
    (parts : List (Slice U8)) (p : List U8) (s : high.hmac.Streaming)
    (hs : StreamOf a key p s)
    (hm : hmacBlock a + p.length + (parts.flatMap (·.val)).length ≤ maxInput) :
    parts.foldlM high.hmac.Streaming.update s ⦃ s' =>
      StreamOf a key (p ++ parts.flatMap (·.val)) s' ⦄ := by
  induction parts generalizing p s with
  | nil =>
    simp only [List.foldlM_nil, List.flatMap_nil, List.append_nil]
    exact (WP.spec_ok s).mpr hs
  | cons x parts ih =>
    simp only [List.foldlM_cons, List.flatMap_cons, List.length_append] at hm ⊢
    apply WP.spec_bind (stream_update_spec a hr key p s hs x (by simp only [Slice.length]; omega))
    intro s' hs'
    have := ih (p ++ x.val) s' hs' (by simp only [List.length_append]; omega)
    simpa using this

theorem counterSlice_val (c : Nat) : (counterSlice c).val = [⟨BitVec.ofNat 8 c⟩] := by
  simp [counterSlice]

theorem expand_into_loop_spec (a : high.hmac.Algorithm) (hr : RunsHmac a) (prk : List Byte)
    (k : high.hmac.Key) (hk : KeyOf a prk k) (info : Slice (Slice U8))
    (hinfo : hmacBlock a + tagLen a + (infoBytes info).length + 1 ≤ maxInput) :
    ∀ (m c : Nat) (block : Option high.digest.Digest) (out : Slice U8),
      out.length - (c - 1) * tagLen a = m → 1 ≤ c →
      (match block with
        | none => c = 1
        | some t => outLen t.algorithm = tagLen a ∧
            digestBytes t = hkdfT (hmacOf a) prk (bv (infoBytes info)) (c - 1)) →
      out.length ≤ 255 * tagLen a →
      (bv out.val).take ((c - 1) * tagLen a) =
        (hkdfOut (hmacOf a) prk (bv (infoBytes info)) (c - 1)).take out.length →
      high.hkdf.Prk.expand_into_loop k info (tagLen a) block c ((c - 1) * tagLen a) out ⦃ r =>
        r.length = out.length ∧
          bv r.val = (hkdfOut (hmacOf a) prk (bv (infoBytes info))
            ((out.length + tagLen a - 1) / tagLen a)).take out.length ⦄ := by
  intro m
  induction m using Nat.strong_induction_on with
  | _ m ih =>
  intro c block out hm hc hb hL hpre
  have hn := tagLen_pos a
  have hlen : ∀ x, (hmacOf a prk x).length = tagLen a := fun x => hmacOf_length a prk x hr
  have hTlen : ∀ i, (hkdfT (hmacOf a) prk (bv (infoBytes info)) (i + 1)).length = tagLen a :=
    fun i => hlen _
  rw [high.hkdf.Prk.expand_into_loop]
  split
  · rename_i hcond
    obtain ⟨hoff, hc255, -⟩ := hcond
    obtain ⟨c', rfl⟩ : ∃ c', c = c' + 1 := ⟨c - 1, by omega⟩
    simp only [Nat.add_sub_cancel] at hb hpre hoff hm ⊢
    apply WP.spec_bind (key_start_spec a hr prk k hk)
    intro ctx hctx
    apply WP.spec_bind (Pₘ := fun ctx => ∃ p : List U8,
      bv p = hkdfT (hmacOf a) prk (bv (infoBytes info)) c' ∧ p.length ≤ tagLen a ∧
        StreamOf a prk p ctx)
    · cases block with
      | none =>
        simp only at hb
        obtain rfl : c' = 0 := by omega
        simp only [WP.spec_ok]
        exact ⟨[], rfl, by simp, hctx⟩
      | some t =>
        obtain ⟨htl, htb⟩ := hb
        simp only
        step with digest_as_ref_spec t as ⟨s, hsl, hsb⟩
        apply WP.spec_mono (stream_update_spec a hr prk [] ctx hctx s (by
          have := tagLen_le a
          simp only [List.length_nil, Slice.length] at hsl ⊢; omega))
        intro ctx' hctx'
        refine ⟨s.val, by rw [hsb, htb], ?_, by simpa using hctx'⟩
        simp only [Slice.length] at hsl; omega
    · rintro ctx1 ⟨p, hpb, hpl, hctx1⟩
      apply WP.spec_bind (stream_updates_spec a hr prk info.val p ctx1 hctx1 (by
        show hmacBlock a + p.length + (infoBytes info).length ≤ maxInput
        omega))
      intro ctx2 hctx2
      apply WP.spec_bind (stream_update_spec a hr prk _ ctx2 hctx2 (counterSlice (c' + 1)) (by
        show hmacBlock a + (p ++ infoBytes info).length + (counterSlice (c' + 1)).val.length ≤ maxInput
        simp only [List.length_append, counterSlice_val, List.length_singleton]
        omega))
      intro ctx3 hctx3
      apply WP.spec_bind (stream_finish_spec a hr prk _ ctx3 hctx3 (by
        show hmacBlock a + (p ++ infoBytes info ++ (counterSlice (c' + 1)).val).length ≤ maxInput
        simp only [List.length_append, counterSlice_val, List.length_singleton]
        omega))
      rintro tag ⟨htl, htb⟩
      step with digest_as_ref_spec tag as ⟨s, hsl, hsb⟩
      have hT : bv s.val = hkdfT (hmacOf a) prk (bv (infoBytes info)) (c' + 1) := by
        rw [hsb, htb, hkdfT, ← hpb]
        simp only [bv_append, counterSlice_val]
        rfl
      have hsl' : s.val.length = tagLen a := by
        have : s.length = tagLen a := by rw [hsl, htl]
        simpa only [Slice.length] using this
      have hTl : (hkdfT (hmacOf a) prk (bv (infoBytes info)) (c' + 1)).length = tagLen a := hTlen c'
      have hOl : (hkdfOut (hmacOf a) prk (bv (infoBytes info)) c').length = c' * tagLen a :=
        hkdfOut_length _ _ _ _ hlen c'
      split
      · rename_i hle
        rw [show c' * tagLen a + tagLen a = (c' + 1 + 1 - 1) * tagLen a by
          simp only [Nat.add_sub_cancel]; ring]
        have hlen' := Slice.setSlice!_length out (c' * tagLen a)
          (s.val.take (min (tagLen a) (out.length - c' * tagLen a)))
        apply WP.spec_mono (ih _ (by rw [hlen', Nat.add_sub_cancel, Nat.add_mul, one_mul]; omega)
          (c' + 1 + 1) (some tag)
          (out.setSlice! (c' * tagLen a) (s.val.take (min (tagLen a) (out.length - c' * tagLen a))))
          rfl (by omega) ⟨htl, by rw [Nat.add_sub_cancel, ← hT, hsb]⟩ (by rw [hlen']; exact hL) ?_)
        · rintro r ⟨hrl, hrv⟩
          rw [hlen'] at hrl hrv
          exact ⟨hrl, hrv⟩
        · rw [hlen', Nat.add_sub_cancel, Slice.setSlice!_val, ← bv_take, hkdfOut_succ,
            List.take_append, hOl,
            List.take_of_length_le (l := hkdfOut _ _ _ c') (by rw [hOl]; omega)]
          have hs'l : (s.val.take (min (tagLen a) (out.length - c' * tagLen a))).length =
              min (tagLen a) (out.length - c' * tagLen a) := by
            simp only [List.length_take, hsl']; omega
          have h1 := take_setSlice! out.val (s.val.take (min (tagLen a) (out.length - c' * tagLen a)))
            (c' * tagLen a) (by rw [hs'l]; simp only [Slice.length] at hoff ⊢; omega)
          rw [hs'l] at h1
          have hsetl : (out.val.setSlice! (c' * tagLen a)
              (s.val.take (min (tagLen a) (out.length - c' * tagLen a)))).length = out.length := by
            simp [List.length_setSlice!, Slice.length]
          have htake : (out.val.setSlice! (c' * tagLen a)
              (s.val.take (min (tagLen a) (out.length - c' * tagLen a)))).take ((c' + 1) * tagLen a) =
              out.val.take (c' * tagLen a) ++
                s.val.take (min (tagLen a) (out.length - c' * tagLen a)) := by
            rw [← h1]
            by_cases hcase : tagLen a ≤ out.length - c' * tagLen a
            · rw [show c' * tagLen a + min (tagLen a) (out.length - c' * tagLen a) =
                (c' + 1) * tagLen a by rw [Nat.add_mul, one_mul]; omega]
            · have e1 : (out.val.setSlice! (c' * tagLen a)
                  (s.val.take (min (tagLen a) (out.length - c' * tagLen a)))).take
                  ((c' + 1) * tagLen a) = out.val.setSlice! (c' * tagLen a)
                  (s.val.take (min (tagLen a) (out.length - c' * tagLen a))) :=
                List.take_of_length_le (by rw [hsetl, Nat.add_mul, one_mul]; omega)
              have e2 : (out.val.setSlice! (c' * tagLen a)
                  (s.val.take (min (tagLen a) (out.length - c' * tagLen a)))).take
                  (c' * tagLen a + min (tagLen a) (out.length - c' * tagLen a)) =
                  out.val.setSlice! (c' * tagLen a)
                  (s.val.take (min (tagLen a) (out.length - c' * tagLen a))) :=
                List.take_of_length_le (by rw [hsetl]; omega)
              rw [e1, e2]
          rw [htake, bv_append, bv_take, hpre, List.take_of_length_le (by rw [hOl]; omega), bv_take,
            hT]
          congr 1
          rw [← List.take_take, List.take_of_length_le (l := List.take _ _)
            (by simp only [List.length_take, hTl]; omega)]
      · rename_i hgt
        exfalso
        apply hgt
        simp only [Slice.length] at hsl' ⊢
        omega
  · rename_i hcond
    simp only [WP.spec_ok]
    refine ⟨by simp, ?_⟩
    have hdone : out.length ≤ (c - 1) * tagLen a := by
      by_contra h
      apply hcond
      refine ⟨by omega, ?_, hn⟩
      by_contra h'
      have : 255 * tagLen a ≤ (c - 1) * tagLen a := Nat.mul_le_mul_right _ (by omega)
      omega
    have hout : (bv out.val).take ((c - 1) * tagLen a) = bv out.val :=
      List.take_of_length_le (by rw [bv_length]; exact hdone)
    rw [← hout, hpre]
    have hK : out.length ≤ (out.length + tagLen a - 1) / tagLen a * tagLen a := by
      have h1 := Nat.div_add_mod (out.length + tagLen a - 1) (tagLen a)
      have h2 := Nat.mod_lt (out.length + tagLen a - 1) hn
      rw [Nat.mul_comm] at h1
      omega
    have hKle : (out.length + tagLen a - 1) / tagLen a ≤ c - 1 := by
      have : (out.length + tagLen a - 1) / tagLen a < c := by
        rw [Nat.div_lt_iff_lt_mul hn]
        obtain ⟨c', rfl⟩ : ∃ c', c = c' + 1 := ⟨c - 1, by omega⟩
        simp only [Nat.add_sub_cancel] at hdone
        rw [Nat.add_mul, one_mul]
        omega
      omega
    rw [show c - 1 = (out.length + tagLen a - 1) / tagLen a +
        (c - 1 - (out.length + tagLen a - 1) / tagLen a) by omega,
      hkdfOut_take _ _ _ (tagLen a) hlen _ _ _ hK]

/-- `Prk::expand_into` fills `out` with HKDF-Expand's output. -/
theorem expand_into_spec (a : high.hmac.Algorithm) (hr : RunsHmac a) (prk : List Byte)
    (k : high.hmac.Key) (hk : KeyOf a prk k) (info : Slice (Slice U8))
    (hinfo : hmacBlock a + tagLen a + (infoBytes info).length + 1 ≤ maxInput) (out : Slice U8)
    (hL : out.length ≤ 255 * tagLen a) :
    high.hkdf.Prk.expand_into k info out ⦃ r => r.length = out.length ∧
      bv r.val = hkdfExpand (hmacOf a) (tagLen a) prk (bv (infoBytes info)) out.length ⦄ := by
  obtain ⟨n, hn, hnv⟩ := tagLen_eq a
  have hloop := expand_into_loop_spec a hr prk k hk info hinfo _ 1 none out rfl le_rfl rfl hL
    (by simp [hkdfOut])
  obtain ⟨⟨e, he⟩, -⟩ := hr
  simp only [Nat.sub_self, Nat.zero_mul] at hloop
  unfold high.hkdf.Prk.expand_into
  rw [he, bind_ok, key_algorithm_eq hk, bind_ok, hn, bind_ok,
    if_neg (by rw [hnv]; have := tagLen_pos a; omega), hnv]
  apply WP.spec_mono hloop
  rintro r ⟨h1, h2⟩
  exact ⟨h1, by rw [h2, hkdfExpand_eq]⟩

/-- `Okm::fill` fills `out` with HKDF-Expand's output when `out` is the
length asked for and at most 255 blocks, and refuses it otherwise. -/
theorem okm_fill_spec (a : high.hmac.Algorithm) (hr : RunsHmac a) (prk : List Byte)
    (k : high.hmac.Key) (hk : KeyOf a prk k) (info : Slice (Slice U8))
    (hinfo : hmacBlock a + tagLen a + (infoBytes info).length + 1 ≤ maxInput) (len : Usize)
    (out : Slice U8) :
    high.hkdf.Okm0Usize.fill { prk := k, info, len } out ⦃ r =>
      if out.length = len.val ∧ out.length ≤ 255 * tagLen a then
        r.1 = .Ok () ∧ r.2.length = out.length ∧
          bv r.2.val = hkdfExpand (hmacOf a) (tagLen a) prk (bv (infoBytes info)) out.length
      else r = (.Err .WrongLength, out) ⦄ := by
  obtain ⟨n, hn, hnv⟩ := tagLen_eq a
  have hn64 : tagLen a ≤ 64 := by cases a <;> decide
  unfold high.hkdf.Okm0Usize.fill
  simp only [key_algorithm_eq hk, hn, bind_ok]
  split
  · rename_i hne
    simp only [WP.spec_ok]
    split
    · rename_i hc
      exfalso
      obtain ⟨h, -⟩ := hc
      simp only [bne_iff_ne, ne_eq] at hne
      apply hne
      apply UScalar.eq_of_val_eq
      rw [Slice.len_val, h]
    · trivial
  · rename_i heq
    simp only [bne_iff_ne, ne_eq, Decidable.not_not] at heq
    have hlen : out.length = len.val := by rw [← heq, Slice.len_val]
    step as ⟨i3, hi3⟩
    split
    · rename_i hgt
      simp only [WP.spec_ok]
      split
      · rename_i hc
        exfalso
        obtain ⟨-, h⟩ := hc
        simp only [GT.gt, UScalar.lt_equiv, Slice.len_val] at hgt
        omega
      · trivial
    · rename_i hle
      simp only [GT.gt, UScalar.lt_equiv, Slice.len_val, not_lt] at hle
      apply WP.spec_bind (expand_into_spec a hr prk k hk info hinfo out (by omega))
      rintro r ⟨h1, h2⟩
      simp only [WP.spec_ok]
      split
      · exact ⟨trivial, h1, h2⟩
      · rename_i hc
        exact absurd ⟨hlen, by omega⟩ hc

/-- `Salt::new` keys HMAC with the salt. -/
theorem salt_new_spec (a : high.hmac.Algorithm) (hr : RunsHmac a) (salt : Slice U8)
    (hs : salt.length ≤ maxInput) :
    high.hkdf.Salt.new a salt ⦃ k => KeyOf a (bv salt.val) k ⦄ := by
  unfold high.hkdf.Salt.new
  apply WP.spec_bind (key_new_spec a hr salt hs)
  intro k hk
  simpa using hk

/-- `Salt::extract` is HKDF-Extract: the PRK is HMAC of the secret under the salt. -/
theorem salt_extract_spec (a : high.hmac.Algorithm) (hr : RunsHmac a) (salt : List Byte)
    (k : high.hmac.Key) (hk : KeyOf a salt k) (secret : Slice U8)
    (hm : hmacBlock a + secret.length ≤ maxInput) :
    high.hkdf.Salt.extract k secret ⦃ prk =>
      KeyOf a (hkdfExtract (hmacOf a) salt (bv secret.val)) prk ⦄ := by
  have hsign := sign_spec a hr salt k hk secret hm
  have hnew := key_new_spec a hr
  obtain ⟨⟨e, he⟩, -⟩ := hr
  unfold high.hkdf.Salt.extract
  rw [he, bind_ok]
  apply WP.spec_bind hsign
  rintro d ⟨hdl, hdb⟩
  rw [key_algorithm_eq hk, bind_ok]
  unfold high.hmac.Tag.Insts.CoreConvertAsRefSliceU8.as_ref
  step with digest_as_ref_spec d as ⟨s, hsl, hsb⟩
  apply WP.spec_bind (hnew s (by
    have h64 : tagLen a ≤ 64 := by cases a <;> decide
    rw [hsl, hdl]; unfold maxInput; scalar_tac))
  intro prk hprk
  simp only [WP.spec_ok]
  rw [hsb, hdb] at hprk
  exact hprk

/-- HKDF in rind's calls: `Salt::new(a, salt).extract(ikm).expand(info, len).fill(out)`
fills `out` with RFC 5869's HKDF-Expand of HKDF-Extract's PRK, for any `len`
that is `out`'s length and at most 255 blocks. -/
theorem hkdf_fill (a : high.hmac.Algorithm) (hr : RunsHmac a) (inst : high.hkdf.KeyType Usize)
    (salt ikm : Slice U8) (info : Slice (Slice U8)) (len : Usize) (out : Slice U8)
    (hs : salt.length ≤ maxInput) (hm : hmacBlock a + ikm.length ≤ maxInput)
    (hinfo : hmacBlock a + tagLen a + (infoBytes info).length + 1 ≤ maxInput)
    (hlen : out.length = len.val) (hL : out.length ≤ 255 * tagLen a) :
    (do
      let s ← high.hkdf.Salt.new a salt
      let prk ← high.hkdf.Salt.extract s ikm
      let okm ← high.hkdf.Prk.expand inst prk info len
      high.hkdf.Okm0Usize.fill okm out) ⦃ r =>
      r.1 = .Ok () ∧ bv r.2.val = hkdfExpand (hmacOf a) (tagLen a)
        (hkdfExtract (hmacOf a) (bv salt.val) (bv ikm.val)) (bv (infoBytes info)) out.length ⦄ := by
  apply WP.spec_bind (salt_new_spec a hr salt hs)
  intro s hsk
  apply WP.spec_bind (salt_extract_spec a hr _ s hsk ikm hm)
  intro prk hprk
  simp only [high.hkdf.Prk.expand, bind_ok]
  apply WP.spec_mono (okm_fill_spec a hr _ prk hprk info hinfo len out)
  intro r hr'
  rw [ite_cond_eq_true _ _ (eq_true ⟨hlen, hL⟩)] at hr'
  exact ⟨hr'.1, hr'.2.2⟩

end rind.x86_64.kdf
