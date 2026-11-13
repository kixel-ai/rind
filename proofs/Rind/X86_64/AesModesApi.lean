import Rind.X86_64.AesModesLow
open Aeneas Aeneas.Std Result rind.vale rind.simd rind.modes

/-!
# `cipher::AesCtr`, `AesCbcEncryptingKey`, and `AesCbcDecryptingKey`

The public CTR and CBC APIs, from `Rind.X86_64.AesModesLow`'s theorems about
the low-level modes alone: `expand_key_mode_spec`, `dec_key_new_mode_spec`,
`aes_ctr_apply_spec`, `aes_cbc_encrypt_spec`, and `aes_cbc_decrypt_spec`, and
the predicates `ModeKeyIs` and `ModeDecKeyIs`. `admin/prove` writes the
aarch64 copy of this file, whose `Rind.Aarch64.AesModesLow` proves the same
names on that target.
-/

namespace rind.x86_64

/-! ## CBC -/

/-- A CBC key is refused unless it is the algorithm's length, and otherwise
holds the round keys of its bytes. -/
theorem aes_cbc_encrypting_key_new_spec (h : RunsAesHw) (alg : Algorithm) (algorithm : cipher.Algorithm)
    (hlen : algorithm.key_len.val = 4 * nk alg) (key : Slice U8) :
    mid.aes_cbc.AesCbcEncryptingKey.new algorithm key ⦃ r =>
      if key.length = 4 * nk alg then ∃ k, r = .Ok k ∧ ModeKeyIs alg (bvs key.val) k.key
      else r = .Err .WrongLength ⦄ := by
  obtain ⟨e, he⟩ := h.1
  unfold mid.aes_cbc.AesCbcEncryptingKey.new
  rw [he, bind_ok]
  by_cases hk : key.length = 4 * nk alg
  · have hne : ¬ (Slice.len key != algorithm.key_len) = true := by
      simp only [bne_iff_ne, ne_eq, not_not]; scalar_tac
    simp only [hne, ite_eq_left hk]
    apply WP.spec_bind (expand_key_mode_spec h alg key hk)
    intro ak hak
    exact (WP.spec_ok _).2 ⟨_, rfl, hak⟩
  · have hne : (Slice.len key != algorithm.key_len) = true := by
      simp only [bne_iff_ne, ne_eq]; intro he; apply hk; rw [← hlen, ← he]; simp
    simp only [hne, ite_true, ite_eq_right hk, WP.spec_ok]

/-- A CBC decryption key is refused unless it is the algorithm's length, and
otherwise holds the inverse cipher's round keys of its bytes. -/
theorem aes_cbc_decrypting_key_new_spec (h : RunsAesHw) (alg : Algorithm) (algorithm : cipher.Algorithm)
    (hlen : algorithm.key_len.val = 4 * nk alg) (key : Slice U8) :
    mid.aes_cbc.AesCbcDecryptingKey.new algorithm key ⦃ r =>
      if key.length = 4 * nk alg then ∃ k, r = .Ok k ∧ ModeDecKeyIs alg (bvs key.val) k.key
      else r = .Err .WrongLength ⦄ := by
  obtain ⟨e, he⟩ := h.1
  unfold mid.aes_cbc.AesCbcDecryptingKey.new
  rw [he, bind_ok]
  by_cases hk : key.length = 4 * nk alg
  · have hne : ¬ (Slice.len key != algorithm.key_len) = true := by
      simp only [bne_iff_ne, ne_eq, not_not]; scalar_tac
    simp only [hne, ite_eq_left hk]
    have hnk : nk alg ≤ 8 := by cases alg <;> decide
    step*
    · simp only [copy_key1_post, low.ct.secret_slice, bind_ok]
      apply WP.spec_bind (dec_key_new_mode_spec h alg key hk)
      intro adk hadk
      exact (WP.spec_ok _).2 ⟨_, rfl, hadk⟩
  · have hne : (Slice.len key != algorithm.key_len) = true := by
      simp only [bne_iff_ne, ne_eq]; intro he; apply hk; rw [← hlen, ← he]; simp
    simp only [hne, ite_true, ite_eq_right hk, WP.spec_ok]

