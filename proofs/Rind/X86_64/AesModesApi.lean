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

end rind.x86_64
