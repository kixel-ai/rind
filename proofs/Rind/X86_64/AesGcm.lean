import Rind.X86_64.AesGcmGlue
import Rind.X86_64.AesKey
import Rind.X86_64.Ghash
import Rind.X86_64.AeadDispatch
open Aeneas Aeneas.Std Result rind.vale

namespace rind.x86_64

@[step]
theorem aes128_expand_step (key : Std.Array U8 16#usize) (out : Std.Array core.core_arch.x86.__m128i 11#usize) :
    low.x86_64.aes.aes128_expand key out ⦃ rk =>
      rk.val = keyToRoundKeys .AES_128 (seqNat8ToSeqNat32LE (bvs key.val)) ⦄ := by
  obtain ⟨rk, h, hv⟩ := aes128_expand_spec key out
  rw [h, WP.spec_ok]; exact hv

@[step]
theorem aes256_expand_step (key : Std.Array U8 32#usize) (out : Std.Array core.core_arch.x86.__m128i 15#usize) :
    low.x86_64.aes.aes256_expand key out ⦃ rk =>
      rk.val = keyToRoundKeys .AES_256 (seqNat8ToSeqNat32LE (bvs key.val)) ⦄ := by
  obtain ⟨rk, h, hv⟩ := aes256_expand_spec key out
  rw [h, WP.spec_ok]; exact hv

/-- rind runs Vale's AES-GCM on this CPU: its entry guard passes, and its
CPU-feature checks find AES-NI, PCLMULQDQ, AVX, and MOVBE, but neither tier
with VAES. None reads an input. -/
def RunsValeAesGcm : Prop :=
  (∃ e, low.entry.Entry.new_secret = ok e) ∧
  (∃ hw, low.x86_64.cpu.HaveAesHardware.check = ok (some hw)) ∧
  (∃ s, low.x86_64.cpu.HaveSsse3.check = ok s) ∧
  low.x86_64.cpu.HaveAvx512ForAesGcm.check = ok none ∧
  low.x86_64.cpu.HaveVaesAvx2ForAesGcm.check = ok none ∧
  (∃ t, low.x86_64.cpu.HaveAvxMovbeForAesGcm.check = ok (some t))

theorem expand_key128_spec (h : RunsValeAesGcm) (key : Slice U8) (hk : key.length = 16) :
    mid.aes.expand_key key ⦃ k => ∃ k128, k = .Hw (.Aes128 k128) ∧
      k128.round_keys.val = keyToRoundKeys .AES_128 (seqNat8ToSeqNat32LE (bvs key.val)) ⦄ := by
  obtain ⟨-, ⟨hw, hhw⟩, ⟨ss, hss⟩, -⟩ := h
  unfold mid.aes.expand_key low.x86_64.aes.AesKey.new low.x86_64.aes.AesKey128.new
  step*
  have hl : copy_key1.len.val = 16 := by rw [Slice.len_val, copy_key1_post]; exact hk
  have hl' : copy_key1.len = 16#usize := by scalar_tac
  simp only [low.ct.secret_slice, hhw, hss, bind_ok, core.array.TryFromSharedArraySlice.try_from,
    hl', ↓reduceDIte, core.result.Result.unwrap, low.x86_64.aes.zero,
    core.core_arch.x86.sse2._mm_setzero_si128]
  apply WP.spec_bind (aes128_expand_step _ _)
  intro rk hrk
  rw [WP.spec_ok]
  refine ⟨_, rfl, ?_⟩
  rw [hrk, Std.Array.from_val, copy_key1_post]

theorem expand_key256_spec (h : RunsValeAesGcm) (key : Slice U8) (hk : key.length = 32) :
    mid.aes.expand_key key ⦃ k => ∃ k256, k = .Hw (.Aes256 k256) ∧
      k256.round_keys.val = keyToRoundKeys .AES_256 (seqNat8ToSeqNat32LE (bvs key.val)) ⦄ := by
  obtain ⟨-, ⟨hw, hhw⟩, ⟨ss, hss⟩, -⟩ := h
  unfold mid.aes.expand_key low.x86_64.aes.AesKey.new low.x86_64.aes.AesKey256.new
  step*
  have hl : copy_key1.len.val = 32 := by rw [Slice.len_val, copy_key1_post]; exact hk
  have hl' : copy_key1.len = 32#usize := by scalar_tac
  simp only [low.ct.secret_slice, hhw, hss, bind_ok, core.array.TryFromSharedArraySlice.try_from,
    hl', ↓reduceDIte, core.result.Result.unwrap, low.x86_64.aes.zero,
    core.core_arch.x86.sse2._mm_setzero_si128]
  apply WP.spec_bind (aes256_expand_step _ _)
  intro rk hrk
  rw [WP.spec_ok]
  refine ⟨_, rfl, ?_⟩
  rw [hrk, Std.Array.from_val, copy_key1_post]

/-- The AES-NI key holds Vale's round keys of the AES key `kw` for `alg`. -/
def HwKeyIs (alg : Algorithm) (kw : List (BitVec 32)) : low.x86_64.aes.HwKey → Prop
  | .Aes128 k => alg = .AES_128 ∧ k.round_keys.val = keyToRoundKeys .AES_128 kw
  | .Aes192 _ => False
  | .Aes256 k => alg = .AES_256 ∧ k.round_keys.val = keyToRoundKeys .AES_256 kw

/-- An AES-GCM key on Vale's tier, for the AES key `kw` and `alg`. -/
def Ready (alg : Algorithm) (kw : List (BitVec 32)) (g : mid.aes_gcm.AesGcm) : Prop :=
  ∃ hk table kernel, g.key = .Hw hk ∧ g.gh = .Avx table kernel ∧ KernelKeys alg hk kw kernel

/-- The key length `alg` takes, which rind's AES supports. -/
def KeyLen (alg : Algorithm) (n : Nat) : Prop :=
  (alg = .AES_128 ∧ n = 16) ∨ (alg = .AES_256 ∧ n = 32)

theorem encrypt_zero (hk : low.x86_64.aes.HwKey) (alg : Algorithm) (kw : List (BitVec 32))
    (h : HwKeyIs alg kw hk) :
    low.x86_64.aes.AesKey.encrypt_block (.Hw hk) (Std.Array.repeat 16#usize 0#u8) =
      ok (low.x86_64.aes.store (aesEncrypt alg kw (mkfour 0 0 0 0))) := by
  cases hk with
  | Aes128 k =>
    obtain ⟨rfl, hrk⟩ := h
    simp only [low.x86_64.aes.AesKey.encrypt_block, low.x86_64.aes.HwKey.encrypt_block,
      low.x86_64.aes.AesKey128.encrypt_block, aes128_block_spec, load_zero, hrk, aesEncrypt]
  | Aes192 k => exact h.elim
  | Aes256 k =>
    obtain ⟨rfl, hrk⟩ := h
    simp only [low.x86_64.aes.AesKey.encrypt_block, low.x86_64.aes.HwKey.encrypt_block,
      low.x86_64.aes.AesKey256.encrypt_block, aes256_block_spec, load_zero, hrk, aesEncrypt]

/-- `AesGcm::new` sets up Vale's AES-GCM: FIPS 197's round keys and the GHASH
key powers `hkeys_reqs_pub` requires. -/
theorem aes_gcm_new_spec (h : RunsValeAesGcm) (alg : Algorithm) (key : Slice U8)
    (hk : KeyLen alg key.length) :
    mid.aes_gcm.AesGcm.new key ⦃ g => Ready alg (seqNat8ToSeqNat32LE (bvs key.val)) g ⦄ := by
  have h' := h
  obtain ⟨⟨e, he⟩, ⟨hw, hhw⟩, -, h512, hvaes, ⟨tok, htok⟩⟩ := h'
  set kw := seqNat8ToSeqNat32LE (bvs key.val)
  have hkey : mid.aes.expand_key key ⦃ k => ∃ hwk, k = .Hw hwk ∧ HwKeyIs alg kw hwk ⦄ := by
    rcases hk with ⟨rfl, hl⟩ | ⟨rfl, hl⟩
    · exact WP.spec_mono (expand_key128_spec h key hl) fun k ⟨k128, hk1, hk2⟩ => ⟨_, hk1, rfl, hk2⟩
    · exact WP.spec_mono (expand_key256_spec h key hl) fun k ⟨k256, hk1, hk2⟩ => ⟨_, hk1, rfl, hk2⟩
  unfold mid.aes_gcm.AesGcm.new
  rw [he, bind_ok]
  apply WP.spec_bind hkey
  rintro _ ⟨hwk, rfl, hwk_is⟩
  simp only [encrypt_zero hwk alg kw hwk_is, bind_ok, lift, low.x86_64.ghash.GhashTable.new, hhw, h512,
    hvaes, htok]
  obtain ⟨px, hpx⟩ := clmul_new_eq (core.num.U128.from_be_bytes
    (low.x86_64.aes.store (aesEncrypt alg kw (mkfour 0 0 0 0)))) hw
  simp only [hpx, bind_ok, kernel_new_eq, WP.spec_ok]
  refine ⟨hwk, _, _, rfl, rfl, ?_, hwk_is, ?_⟩
  · rcases hk with ⟨rfl, hl⟩ | ⟨rfl, hl⟩ <;> simp [kw, seqNat8ToSeqNat32LE_length, hl, nk]
  · simp only [Std.Array.make_val]
    have := valeHkeys_spec (core.num.U128.from_be_bytes
      (low.x86_64.aes.store (aesEncrypt alg kw (mkfour 0 0 0 0)))).bv
    rw [from_be_bytes_store] at this ⊢; assumption

@[step]
theorem public_slice_spec {T : Type} (s : Slice T) : low.ct.public_slice s ⦃ _ => True ⦄ := by
  simp [low.ct.public_slice, WP.spec_ok]

@[step]
theorem check_gcm_lengths_spec (aad msg : Usize) (haad : aad.val < 2 ^ 32) (hmsg : msg.val < 2 ^ 32) :
    mid.aes.check_gcm_lengths aad msg ⦃ r => r = .Ok () ⦄ := by
  unfold mid.aes.check_gcm_lengths mid.aes.check_counter core.num.Usize.div_ceil
  step*
  rw [dite_eq_right (by decide)]
  simp only [lift, bind_ok]
  step*

/-- `aes_gcm::seal` and `open` run Vale's routines for a key on its tier and
lengths under 2^32. -/
theorem vale_some (enc : Bool) (alg : Algorithm) (kw : List (BitVec 32)) (key : low.x86_64.aes.AesKey)
    (gh : low.x86_64.ghash.GhashTable) (hg : Ready alg kw ⟨key, gh⟩)
    (aad inout : Slice U8) (haad : aad.length < 2 ^ 32) (hin : inout.length < 2 ^ 32) :
    low.x86_64.aes_gcm.vale enc key gh aad inout ⦃ o =>
      ∃ hk kernel, o = some (hk, kernel) ∧ KernelKeys alg hk kw kernel ⦄ := by
  obtain ⟨hk, table, kernel, hkey, hgh, hkk⟩ := hg
  simp only at hkey hgh
  subst hkey hgh
  unfold low.x86_64.aes_gcm.vale
  cases hk with
  | Aes128 k => cases enc <;> step*
  | Aes192 k => exact hkk.2.1.elim
  | Aes256 k => cases enc <;> step*

/-- `AesGcm::encrypt` on Vale's tier, for AAD and messages under 2^32 bytes:
the ciphertext in place and the tag are AES-GCM's. -/
theorem aes_gcm_encrypt_spec (he : ∃ e, low.entry.Entry.new_secret = ok e) (alg : Algorithm)
    (kw : List (BitVec 32)) (g : mid.aes_gcm.AesGcm) (hg : Ready alg kw g)
    (nonce : Std.Array U8 12#usize) (aad inout : Slice U8) (tag : Std.Array U8 16#usize)
    (haad : aad.length < 2 ^ 32) (hin : inout.length < 2 ^ 32) :
    mid.aes_gcm.AesGcm.encrypt g nonce aad inout tag ⦃ r =>
      r.1 = .Ok () ∧ r.2.1.length = inout.length ∧ (bvs r.2.1.val, bvs r.2.2.val) =
        gcmEncrypt alg (seqNat32ToSeqNat8LE kw) (bvs nonce.val) (bvs inout.val) (bvs aad.val) ⦄ := by
  obtain ⟨e, he⟩ := he
  obtain ⟨key, gh⟩ := g
  unfold mid.aes_gcm.AesGcm.encrypt low.x86_64.aes_gcm.seal
  rw [he, bind_ok]
  step*
  · apply WP.spec_bind (vale_some true alg kw key gh hg aad inout haad hin)
    rintro _ ⟨hk, kernel, rfl, hkk⟩
    simp only [low.x86_64.aes_gcm_avx.AvxKernel.seal]
    step with cipher_encrypt_spec alg hk kw kernel hkk nonce aad inout _ haad hin as ⟨res, hres⟩
    obtain ⟨_, out, t⟩ := res
    step*

/-- `AesGcm::decrypt` on Vale's tier, for AAD and messages under 2^32 bytes:
it succeeds exactly when the tag is AES-GCM's, leaving the plaintext in place,
and otherwise fails, leaving zeros. -/
theorem aes_gcm_decrypt_spec (he : ∃ e, low.entry.Entry.new_secret = ok e) (alg : Algorithm)
    (kw : List (BitVec 32)) (g : mid.aes_gcm.AesGcm) (hg : Ready alg kw g)
    (nonce : Std.Array U8 12#usize) (aad inout : Slice U8) (tag : Std.Array U8 16#usize)
    (haad : aad.length < 2 ^ 32) (hin : inout.length < 2 ^ 32) :
    mid.aes_gcm.AesGcm.decrypt g nonce aad inout tag ⦃ r =>
      let out := gcmDecrypt alg (seqNat32ToSeqNat8LE kw) (bvs nonce.val) (bvs inout.val) (bvs aad.val)
        (bvs tag.val)
      if out.2 then r.1 = .Ok () ∧ bvs r.2.val = out.1
      else r.1 = .Err .DecryptFailed ∧ r.2.val = List.replicate inout.length 0#u8 ⦄ := by
  obtain ⟨e, he⟩ := he
  obtain ⟨key, gh⟩ := g
  unfold mid.aes_gcm.AesGcm.decrypt low.x86_64.aes_gcm.open
  rw [he, bind_ok]
  step*
  · apply WP.spec_bind (vale_some false alg kw key gh hg aad inout haad hin)
    rintro _ ⟨hk, kernel, rfl, hkk⟩
    simp only [low.x86_64.aes_gcm_avx.AvxKernel.open]
    step with cipher_decrypt_spec alg hk kw kernel hkk nonce aad inout tag haad hin as ⟨res, hlen, hout, hok⟩
    obtain ⟨i, out, t⟩ := res
    simp only at hlen hout hok
    simp only [low.ct.into_public, bind_ok]
    by_cases hi : i = 0#u64
    · have h2 : (gcmDecrypt alg (seqNat32ToSeqNat8LE kw) (bvs nonce.val) (bvs inout.val) (bvs aad.val)
          (bvs tag.val)).2 = true := hok.1 (by rw [hi]; rfl)
      simp only [hi, ite_true, h2]
      step*
    · have h2 : (gcmDecrypt alg (seqNat32ToSeqNat8LE kw) (bvs nonce.val) (bvs inout.val) (bvs aad.val)
          (bvs tag.val)).2 = false := by
        rw [Bool.eq_false_iff]; intro h; exact hi (by scalar_tac)
      simp only [Bool.false_eq_true, ite_false, h2]
      step*

/-! ## The AEAD API -/

/-- An AEAD key holding AES-GCM on Vale's tier for the key bytes `key` and `alg`. -/
def KeyReady (alg : Algorithm) (key : List (BitVec 8)) (k : aead.Key) : Prop :=
  key.length = 4 * nk alg ∧ ∃ g, k = .AesGcm g ∧ Ready alg (seqNat8ToSeqNat32LE key) g

theorem aes_gcm_new (h : RunsValeAesGcm) (alg : Algorithm) (algorithm : aead.Algorithm)
    (halg : (algorithm = aead.AES_128_GCM ∧ alg = .AES_128) ∨ (algorithm = aead.AES_256_GCM ∧ alg = .AES_256))
    (key : Slice U8) :
    aead.Key.new algorithm key ⦃ r =>
      if key.length = 4 * nk alg then ∃ k, r = .Ok k ∧ KeyReady alg (bvs key.val) k
      else r = .Err .WrongLength ⦄ := by
  have hlen : algorithm.key_len.val = 4 * nk alg := by
    rcases halg with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;> rfl
  unfold aead.Key.new
  by_cases hk : key.length = 4 * nk alg
  · have hne : ¬ key.len ≠ algorithm.key_len := by
      intro hne; apply hne; scalar_tac
    rw [ite_eq_right hne]
    have hexp : algorithm.expand = aead.Sealer.expand mid.aes_gcm.AesGcm.Insts.RindAeadCipher := by
      rcases halg with ⟨rfl, -⟩ | ⟨rfl, -⟩ <;> rfl
    have hkl : KeyLen alg key.length := by
      rcases halg with ⟨-, rfl⟩ | ⟨-, rfl⟩ <;> simp_all [nk, KeyLen]
    have hx : aead.Sealer.expand mid.aes_gcm.AesGcm.Insts.RindAeadCipher key ⦃ i =>
        ∃ g, i = .AesGcm g ∧ Ready alg (seqNat8ToSeqNat32LE (bvs key.val)) g ⦄ := by
      unfold aead.Sealer.expand
      apply WP.spec_bind (aes_gcm_new_spec h alg key hkl)
      intro g hg
      exact (WP.spec_ok _).2 ⟨g, rfl, hg⟩
    rw [hexp]
    apply WP.spec_bind hx
    rintro _ ⟨g, rfl, hg⟩
    refine (WP.spec_ok _).2 ?_
    rw [ite_eq_left hk]
    exact ⟨_, rfl, by simp [hk, bvs], g, rfl, hg⟩
  · have hne : key.len ≠ algorithm.key_len := by intro he; apply hk; rw [← hlen, ← he]; simp
    rw [ite_eq_left hne]
    refine (WP.spec_ok _).2 ?_
    rw [ite_eq_right hk]

theorem key_bytes (alg : Algorithm) (key : List (BitVec 8)) (h : key.length = 4 * nk alg) :
    seqNat32ToSeqNat8LE (seqNat8ToSeqNat32LE key) = key :=
  seqNat32ToSeqNat8LE_seqNat8ToSeqNat32LE key (by omega)

theorem aes_gcm_seal (he : ∃ e, low.entry.Entry.new_secret = ok e) (alg : Algorithm)
    (key : List (BitVec 8)) (k : aead.Key) (hk : KeyReady alg key k) (nonce : aead.Nonce) (aad in_out : Slice U8)
    (haad : aad.length < 2 ^ 32) (hin : in_out.length < 2 ^ 32) :
    k.seal_in_place_separate_tag nonce aad in_out ⦃ r =>
      ∃ tag, r.1 = .Ok tag ∧ r.2.length = in_out.length ∧
        (bvs r.2.val, bvs tag.bytes.val) = gcmEncrypt alg key (bvs nonce.bytes.val) (bvs in_out.val) (bvs aad.val) ⦄ := by
  obtain ⟨hkl, g, rfl, hg⟩ := hk
  unfold aead.Key.seal_in_place_separate_tag aead.Sealer.seal
  simp only [mid.aes_gcm.AesGcm.Insts.RindAeadCipher.seal]
  apply WP.spec_bind (aes_gcm_encrypt_spec he alg _ g hg nonce.bytes aad in_out _ haad hin)
  rintro ⟨r, out, tag⟩ ⟨rfl, hlen, hout⟩
  rw [key_bytes alg key hkl] at hout
  exact (WP.spec_ok _).2 ⟨⟨tag⟩, rfl, hlen, hout⟩

theorem aes_gcm_open_separate_tag (he : ∃ e, low.entry.Entry.new_secret = ok e) (alg : Algorithm)
    (key : List (BitVec 8)) (k : aead.Key) (hk : KeyReady alg key k) (nonce : aead.Nonce) (aad : Slice U8)
    (tag : aead.Tag) (in_out : Slice U8) (haad : aad.length < 2 ^ 32) (hin : in_out.length < 2 ^ 32) :
    k.open_in_place_separate_tag nonce aad tag in_out ⦃ r =>
      let out := gcmDecrypt alg key (bvs nonce.bytes.val) (bvs in_out.val) (bvs aad.val) (bvs tag.bytes.val)
      if out.2 then r.1 = .Ok r.2 ∧ bvs r.2.val = out.1
      else r.1 = .Err .DecryptFailed ∧ r.2.val = List.replicate in_out.length 0#u8 ⦄ := by
  obtain ⟨hkl, g, rfl, hg⟩ := hk
  unfold aead.Key.open_in_place_separate_tag aead.Sealer.open
  simp only [mid.aes_gcm.AesGcm.Insts.RindAeadCipher.open]
  apply WP.spec_bind (aes_gcm_decrypt_spec he alg _ g hg nonce.bytes aad in_out tag.bytes haad hin)
  rintro ⟨r, out⟩ hr
  rw [key_bytes alg key hkl] at hr
  dsimp only at hr
  split at hr
  · obtain ⟨rfl, hout⟩ := hr
    refine (WP.spec_ok _).2 ?_
    simp_all
  · obtain ⟨rfl, hout⟩ := hr
    refine (WP.spec_ok _).2 ?_
    simp_all

theorem aes_gcm_open (he : ∃ e, low.entry.Entry.new_secret = ok e) (alg : Algorithm)
    (key : List (BitVec 8)) (k : aead.Key) (hk : KeyReady alg key k) (nonce : aead.Nonce) (aad in_out : Slice U8)
    (haad : aad.length < 2 ^ 32) (hin : in_out.length < 2 ^ 32) :
    k.open_in_place nonce aad in_out ⦃ r =>
      if in_out.length < 16 then r.1 = .Err .DecryptFailed else
      let out := gcmDecrypt alg key (bvs nonce.bytes.val) (bvs (in_out.val.take (in_out.length - 16)))
        (bvs aad.val) (bvs (in_out.val.drop (in_out.length - 16)))
      if out.2 then r.1 = .Ok r.2 ∧ bvs r.2.val = out.1
      else r.1 = .Err .DecryptFailed ∧ r.2.val = List.replicate (in_out.length - 16) 0#u8 ⦄ := by
  unfold aead.Key.open_in_place
  by_cases hs : in_out.length < 16
  · rw [ite_eq_left hs]
    exact (WP.spec_ok _).2 (by rw [ite_eq_left hs])
  · rw [ite_eq_right hs]
    have hd : (in_out.val.drop (in_out.length - 16)).length = 16 := by simp [Slice.length] at *; omega
    rw [dite_eq_left hd]
    apply WP.spec_mono (aes_gcm_open_separate_tag he alg key k hk nonce aad _ _ haad (by
      rw [Slice.length, Slice.from_val, List.length_take]; omega))
    intro r hr
    rw [ite_eq_right hs]
    simp only [Slice.from_val, Std.Array.from_val] at hr
    have hl : ∀ h, (Slice.from (List.take (in_out.length - 16) in_out.val) h).length = in_out.length - 16 := by
      intro h; rw [Slice.length, Slice.from_val, List.length_take]; simp only [Slice.length] at *; omega
    rw [hl] at hr
    exact hr

end rind.x86_64