theorem chunks_back {s : Slice U8} {p : Slice (Std.Array U8 16#usize) × Slice U8}
    {back : Slice (Std.Array U8 16#usize) × Slice U8 → Slice U8}
    (hl : p.1.length = s.length / 16)
    (hb : ∀ i (h : i < p.1.val.length), (p.1.val[i]).val = (s.val.drop (i * 16)).take 16)
    (hr : p.2.val = s.val.drop (s.length / 16 * 16))
    (hback : ∀ c t, (c.val.flatMap (·.val) ++ t.val).length ≤ Usize.max →
      (back (c, t)).val = c.val.flatMap (·.val) ++ t.val) :
    p.1.val.flatMap (·.val) = s.val.take (s.length / 16 * 16) ∧ back (p.1, p.2) = s := by
  have hf := flatMap_chunks s.val p.1.val hl hb
  refine ⟨hf, Slice.ext _ _ ?_⟩
  rw [hback _ _ (by rw [hf, hr, List.take_append_drop]; exact Slice.length_ineq s), hf, hr,
    List.take_append_drop]

/-- `as_chunks_mut::<16>` of a byte slice: its whole blocks, which flatten to
its leading bytes, the rest, and a write-back that rebuilds it. -/
theorem as_chunks16 (s : Slice U8) : ∃ blocks rest back,
    core.slice.Slice.as_chunks_mut 16#usize s = ok ((blocks, rest), back) ∧
    blocks.val.length = s.val.length / 16 ∧
    blocks.val.flatMap (·.val) = s.val.take (s.val.length / 16 * 16) ∧
    rest.val.length = s.val.length % 16 ∧ back (blocks, rest) = s ∧
    ∀ c t, (c.val.flatMap (·.val) ++ t.val).length ≤ Usize.max →
      (back (c, t)).val = c.val.flatMap (·.val) ++ t.val := by
  have hs := as_chunks_mut_spec (T := U8) 16#usize (by decide) s
  cases hres : core.slice.Slice.as_chunks_mut 16#usize s with
  | ok x =>
    rw [hres, WP.spec_ok] at hs
    obtain ⟨⟨blocks, rest⟩, back⟩ := x
    obtain ⟨hl, hb, hr, hback⟩ := hs
    simp only [show ((16#usize : Usize) : Nat) = 16 from rfl] at hl hb hr
    obtain ⟨hf, hid⟩ := chunks_back hl hb hr hback
    refine ⟨blocks, rest, back, rfl, hl, hf, ?_, hid, hback⟩
    rw [hr, List.length_drop]
    omega
  | fail e => rw [hres] at hs; simp at hs
  | div => rw [hres] at hs; simp at hs

/-- CBC encryption of whole blocks: refused unless the buffer is whole
blocks, and otherwise SP 800-38A's CBC encryption of it. -/
theorem aes_cbc_encrypt_blocks_spec (h : RunsAesHw) (alg : Algorithm) (key : List (BitVec 8))
    (k : mid.aes_cbc.AesCbcEncryptingKey) (hk : ModeKeyIs alg key k.key) (iv : mid.aes_cbc.CbcIv)
    (in_out : Slice U8) :
    k.encrypt_blocks iv in_out ⦃ r =>
      if in_out.length % 16 = 0 then
        r.1 = .Ok () ∧ bvs r.2.val = cbcEncrypt alg key (bvs iv.val) (bvs in_out.val)
      else r = (.Err .WrongLength, in_out) ⦄ := by
  obtain ⟨e, he⟩ := h.1
  have hmax := Slice.length_ineq in_out
  obtain ⟨blocks, rest, back, heq, hl, hf, hrl, hid, hback⟩ := as_chunks16 in_out
  unfold mid.aes_cbc.AesCbcEncryptingKey.encrypt_blocks mid.aes_cbc.AesCbcEncryptingKey.encrypt_in_place
  simp only [he, heq, bind_ok, low.ct.secret_slice, low.ct.public_slice, core.slice.Slice.is_empty,
    Slice.length, hrl]
  simp only [Slice.length] at hmax ⊢
  by_cases h16 : in_out.val.length % 16 = 0
  · simp only [h16, decide_true, ite_true]
    apply WP.spec_bind (aes_cbc_encrypt_spec alg key k.key hk iv blocks (by simp only [Slice.length]; omega))
    rintro blocks1 ⟨hl1, henc⟩
    refine (WP.spec_ok _).2 ⟨rfl, ?_⟩
    have hrn : rest.val = [] := List.length_eq_zero_iff.mp (by omega)
    simp only [Slice.length] at hl1
    rw [hback _ _ (by rw [List.length_append, length_flatMap16, hrn]; simp; omega), hrn, List.append_nil,
      henc, hf, List.take_of_length_le (by omega)]
  · simp only [h16, decide_false, Bool.false_eq_true, ite_false, WP.spec_ok, hid]

/-- CBC decryption of whole blocks: refused unless the buffer is whole
blocks, and otherwise SP 800-38A's CBC decryption of it. -/
theorem aes_cbc_decrypt_blocks_spec (h : RunsAesHw) (alg : Algorithm) (key : List (BitVec 8))
    (k : mid.aes_cbc.AesCbcDecryptingKey) (hk : ModeDecKeyIs alg key k.key) (iv : Std.Array U8 16#usize)
    (in_out : Slice U8) :
    k.decrypt_blocks iv in_out ⦃ r =>
      if in_out.length % 16 = 0 then
        r.1 = .Ok () ∧ bvs r.2.val = cbcDecrypt alg key (bvs iv.val) (bvs in_out.val)
      else r = (.Err .DecryptFailed, in_out) ⦄ := by
  obtain ⟨e, he⟩ := h.1
  have hmax := Slice.length_ineq in_out
  obtain ⟨blocks, rest, back, heq, hl, hf, hrl, hid, hback⟩ := as_chunks16 in_out
  unfold mid.aes_cbc.AesCbcDecryptingKey.decrypt_blocks
  simp only [he, heq, bind_ok, low.ct.public_slice, core.slice.Slice.is_empty, Slice.length, hrl]
  simp only [Slice.length] at hmax ⊢
  by_cases h16 : in_out.val.length % 16 = 0
  · simp only [decide_eq_true h16, ↓reduceIte, ite_eq_left h16]
    apply WP.spec_bind (aes_cbc_decrypt_spec alg key k.key hk iv blocks (by simp only [Slice.length]; omega))
    rintro blocks1 ⟨hl1, hdec⟩
    refine (WP.spec_ok _).2 ⟨rfl, ?_⟩
    have hrn : rest.val = [] := List.length_eq_zero_iff.mp (by omega)
    simp only [Slice.length] at hl1
    rw [hback _ _ (by rw [List.length_append, length_flatMap16, hrn]; simp; omega), hrn, List.append_nil,
      hdec, hf, List.take_of_length_le (by omega)]
  · simp only [decide_eq_false h16, Bool.false_eq_true, ↓reduceIte, ite_eq_right h16, WP.spec_ok, hid]

/-! ## The PKCS#7 check -/

theorem setSlice!_zero {α : Type _} (s s' : List α) (h : s'.length ≤ s.length) :
    s.setSlice! 0 s' = s' ++ s.drop s'.length := by
  simp only [List.setSlice!, List.take_zero, List.nil_append, Nat.sub_zero, Nat.min_eq_left h,
    List.take_length, Nat.zero_add]

/-- PKCS#7 unpadding of bytes ending in a 16-byte block reads only that block. -/
theorem pkcs7Unpad_last (pre l : List (BitVec 8)) (h16 : l.length = 16) :
    pkcs7Unpad (pre ++ l) =
      if 1 ≤ l[15]!.toNat ∧ l[15]!.toNat ≤ 16 ∧ ∀ i < 16, i < l[15]!.toNat → l[15 - i]! = l[15]! then
        some ((pre ++ l).take (pre.length + 16 - l[15]!.toNat))
      else none := by
  have hlast : (pre ++ l).getLast? = some l[15]! := by
    rw [List.getLast?_eq_getElem?, List.length_append, h16, List.getElem?_append_right (by omega),
      show pre.length + 16 - 1 - pre.length = 15 by omega, getElem!_pos l 15 (by omega),
      List.getElem?_eq_getElem]
  simp only [pkcs7Unpad, hlast, List.length_append, h16]
  generalize l[15]!.toNat = n
  by_cases hc : 1 ≤ n ∧ n ≤ 16 ∧ ∀ i < 16, i < n → l[15 - i]! = l[15]!
  · rw [if_pos hc, if_pos]
    refine ⟨hc.1, hc.2.1, by omega, ?_⟩
    intro b hb
    obtain ⟨j, hj, rfl⟩ := List.getElem_of_mem hb
    have hjn : j < n := by simp only [List.length_drop, List.length_append, h16] at hj; omega
    rw [List.getElem_drop, List.getElem_append_right (by omega)]
    have := hc.2.2 (n - 1 - j) (by omega) (by omega)
    rw [getElem!_pos l _ (by omega)] at this
    have e : pre.length + 16 - n + j - pre.length = 15 - (n - 1 - j) := by omega
    simp only [e]
    exact this
  · rw [if_neg hc, if_neg]
    rintro ⟨h1, h2, -, hall⟩
    apply hc
    refine ⟨h1, h2, fun i hi hin => ?_⟩
    apply hall
    rw [getElem!_pos l _ (by omega)]
    apply List.mem_iff_getElem.2
    refine ⟨n - 1 - i, by simp only [List.length_drop, List.length_append, h16]; omega, ?_⟩
    rw [List.getElem_drop, List.getElem_append_right (by omega)]
    have e : pre.length + 16 - n + (n - 1 - i) - pre.length = 15 - i := by omega
    simp only [e]

theorem bvs_getElem! (l : List U8) {j : Nat} (hj : j < l.length) : (bvs l)[j]! = (l[j]!).bv := by
  rw [getElem!_pos _ j (by rw [List.length_map]; exact hj), getElem!_pos l j hj, List.getElem_map]

/-- `pkcs7Unpad_last` on a block of `U8`s. -/
theorem pkcs7Unpad_block (pre : List (BitVec 8)) (last : Std.Array U8 16#usize) :
    pkcs7Unpad (pre ++ bvs last.val) =
      if 1 ≤ last.val[15]!.val ∧ last.val[15]!.val ≤ 16 ∧
          ∀ i < 16, i < last.val[15]!.val → last.val[15 - i]! = last.val[15]! then
        some ((pre ++ bvs last.val).take (pre.length + 16 - last.val[15]!.val))
      else none := by
  have hl : last.val.length = 16 := last.property
  have hn : (bvs last.val)[15]!.toNat = last.val[15]!.val :=
    congrArg BitVec.toNat (bvs_getElem! _ (show 15 < last.val.length by omega))
  have hc : (∀ i < 16, i < last.val[15]!.val → (bvs last.val)[15 - i]! = (bvs last.val)[15]!) ↔
      (∀ i < 16, i < last.val[15]!.val → last.val[15 - i]! = last.val[15]!) := by
    refine forall_congr' fun i => imp_congr_right fun hi => imp_congr_right fun _ => ?_
    rw [bvs_getElem! _ (by omega), bvs_getElem! _ (by omega), U8.eq_equiv_bv_eq]
  rw [pkcs7Unpad_last pre (bvs last.val) (by rw [List.length_map, hl]), hn]
  simp only [hc]

theorem mask_bv (m : U8) (c : Bool) (h : m.val = if c then 255 else 0) :
    m.bv = if c then BitVec.allOnes 8 else 0#8 := by
  apply BitVec.eq_of_toNat_eq
  rw [show m.bv.toNat = m.val from rfl, h]
  cases c <;> decide

theorem or_masks_eq_zero (m1 m2 : U8) (c1 c2 : Bool) (h1 : m1.val = if c1 then 255 else 0)
    (h2 : m2.val = if c2 then 255 else 0) : (m1 ||| m2) = 0#u8 ↔ c1 = false ∧ c2 = false := by
  rw [U8.eq_equiv_bv_eq, UScalar.bv_or, mask_bv m1 c1 h1, mask_bv m2 c2 h2]
  cases c1 <;> cases c2 <;> decide

theorem mask_or_eq_zero (bad m x p : U8) (c : Bool) (hm : m.val = if c then 255 else 0) :
    (bad ||| (m &&& (x ^^^ p))) = 0#u8 ↔ bad = 0#u8 ∧ (c = true → x = p) := by
  rw [U8.eq_equiv_bv_eq, U8.eq_equiv_bv_eq bad, U8.eq_equiv_bv_eq x, UScalar.bv_or, UScalar.bv_and,
    UScalar.bv_xor, mask_bv m c hm, show (0#u8 : U8).bv = 0#8 from rfl, BitVec.or_eq_zero_iff]
  cases c <;> simp [BitVec.xor_eq_zero_iff]

/-- `ct_mask_lt` is all ones when `a < b` and zero otherwise. -/
theorem ct_mask_lt_spec (a b : U8) :
    mid.aes_cbc.ct_mask_lt a b ⦃ m => m.val = if a.val < b.val then 255 else 0 ⦄ := by
  unfold mid.aes_cbc.ct_mask_lt
  simp only [lift, bind_ok]
  apply WP.spec_bind (U32.ShiftRight_IScalar_spec _ 8#i32 (by decide) (by decide))
  rintro z ⟨hz, -⟩
  refine (WP.spec_ok _).2 ?_
  have ha : a.val < 256 := by scalar_tac
  have hb : b.val < 256 := by scalar_tac
  have h8 : (8#i32 : I32).toNat = 8 := by decide
  rw [UScalar.cast_val_eq, hz, core.num.U32.wrapping_sub_val_eq, core.convert.num.FromU32U8.from_val_eq,
    core.convert.num.FromU32U8.from_val_eq, h8, Nat.shiftRight_eq_div_pow]
  simp only [UScalar.size, UScalarTy.numBits, Nat.reducePow]
  split <;> omega

/-- The padding check's loop leaves `bad` zero exactly when it was and each
of the last `pad` bytes, up to 16, is `pad`. -/
theorem decrypt_loop_spec (last : Std.Array U8 16#usize) (pad bad : U8) :
    mid.aes_cbc.AesCbcDecryptingKey.decrypt_loop { start := 0#usize, «end» := 16#usize } last pad bad
      ⦃ r => (r = 0#u8 ↔ bad = 0#u8 ∧ ∀ i < 16, i < pad.val → last.val[15 - i]! = pad) ⦄ := by
  have hl16 : last.val.length = 16 := last.property
  have h15 : (15#usize : Usize).val = 15 := rfl
  unfold mid.aes_cbc.AesCbcDecryptingKey.decrypt_loop
  apply loop.spec_decr_nat (fun x => 16 - x.1.start.val)
    (fun x => x.1.«end» = 16#usize ∧ x.1.start.val ≤ 16 ∧
      (x.2 = 0#u8 ↔ bad = 0#u8 ∧ ∀ i < x.1.start.val, i < pad.val → last.val[15 - i]! = pad))
  · rintro ⟨it, b⟩ ⟨hend, hle, hinv⟩
    simp only at hend hle hinv ⊢
    unfold mid.aes_cbc.AesCbcDecryptingKey.decrypt_loop.body
    have hE : it.«end».val = 16 := by rw [hend]; all_goals rfl
    step as ⟨o, iter1, ho, hend1⟩
    by_cases hlt : it.start.val < it.«end».val
    · simp only [hlt, ↓reduceIte] at ho
      obtain ⟨rfl, hst⟩ := ho
      simp only [lift, bind_ok]
      have hc : (UScalar.cast .U8 it.start).val = it.start.val := by
        rw [UScalar.cast_val_eq]; exact Nat.mod_eq_of_lt (by simp only [UScalarTy.numBits]; omega)
      apply WP.spec_bind (ct_mask_lt_spec _ pad)
      intro m hm
      rw [hc] at hm
      apply WP.spec_bind (Usize.sub_spec (x := 15#usize) (y := it.start) (by rw [h15]; omega))
      rintro i3 ⟨hi3, -⟩
      have hb3 : i3.val < last.val.length := by rw [hl16, hi3, h15]; omega
      apply WP.spec_bind (Array.index_usize_spec last i3 hb3)
      rintro i4 rfl
      have hx : last.val[i3.val] = last.val[15 - it.start.val]! := by
        rw [getElem!_pos last.val (15 - it.start.val) (by omega)]
        simp only [hi3, h15]
      refine (WP.spec_ok _).2 ⟨⟨by rw [hend1, hend], by omega, ?_⟩, by omega⟩
      rw [mask_or_eq_zero b m _ pad (decide (it.start.val < pad.val)) (by simpa using hm), hinv, hst, hx]
      constructor
      · rintro ⟨⟨hb, hall⟩, hs⟩
        refine ⟨hb, fun i hi hp => ?_⟩
        by_cases hi' : i < it.start.val
        · exact hall i hi' hp
        · have : i = it.start.val := by omega
          subst this
          exact hs (by simpa using hp)
      · rintro ⟨hb, hall⟩
        exact ⟨⟨hb, fun i hi hp => hall i (by omega) hp⟩,
          fun hp => hall _ (by omega) (by simpa using hp)⟩
    · simp only [hlt, ↓reduceIte] at ho
      obtain ⟨rfl, hst⟩ := ho
      simp only [WP.spec_ok]
      have : it.start.val = 16 := by omega
      rw [hinv, this]
  · exact ⟨rfl, by decide, by simp⟩

/-- CBC decryption with PKCS#7 padding. A buffer of whole blocks, at least
one, decrypts; if its padding is good, the result is the message, and the
buffer holds the decryption with the message part written back; if not,
decryption fails and the buffer is zeroed. Any other buffer fails unchanged. -/
theorem aes_cbc_decrypting_key_decrypt_spec (h : RunsAesHw) (alg : Algorithm) (key : List (BitVec 8))
    (k : mid.aes_cbc.AesCbcDecryptingKey) (hk : ModeDecKeyIs alg key k.key) (iv : Std.Array U8 16#usize)
    (in_out : Slice U8) :
    k.decrypt iv in_out ⦃ r back =>
      if in_out.length % 16 = 0 ∧ in_out.length ≠ 0 then
        (∀ m, pkcs7Unpad (cbcDecrypt alg key (bvs iv.val) (bvs in_out.val)) = some m →
          ∃ s, r = .Ok s ∧ bvs s.val = m ∧ ∀ s' : Slice U8, s'.length = s.length →
            bvs (back (.Ok s')).val = bvs s'.val ++
              (cbcDecrypt alg key (bvs iv.val) (bvs in_out.val)).drop m.length) ∧
        (pkcs7Unpad (cbcDecrypt alg key (bvs iv.val) (bvs in_out.val)) = none →
          r = .Err .DecryptFailed ∧ ∀ r', (back r').val = List.replicate in_out.length 0#u8)
      else r = .Err .DecryptFailed ∧ ∀ r', back r' = in_out ⦄ := by
  obtain ⟨e, he⟩ := h.1
  have hmax := Slice.length_ineq in_out
  obtain ⟨blocks, rest, back, heq, hl, hf, hrl, hid, hback⟩ := as_chunks16 in_out
  unfold mid.aes_cbc.AesCbcDecryptingKey.decrypt
  simp only [he, heq, bind_ok, core.slice.Slice.is_empty, Slice.length, hrl, hl]
  simp only [Slice.length] at hmax ⊢
  by_cases h16 : in_out.val.length % 16 = 0
  swap
  · simp only [decide_eq_false h16, Bool.false_eq_true, ↓reduceIte, WP.spec_ok, WP.uncurry'_pair]
    rw [if_neg (show ¬ (in_out.val.length % 16 = 0 ∧ in_out.val.length ≠ 0) from fun hc => h16 hc.1)]
    exact ⟨rfl, fun _ => hid⟩
  simp only [decide_eq_true h16, ↓reduceIte]
  by_cases h0 : in_out.val.length = 0
  · simp only [decide_eq_true (show in_out.val.length / 16 = 0 by omega), ↓reduceIte, WP.spec_ok,
      WP.uncurry'_pair]
    rw [if_neg (show ¬ (in_out.val.length % 16 = 0 ∧ in_out.val.length ≠ 0) from fun hc => hc.2 h0)]
    exact ⟨rfl, fun _ => hid⟩
  simp only [decide_eq_false (show ¬ in_out.val.length / 16 = 0 by omega), Bool.false_eq_true, ↓reduceIte]
  apply WP.spec_bind (aes_cbc_decrypt_spec alg key k.key hk iv blocks (by simp only [Slice.length]; omega))
  rintro blocks1 ⟨hl1, hdec⟩
  simp only [Slice.length] at hl1
  rw [hf, List.take_of_length_le (by omega)] at hdec
  have hrn : rest.val = [] := List.length_eq_zero_iff.mp (by omega)
  have hout := hback blocks1 rest (by rw [List.length_append, length_flatMap16, hrn]; simp; omega)
  rw [hrn, List.append_nil] at hout
  generalize cbcDecrypt alg key (bvs iv.val) (bvs in_out.val) = D at hdec ⊢
  have hbo : bvs (back (blocks1, rest)).val = D := by rw [hout, hdec]
  rcases List.eq_nil_or_concat blocks1.val with hn | ⟨pre, last, hsplit⟩
  · exfalso; have := congrArg List.length hn; simp only [List.length_nil] at this; omega
  rw [List.concat_eq_append] at hsplit
  have hD : D = bvs (pre.flatMap (·.val)) ++ bvs last.val := by
    rw [← hdec, hsplit]
    simp only [bvs, List.flatMap_append, List.flatMap_singleton, List.map_append]
  have hol : (back (blocks1, rest)).val.length = 16 * pre.length + 16 := by
    rw [hout, length_flatMap16, hsplit, List.length_append, List.length_singleton]; ring
  have hlast16 : last.val.length = 16 := last.property
  simp only [core.slice.Slice.last, hsplit, List.getLast?_concat, bind_ok, core.option.Option.unwrap,
    Result.ofOption]
  apply WP.spec_bind (Array.index_usize_spec last 15#usize (by show (15#usize : Usize).val < last.val.length; rw [hlast16]; decide))
  rintro pad hpad
  have hpad' : pad = last.val[15]! := by
    rw [hpad, getElem!_pos last.val 15 (by rw [hlast16]; omega)]; all_goals rfl
  subst hpad'
  simp only [core.hint.black_box, bind_ok]
  apply WP.spec_bind (ct_mask_lt_spec _ _)
  intro m1 hm1
  apply WP.spec_bind (ct_mask_lt_spec _ _)
  intro m2 hm2
  simp only [lift, bind_ok]
  apply WP.spec_bind (decrypt_loop_spec last _ _)
  intro bad1 hbad1
  simp only [core.hint.black_box, low.ct.into_public, bind_ok]
  rw [show (16#u8 : U8).val = 16 from rfl] at hm1
  rw [show (1#u8 : U8).val = 1 from rfl] at hm2
  have hbad0 : (m1 ||| m2) = 0#u8 ↔ ¬ 16 < last.val[15]!.val ∧ ¬ last.val[15]!.val < 1 := by
    rw [or_masks_eq_zero m1 m2 (decide (16 < last.val[15]!.val)) (decide (last.val[15]!.val < 1))
      (by simpa using hm1) (by simpa using hm2)]
    simp
  have hok : bad1 = 0#u8 ↔ 1 ≤ last.val[15]!.val ∧ last.val[15]!.val ≤ 16 ∧
      ∀ i < 16, i < last.val[15]!.val → last.val[15 - i]! = last.val[15]! := by
    rw [hbad1, hbad0]
    constructor
    · rintro ⟨⟨h1, h2⟩, h3⟩; exact ⟨by omega, by omega, h3⟩
    · rintro ⟨h1, h2, h3⟩; exact ⟨⟨by omega, by omega⟩, h3⟩
  have hPU := pkcs7Unpad_block (bvs (pre.flatMap (·.val))) last
  rw [← hD] at hPU
  have hcond : in_out.val.length % 16 = 0 ∧ in_out.val.length ≠ 0 := ⟨h16, h0⟩
  by_cases hb : bad1 = 0#u8
  · have hbne : (bad1 != 0#u8) = false := by simp [hb]
    have hp16 := (hok.1 hb).2.1
    rw [if_pos (hok.1 hb)] at hPU
    simp only [hbne, Bool.false_eq_true, ↓reduceIte, low.ct.into_public, low.ct.public_slice, bind_ok,
      lift, Slice.index_mut_SliceIndexRangeToUsizeSliceInst]
    apply WP.spec_bind (Usize.sub_spec (x := Slice.len (back (blocks1, rest)))
      (y := core.convert.num.FromUsizeU8.from last.val[15]!)
      (by rw [Slice.len_val, core.convert.num.FromUsizeU8.from_val_eq]; simp only [Slice.length, hol]; omega))
    rintro len ⟨hlen, -⟩
    have hlen' : len.val = 16 * pre.length + 16 - last.val[15]!.val := by
      rw [hlen, Slice.len_val, core.convert.num.FromUsizeU8.from_val_eq]; simp only [Slice.length, hol]
    apply WP.spec_bind (core.slice.index.SliceIndexRangeToUsizeSlice.index_mut.step_spec { «end» := len }
      (back (blocks1, rest)) (by show len.val ≤ _; simp only [Slice.length, hol]; omega))
    rintro ⟨s, imb⟩ ⟨hs, hsl, himb⟩
    refine (WP.spec_ok _).2 ?_
    simp only [WP.uncurry'_pair]
    rw [if_pos hcond]
    refine ⟨fun m hm => ?_, fun hn => by rw [hPU] at hn; simp at hn⟩
    rw [hPU] at hm
    obtain rfl := Option.some.inj hm
    simp only [Slice.length] at hsl
    refine ⟨s, rfl, ?_, fun s' hs' => ?_⟩
    · rw [hs, ← hbo]
      simp only [List.slice, List.drop_zero, Nat.sub_zero, bvs, List.map_take, hlen', List.length_map,
        length_flatMap16]
    · simp only [Slice.length] at hs'
      show bvs (imb s').val = _
      rw [himb, setSlice!_zero _ _ (by rw [hol, hs', hsl]; show len.val ≤ _; omega), ← hbo]
      simp only [bvs, List.map_append, List.map_drop, List.length_take, List.length_map,
        length_flatMap16]
      congr 2
      rw [hs', hsl, hol]
      show len.val = _
      omega
  · have hbne : (bad1 != 0#u8) = true := by simpa using hb
    rw [if_neg (fun hc => hb (hok.2 hc))] at hPU
    simp only [hbne, ↓reduceIte]
    apply WP.spec_bind (core.slice.Slice.fill.spec core.clone.CloneU8 (back (blocks1, rest)) 0#u8
      (by simp [WP.spec_ok]))
    rintro z ⟨-, hz⟩
    refine (WP.spec_ok _).2 ?_
    simp only [WP.uncurry'_pair]
    rw [if_pos hcond]
    refine ⟨fun m hm => by rw [hPU] at hm; simp at hm, fun _ => ⟨rfl, fun _ => ?_⟩⟩
    rw [hz]
    congr 1
    simp only [Slice.length, hol]
    rw [hsplit, List.length_append, List.length_singleton] at hl1
    omega

/-! ## CTR -/

/-- An AES-CTR key: the AES key's round keys, counting over the low `m` bits
of each counter block. -/
def AesCtrIs (alg : Algorithm) (key : List (BitVec 8)) (m : Nat) (c : mid.aes.AesCtr) : Prop :=
  ModeKeyIs alg key c.key ∧ c.counter_mask.val = 2 ^ m - 1

theorem shr_max (s : Nat) (hs : s ≤ 128) : (2 ^ 128 - 1) / 2 ^ s = 2 ^ (128 - s) - 1 := by
  have hp : 2 ^ (128 - s) * 2 ^ s = 2 ^ 128 := by rw [← pow_add]; congr 1; omega
  have h1 : 1 ≤ 2 ^ s := Nat.one_le_two_pow
  have h2 : 1 ≤ 2 ^ (128 - s) := Nat.one_le_two_pow
  apply Nat.div_eq_of_lt_le
  · rw [Nat.sub_mul, hp]; omega
  · rw [Nat.sub_add_cancel h2, hp]; omega

theorem contains_u8 (lo hi x : U8) :
    core.ops.range.RangeInclusive.contains core.cmp.PartialOrdU8 core.cmp.PartialOrdU8
      core.cmp.PartialOrdU8 ⟨lo, hi, false⟩ x = ok (decide (lo.val ≤ x.val ∧ x.val ≤ hi.val)) := by
  by_cases h1 : lo.val ≤ x.val <;>
    simp [core.ops.range.RangeInclusive.contains, core.cmp.impls.PartialOrdU8.le, h1]

/-- An AES-CTR key is refused unless it is the algorithm's length and its
counter 1 to 128 bits, and otherwise holds the key's round keys and counts
over that many low bits. -/
theorem aes_ctr_new_spec (h : RunsAesHw) (alg : Algorithm) (algorithm : cipher.Algorithm)
    (hlen : algorithm.key_len.val = 4 * nk alg) (key : Slice U8) (counter_bits : U8) :
    mid.aes.AesCtr.new algorithm key counter_bits ⦃ r =>
      if key.length = 4 * nk alg ∧ 1 ≤ counter_bits.val ∧ counter_bits.val ≤ 128 then
        ∃ c, r = .Ok c ∧ AesCtrIs alg (bvs key.val) counter_bits.val c
      else r = .Err .WrongLength ⦄ := by
  obtain ⟨e, he⟩ := h.1
  unfold mid.aes.AesCtr.new
  rw [he, bind_ok]
  by_cases hk : key.length = 4 * nk alg
  · have hne : ¬ (Slice.len key != algorithm.key_len) = true := by
      simp only [bne_iff_ne, ne_eq, not_not]; scalar_tac
    simp only [hne, Bool.false_eq_true, ↓reduceIte, core.ops.range.RangeInclusive.new, bind_ok,
      contains_u8]
    by_cases hc : 1 ≤ counter_bits.val ∧ counter_bits.val ≤ 128
    · have hc' : (1#u8 : U8).val ≤ counter_bits.val ∧ counter_bits.val ≤ (128#u8 : U8).val := hc
      simp only [decide_eq_true hc', ↓reduceIte, ite_eq_left (show key.length = 4 * nk alg ∧ 1 ≤ counter_bits.val ∧
        counter_bits.val ≤ 128 from ⟨hk, hc⟩)]
      apply WP.spec_bind (expand_key_mode_spec h alg key hk)
      intro ak hak
      apply WP.spec_bind (U8.sub_spec (x := 128#u8) (y := counter_bits) (by scalar_tac))
      rintro i1 ⟨hi1, -⟩
      apply WP.spec_bind (U128.ShiftRight_spec core.num.U128.MAX i1 (by scalar_tac))
      rintro i2 ⟨hi2, -⟩
      refine (WP.spec_ok _).2 ⟨_, rfl, hak, ?_⟩
      have hmax : (core.num.U128.MAX).val = 2 ^ 128 - 1 := by decide
      have hi1' : i1.val = 128 - counter_bits.val := by rw [hi1]; all_goals rfl
      show i2.val = _
      rw [hi2, hmax, hi1', Nat.shiftRight_eq_div_pow, shr_max _ (by omega)]
      congr 2; omega
    · have hc' : ¬ ((1#u8 : U8).val ≤ counter_bits.val ∧ counter_bits.val ≤ (128#u8 : U8).val) := hc
      simp only [decide_eq_false hc', Bool.false_eq_true, ↓reduceIte, WP.spec_ok]
      rw [if_neg (fun h' => hc h'.2)]
  · have hne : (Slice.len key != algorithm.key_len) = true := by
      simp only [bne_iff_ne, ne_eq]; intro he; apply hk; rw [← hlen, ← he]; simp
    simp only [hne, ↓reduceIte, WP.spec_ok]
    rw [if_neg (fun h' => hk h'.1)]

end rind.x86_64
