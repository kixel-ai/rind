import Rind.X86_64.Hkdf
import Rind.X86_64.AesGcmAead
open Aeneas Aeneas.Std Result rind.vale rind.spec

/-!
# `aead::Key`'s conversion from `Okm`, for AES-GCM

`From<Okm<&'static aead::Algorithm>> for aead::Key` fills the algorithm's key
length of HKDF-Expand into a buffer, then keys AES-GCM with it through
`Key::new`. This file composes that with `AesGcm`'s `aes_gcm_new`, so the key
holds AES-GCM for the HKDF bytes. It lives apart from `Hkdf`
because AES-GCM's proofs are x86_64's, and so `admin/prove` writes no aarch64
copy of it.
-/

namespace rind.x86_64.kdf

/-- `Key::new` of the AES-GCM algorithm `alg` names, for key bytes of its length,
through the translation's wrapper: the key holds AES-GCM for the
bytes, as `aes_gcm_new` states, and the wrapper refuses only what `new` does. -/
theorem aead_key_new_spec (h : RunsAesGcm) (alg : Algorithm) (algorithm : aead.Algorithm)
    (halg : (algorithm = aead.AES_128_GCM ∧ alg = .AES_128) ∨
      (algorithm = aead.AES_256_GCM ∧ alg = .AES_256))
    (key : Slice U8) (hk : key.length = 4 * nk alg) :
    aead.Key.new algorithm key ⦃ r => ∃ k, r = .Ok k ∧ KeyReady alg (bv key.val) k ⦄ := by
  unfold aead.Key.new
  apply WP.spec_bind (rind.x86_64.aes_gcm_new h alg algorithm halg key)
  intro r hr
  rw [if_pos hk] at hr
  obtain ⟨k, rfl, hk'⟩ := hr
  exact (WP.spec_ok _).mpr ⟨k, rfl, hk'⟩

/-- `aead::Key`'s conversion from `Okm` holds AES-GCM for the `4 * nk` bytes
of HKDF-Expand, for AES-128-GCM and AES-256-GCM. -/
theorem aead_key_from_spec (h : RunsAesGcm) (a : high.hmac.Algorithm) (hr : RunsHmac a)
    (prk : List Byte) (k : high.hmac.Key) (hk : KeyOf a prk k) (info : Slice (Slice U8))
    (hinfo : hmacBlock a + tagLen a + (infoBytes info).length + 1 ≤ maxInput)
    (alg : Algorithm) (algorithm : aead.Algorithm)
    (halg : (algorithm = aead.AES_128_GCM ∧ alg = .AES_128) ∨
      (algorithm = aead.AES_256_GCM ∧ alg = .AES_256)) :
    aead.Key.Insts.CoreConvertFromOkm0SharedStaticAlgorithm.from
      { prk := k, info := info, len := algorithm } ⦃ key =>
      KeyReady alg (hkdfExpand (hmacOf a) (tagLen a) prk (bv (infoBytes info)) (4 * nk alg)) key ⦄ := by
  have hkl : (rind.x86_64.aead.Algorithm.key_len algorithm).val = 4 * nk alg := by
    rcases halg with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;> rfl
  have hnk : nk alg ≤ 8 := by cases alg <;> decide
  have hpos := tagLen_pos a
  unfold aead.Key.Insts.CoreConvertFromOkm0SharedStaticAlgorithm.from
  unfold aead.Algorithm.key_len
  simp only [bind_ok]
  apply WP.spec_bind (Array.index_mut_SliceIndexRangeToUsizeSlice (Array.repeat 64#usize 0#u8)
    { «end» := rind.x86_64.aead.Algorithm.key_len algorithm } (by scalar_tac))
  rintro ⟨bytes, back⟩ ⟨hb1, hb2, -⟩
  have hblen : bytes.length = 4 * nk alg := by rw [hb2]; exact hkl
  apply WP.spec_bind (expand_into_spec a hr prk k hk info hinfo bytes (by rw [hblen]; omega))
  rintro bytes1 ⟨hl1, hl2⟩
  have hbv : bv bytes1.val = hkdfExpand (hmacOf a) (tagLen a) prk (bv (infoBytes info)) (4 * nk alg) := by
    rw [hl2, hblen]
  apply WP.spec_bind (aead_key_new_spec h alg algorithm halg bytes1 (by rw [hl1, hblen]))
  rintro r ⟨k', rfl, hk'⟩
  unfold core.result.Result.expect
  rw [hbv] at hk'
  exact (WP.spec_ok _).mpr hk'

end rind.x86_64.kdf
