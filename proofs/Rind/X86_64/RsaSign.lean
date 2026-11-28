import Rind.X86_64.RsaPrivKey
import Rind.X86_64.P256Ecdsa
open Aeneas Aeneas.Std Result rind.spec rind.spec.rsa

/-!
# RSA signing on x86_64

`SigningKey`'s RSASSA-PKCS1-v1_5 and RSASSA-PSS signing with SHA-256 are RFC
8017's RSASSA-PKCS1-V1_5-SIGN and RSASSA-PSS-SIGN, as `Rind.Rsa` transliterates
them, with RSASP1 by the CRT, for a key meeting `PrivKeyInv`, the values
`RsaPrivateKey::new` computes. `encode_pss_sig` is EMSA-PSS-ENCODE over any
hash meeting `HashSpec` and any random source whose draws return, for the salt
the source drew, which the functional spec leaves out. Signing refuses only
where `private_op`'s fault check does, RSASP1's result raised to `e` modulo `n`
not being the encoded message's representative, and, for PSS, where the
random source fails.
-/

namespace rind.spec.rsa

theorem os2ip_append (A B : List Byte) : os2ip (A ++ B) = os2ip A * 256 ^ B.length + os2ip B := by
  unfold os2ip
  rw [List.foldl_append]
  generalize hA : A.foldl (fun x b => 256 * x + b.toNat) 0 = a
  clear hA
  induction B generalizing a with
  | nil => simp
  | cons b B ih =>
    simp only [List.foldl_cons, List.length_cons]
    rw [ih, ih (256 * 0 + b.toNat)]
    ring

theorem os2ip_lt (A : List Byte) : os2ip A < 256 ^ A.length := by
  induction A using List.reverseRecOn with
  | nil => simp [os2ip]
  | append_singleton A b ih =>
    rw [os2ip_append, List.length_append, List.length_singleton, pow_one, pow_succ]
    have hb : os2ip [b] = b.toNat := by simp [os2ip]
    have := b.isLt
    rw [hb]
    have h8 : (2 : Nat) ^ 8 = 256 := by norm_num
    rw [h8] at this
    nlinarith

/-- A number is at least `2^(size - 1)`, its top bit. -/
theorem two_pow_size_le (n : Nat) (h : 0 < n) : 2 ^ (n.size - 1) ≤ n := by
  by_contra hc
  have := (Nat.size_le).mpr (show n < 2 ^ (n.size - 1) by omega)
  have : 0 < n.size := Nat.size_pos.mpr h
  omega

/-- EMSA-PKCS1-v1_5's encoding, which starts with a zero octet, has a
representative below `n`. -/
theorem emsaPkcs1v15Encode_lt (H : List Byte → List Byte) (di M : List Byte) (n : Nat) (hn : 0 < n)
    (EM : List Byte) (h : emsaPkcs1v15Encode H di M (octetLen n) = some EM) : os2ip EM < n := by
  unfold emsaPkcs1v15Encode at h
  dsimp only at h
  split at h
  · cases h
  · rename_i hk
    cases h
    set T := di ++ H M
    rw [show ([0x00, 0x01] : List Byte) = [0x00] ++ [0x01] from rfl, List.append_assoc, List.append_assoc,
      List.append_assoc, os2ip_append]
    simp only [show os2ip [0x00] = 0 by rfl, zero_mul, zero_add]
    have hl : ([0x01] ++ (List.replicate (octetLen n - T.length - 3) 0xff ++ ([0x00] ++ T))).length =
        octetLen n - 1 := by
      simp only [List.length_append, List.length_singleton, List.length_replicate]; omega
    calc _ < 256 ^ ([0x01] ++ (List.replicate (octetLen n - T.length - 3) 0xff ++ ([0x00] ++ T))).length :=
          os2ip_lt _
      _ = 2 ^ (8 * (octetLen n - 1)) := by rw [hl, pow_mul]; norm_num
      _ ≤ 2 ^ (n.size - 1) := Nat.pow_le_pow_right (by norm_num) (by unfold octetLen; omega)
      _ ≤ n := two_pow_size_le n hn

theorem mgf1_length (H : List Byte → List Byte) (hLen : Nat) (hL : 0 < hLen)
    (hH : ∀ m, (H m).length = hLen) (seed : List Byte) (n : Nat) : (mgf1 H hLen seed n).length = n := by
  unfold mgf1
  rw [List.length_take, List.length_flatMap]
  have : (List.map (fun a => (H (seed ++ (BitVec.ofNat 32 a).toBEBytes)).length)
      (List.range ((n + hLen - 1) / hLen))) = List.replicate ((n + hLen - 1) / hLen) hLen := by
    apply List.ext_getElem <;> simp [hH]
  rw [this, List.sum_replicate, smul_eq_mul]
  apply min_eq_left
  have h1 := Nat.div_add_mod (n + hLen - 1) hLen
  have h2 := Nat.mod_lt (n + hLen - 1) hL
  rw [Nat.mul_comm] at h1
  omega

/-- EMSA-PSS's encoding is `emLen` octets whose representative is below
`2^emBits`, as its leftmost `8 emLen - emBits` bits are zero. -/
theorem emsaPssEncode_lt (H : List Byte → List Byte) (hLen : Nat) (hL : 0 < hLen)
    (hH : ∀ m, (H m).length = hLen) (M salt : List Byte) (emBits : Nat) (EM : List Byte)
    (h : emsaPssEncode H hLen M salt emBits = some EM) :
    EM.length = (emBits + 7) / 8 ∧ os2ip EM < 2 ^ emBits := by
  unfold emsaPssEncode at h
  dsimp only at h
  split at h
  · cases h
  · rename_i hk
    cases h
    set emLen := (emBits + 7) / 8
    set DB := List.replicate (emLen - salt.length - hLen - 2) (0x00 : Byte) ++ [0x01] ++ salt
    set H' := H (List.replicate 8 0x00 ++ H M ++ salt)
    set t := 8 * emLen - emBits
    have hDB : DB.length = emLen - hLen - 1 := by
      simp only [DB, List.length_append, List.length_replicate, List.length_singleton]; omega
    have hX : (List.zipWith (· ^^^ ·) DB (mgf1 H hLen H' (emLen - hLen - 1))).length = emLen - hLen - 1 := by
      rw [List.length_zipWith, hDB, mgf1_length H hLen hL hH]; simp
    obtain ⟨x, xs, hxs⟩ : ∃ x xs, List.zipWith (· ^^^ ·) DB (mgf1 H hLen H' (emLen - hLen - 1)) = x :: xs := by
      cases hc : List.zipWith (· ^^^ ·) DB (mgf1 H hLen H' (emLen - hLen - 1)) with
      | nil => rw [hc] at hX; simp at hX; omega
      | cons x xs => exact ⟨x, xs, rfl⟩
    rw [hxs] at hX ⊢
    simp only [List.modifyHead_cons, List.cons_append]
    have hH'l : H'.length = hLen := hH _
    have hlen : (xs ++ H' ++ [0xbc]).length = emLen - 1 := by
      simp only [List.length_append, List.length_singleton, hH'l]; simp at hX; omega
    refine ⟨by simp only [List.length_cons, hlen]; omega, ?_⟩
    rw [show (x &&& BitVec.ofNat 8 (2 ^ (8 - t) - 1)) :: (xs ++ H' ++ [0xbc]) =
      [x &&& BitVec.ofNat 8 (2 ^ (8 - t) - 1)] ++ (xs ++ H' ++ [0xbc]) from rfl, os2ip_append, hlen]
    have hb : os2ip [x &&& BitVec.ofNat 8 (2 ^ (8 - t) - 1)] < 2 ^ (8 - t) := by
      simp only [os2ip, List.foldl_cons, List.foldl_nil, mul_zero, zero_add, BitVec.toNat_and,
        BitVec.toNat_ofNat]
      have ht : t ≤ 7 := by omega
      have h1 : (2 ^ (8 - t) - 1) % 2 ^ 8 = 2 ^ (8 - t) - 1 := by
        apply Nat.mod_eq_of_lt
        have : 2 ^ (8 - t) ≤ 2 ^ 8 := Nat.pow_le_pow_right (by norm_num) (by omega)
        have : 0 < 2 ^ (8 - t) := by positivity
        omega
      rw [h1]
      have := Nat.and_le_right (n := x.toNat) (m := 2 ^ (8 - t) - 1)
      have : 0 < 2 ^ (8 - t) := by positivity
      omega
    have hr := os2ip_lt (xs ++ H' ++ [0xbc])
    rw [hlen] at hr
    have hpow : (2 : Nat) ^ emBits = 2 ^ (8 - t) * 256 ^ (emLen - 1) := by
      rw [show (256 : Nat) = 2 ^ 8 by norm_num, ← pow_mul, ← pow_add]
      congr 1
      omega
    rw [hpow]
    have h1 : os2ip [x &&& BitVec.ofNat 8 (2 ^ (8 - t) - 1)] + 1 ≤ 2 ^ (8 - t) := hb
    calc _ < os2ip [x &&& BitVec.ofNat 8 (2 ^ (8 - t) - 1)] * 256 ^ (emLen - 1) + 256 ^ (emLen - 1) := by omega
      _ = (os2ip [x &&& BitVec.ofNat 8 (2 ^ (8 - t) - 1)] + 1) * 256 ^ (emLen - 1) := by ring
      _ ≤ _ := Nat.mul_le_mul_right _ h1

end rind.spec.rsa

namespace rind.x86_64

/-- A private key's modulus. -/
abbrev keyN (key : mid.rsa_priv.RsaPrivateKey) : Nat := wordsNat (lowWords key.public.n key.public.n.used)

/-- What signing returns for the encoded message `EM` with `key`: RSASP1 of
`EM`'s representative by the CRT, as the modulus's `k` octets, unless
`private_op`'s fault check finds that raised to `e` modulo `n` it is not that
representative. -/
def SignedAs (key : mid.rsa_priv.RsaPrivateKey) (EM : List U8) :
    core.result.Result (Slice U8) error.Error → Prop
  | .Ok s => i2osp (keyRsasp1 key (beNat EM)) (octetLen (keyN key)) = some (bv s.val)
  | .Err e => e = .Fault ∧ keyRsasp1 key (beNat EM) ^ key.public.e.val % keyN key ≠ beNat EM

/-- `to_signature` writes `c`, below `n`, to the first `k` bytes of
`signature`, the modulus's length, given room for them. -/
theorem to_signature_spec (key : high.rsa.SigningKey) (hinv : PubKeyInv key.public) (c : RsaInt)
    (hcu : c.used.val ≤ 128) (hcN : wordsNat (lowWords c c.used) < keyN key)
    (signature : Slice U8) (hroom : octetLen (keyN key) ≤ signature.length) :
    high.rsa.SigningKey.to_signature key c signature ⦃ r sig' =>
      ∃ s, r = .Ok s ∧ s.length = octetLen (keyN key) ∧ beNat s.val = wordsNat (lowWords c c.used) ∧
        sig'.length = signature.length ∧ sig'.val.take s.length = s.val ⦄ := by
  unfold high.rsa.SigningKey.to_signature mid.rsa_priv.RsaPrivateKey.modulus_len_bytes
  step with modulus_len_bytes_spec key.public hinv as ⟨k, hkv⟩
  split
  · rename_i hlt
    exfalso
    have h1 : signature.len.val < k.val := hlt
    have h2 : signature.len.val = signature.length := rfl
    unfold keyN at hroom
    omega
  · step as ⟨s1, back, hs1, hs1l, hback⟩
    step with i2osp_spec c s1 hcu as ⟨r, s2, hi, _⟩
    obtain ⟨rfl, hs2l, hs2v⟩ := hi (by rw [hs1l, hkv]; exact lt_octetLen _ _ hcN)
    simp only [core.result.Result.Insts.CoreOpsTry.branch, bind_ok, WP.spec_ok]
    refine ⟨s2, rfl, by rw [hs2l, hs1l, hkv], hs2v, ?_, ?_⟩
    · show (back s2).val.length = signature.val.length
      rw [hback]; simp
    · rw [hback]
      have e1 : s2.val.length = s2.length := rfl
      have e2 : signature.val.length = signature.length := rfl
      unfold keyN at hroom
      have h := take_setSlice! signature.val s2.val 0 (by omega)
      simpa [← e1] using h

/-- The CRT's result for a representative below `n` is below `n`. -/
theorem keyRsasp1_lt (key : mid.rsa_priv.RsaPrivateKey) (hinv : PrivKeyInv key) (c : Nat) :
    keyRsasp1 key c < keyN key := by
  obtain ⟨-, -, -, -, -, -, hp1, hq1, hn, -⟩ := hinv
  unfold keyN keyRsasp1
  rw [hn]
  exact rsasp1Crt_lt _ _ _ _ _ _ (by omega) (by omega)

/-- `_sign_pkcs1` refuses a buffer shorter than the modulus, and otherwise
signs the EMSA-PKCS1-v1_5 encoding of `M`, given its hash and `DigestInfo`. -/
theorem sign_pkcs1_core_spec (havx : ∃ t, low.x86_64.cpu.HaveAvx2.check = ok t)
    (t : low.x86_64.cpu.HaveBmi2Adx) (hadx : low.x86_64.cpu.HaveBmi2Adx.check = ok (some t))
    (hifma : IfmaCheckReturns) (key : high.rsa.SigningKey) (hinv : PrivKeyInv key)
    (hPn : MontProducts key.public.n.used.val)
    (hcrt : key.ifma.w = 0#usize → MontProducts key.p.used.val ∧
      (key.p.used.val = 16 ∨ key.p.used.val = 32) ∧ NoRsazPair key.p.used.val)
    (signature digest_info hash : Slice U8) (hT : digest_info.length + hash.length + 11 ≤ 128)
    (hroom : octetLen (keyN key) ≤ signature.length) (H : List Byte → List Byte) (M : List Byte)
    (hH : H M = bv hash.val) :
    high.rsa.SigningKey._sign_pkcs1 key signature digest_info hash ⦃ r sig' =>
      ∃ EM : List U8, emsaPkcs1v15Encode H (bv digest_info.val) M (octetLen (keyN key)) = some (bv EM) ∧
        SignedAs key EM r ∧ ∀ s, r = .Ok s → sig'.length = signature.length ∧ sig'.val.take s.length = s.val ⦄ := by
  have hpub := hinv.1
  obtain ⟨hk2, hk, hodd, hn0, hmont, he, he3, hs1, hs2, htop⟩ := hpub
  unfold high.rsa.SigningKey._sign_pkcs1 mid.rsa_priv.RsaPrivateKey.modulus_len_bytes
  step with modulus_len_bytes_spec key.public hinv.1 as ⟨k, hkv⟩
  have hk128 : 128 ≤ k.val := by rw [hkv, octetLen]; omega
  have hk1024 : k.val ≤ 1024 := by rw [hkv, octetLen]; omega
  split
  · rename_i hlt
    exfalso
    have h1 : signature.len.val < k.val := hlt
    have h2 : signature.len.val = signature.length := rfl
    unfold keyN at hroom
    omega
  · step as ⟨m1, _b, hm1, hm1l, _⟩
    step with encode_pkcs1_sig_spec m1 digest_info hash (by omega) as ⟨m2, hm2⟩
    have hm2l : m2.val.length = k.val := by
      rw [hm2]; simp only [List.length_append, List.length_replicate, List.length_cons, List.length_nil]
      have : m1.length = k.val := hm1l
      have : digest_info.length = digest_info.val.length := rfl
      have : hash.length = hash.val.length := rfl
      omega
    have hEM : emsaPkcs1v15Encode H (bv digest_info.val) M (octetLen (keyN key)) = some (bv m2.val) := by
      unfold emsaPkcs1v15Encode
      have hTl : (bv digest_info.val ++ H M).length = digest_info.length + hash.length := by
        simp [hH, bv]
      dsimp only
      rw [hTl, ← hkv, ite_eq_right_of_eq_false _ _ (eq_false (by omega)), hm2, hm1l, hH, bv_pkcs1]
    have hlt : beNat m2.val < keyN key := by
      rw [← os2ip_bv]
      exact emsaPkcs1v15Encode_lt _ _ _ _ (by unfold keyN; omega) _ hEM
    step with posint_from_bytes_spec m2 (beNat_lt_8192 _ (by omega)) as ⟨r, c, hr, hcu, hcz, hcv, _⟩
    subst hr
    simp only [core.result.Result.Insts.CoreOpsTry.branch, bind_ok]
    step with private_op_spec havx t hadx hifma key hinv hPn hcrt c hcu hcz as ⟨r1, hr1⟩
    cases r1 with
    | Err e =>
      simp only [PrivateOpResult] at hr1
      rcases hr1 with ⟨-, hge⟩ | ⟨rfl, -, hne⟩
      · exfalso; unfold keyN at hlt; rw [hcv] at hge; omega
      · simp only [core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual,
          core.convert.FromSame.from, bind_ok, bind_tc_ok]
        refine (WP.spec_ok _).mpr ?_
        simp only [WP.uncurry'_pair]
        exact ⟨m2.val, hEM, ⟨rfl, by rw [hcv] at hne; exact hne⟩, fun s h => nomatch h⟩
    | Ok sv =>
      obtain ⟨-, hsu, hsv, hchk⟩ := hr1
      simp only [low.ct.into_public, bind_ok]
      have hsN : wordsNat (lowWords sv sv.used) < keyN key := by
        rw [hsv]; exact keyRsasp1_lt key hinv _
      step with to_signature_spec key hinv.1 sv (by rw [hsu]; exact hk) hsN signature hroom
        as ⟨r2, sig', s, hr2, hsl, hsb, hsig'l, hsig'v⟩
      subst hr2
      refine ⟨m2.val, hEM, ?_, fun s' h => by injection h with h; subst h; exact ⟨hsig'l, hsig'v⟩⟩
      simp only [SignedAs]
      rw [← hcv, ← hsv, ← hsb, ← hsl, i2osp_beNat]

/-- RSASSA-PKCS1-V1_5-SIGN with SHA-256: `sign_pkcs1_sha256` signs the
EMSA-PKCS1-v1_5 encoding of `message` with SHA-256's `DigestInfo`. -/
theorem sign_pkcs1_sha256_spec (h : Runs) (hb : Sha256Blocks)
    (t : low.x86_64.cpu.HaveBmi2Adx) (hadx : low.x86_64.cpu.HaveBmi2Adx.check = ok (some t))
    (hifma : IfmaCheckReturns) (key : high.rsa.SigningKey) (hinv : PrivKeyInv key)
    (hPn : MontProducts key.public.n.used.val)
    (hcrt : key.ifma.w = 0#usize → MontProducts key.p.used.val ∧
      (key.p.used.val = 16 ∨ key.p.used.val = 32) ∧ NoRsazPair key.p.used.val)
    (signature message : Slice U8) (hm : message.length ≤ maxInput)
    (hroom : octetLen (keyN key) ≤ signature.length) :
    high.rsa.SigningKey.sign_pkcs1_sha256 key signature message ⦃ r sig' =>
      ∃ EM : List U8, emsaPkcs1v15Encode sha256.hash digestInfoSha256 (bv message.val)
          (octetLen (keyN key)) = some (bv EM) ∧
        SignedAs key EM r ∧ ∀ s, r = .Ok s → sig'.length = signature.length ∧ sig'.val.take s.length = s.val ⦄ := by
  unfold high.rsa.SigningKey.sign_pkcs1_sha256
  step with new_secret_spec h
  have hs := sha256_hashSpec hb
  have hh := hs.hash_spec message hm
  rw [hs.hash_default] at hh
  step with hh as ⟨d, hdl, hdv⟩
  step with digest_as_ref_spec d as ⟨sh, hshl, hshv⟩
  rw [← digestinfo_sha256.1]
  exact sign_pkcs1_core_spec h.2.2.2 t hadx hifma key hinv hPn hcrt signature _ sh
    (by rw [digestinfo_sha256.2, hshl, hdl]; norm_num) hroom sha256.hash (bv message.val) (by rw [hshv, hdv])

/-! ## EMSA-PSS-ENCODE -/

theorem setSlice!_take_prefix {α : Type _} (r s : List α) (i : Nat) (hi : i ≤ r.length) :
    (r.setSlice! i s).take i = r.take i := by
  simp only [List.setSlice!]
  rw [List.append_assoc, List.take_append_of_le_length (by simp; omega), List.take_take, min_self]

theorem setSlice!_length' {α : Type _} (r s : List α) (i : Nat) : (r.setSlice! i s).length = r.length := by
  simp only [List.setSlice!, List.length_append, List.length_take, List.length_drop]
  omega

/-- A list's first `j` elements, split at `i`. -/
theorem take_eq_take_slice {α : Type _} (l : List α) (i j : Nat) (hij : i ≤ j) :
    l.take j = l.take i ++ l.slice i j := by
  rw [List.slice]
  conv_lhs => rw [show j = i + (j - i) by omega, List.take_add]

/-- What `encode_pss_sig` writes after masking, from the encoded message's
parts: `maskedDB`, then `H`, then `0xbc`. -/
theorem pss_encoded (Z s8 h : List U8) (dbLen emLen : Nat) (m : U8) (hZ : Z.length = emLen)
    (hs8 : s8.length = dbLen) (hd : 1 ≤ dbLen) (hh : dbLen + h.length + 1 = emLen) :
    (((s8 ++ Z.drop dbLen).set 0 ((s8 ++ Z.drop dbLen)[0]! &&& m)).setSlice! dbLen h).set (emLen - 1) 188#u8 =
      s8.set 0 (s8[0]! &&& m) ++ h ++ [188#u8] := by
  have hhd : (s8 ++ Z.drop dbLen)[0]! = s8[0]! := by
    rw [getElem!_pos _ _ (by simp; omega), getElem!_pos _ _ (by omega), List.getElem_append_left]
  rw [hhd, List.set_append_left _ _ (by omega)]
  have hl : (Z.drop dbLen).length = h.length + 1 := by simp; omega
  obtain ⟨Y, y, hY⟩ : ∃ Y y, Z.drop dbLen = Y ++ [y] := by
    refine ⟨(Z.drop dbLen).dropLast, (Z.drop dbLen).getLast (by intro h'; simp [h'] at hl), ?_⟩
    exact (List.dropLast_append_getLast _).symm
  have hYl : Y.length = h.length := by
    have := congrArg List.length hY; simp at this; omega
  rw [hY, ← List.append_assoc]
  have hsl : (s8.set 0 (s8[0]! &&& m)).length = dbLen := by simp [hs8]
  rw [show dbLen = (s8.set 0 (s8[0]! &&& m)).length from hsl.symm, setSlice!_append _ _ _ _ hYl.symm]
  have : emLen - 1 = (s8.set 0 (s8[0]! &&& m) ++ h).length := by simp only [List.length_append, hsl]; omega
  rw [this, List.set_append_right _ _ (le_refl _), Nat.sub_self]
  simp

section
variable {Self C S : Type} {inst : high.hash.Hash Self C S} {H : List Byte → List Byte}
  {B L max : Nat} {Abs : List U8 → S → Prop} {CAbs : List U8 → C → Prop}

set_option maxHeartbeats 2000000 in
/-- EMSA-PSS-ENCODE: `encode_pss_sig` refuses a salt too long for `out`, and
otherwise writes RFC 8017's encoding of `M` with the salt `rng` drew, or
fails as the draw does. -/
theorem encode_pss_sig_spec (hs : HashSpec inst H B L max Abs CAbs) (hnew : inst.new ⦃ c => CAbs [] c ⦄)
    (hL : 0 < L) (hmax : 2048 ≤ max) {T : Type} (rinst : mid.rng.RandomSource T) (hd : Draws rinst) (rng : T)
    (out : Slice U8) (em_bits : Usize) (hem : out.length = (em_bits.val + 7) / 8) (hem1024 : out.length ≤ 1024)
    (hash : Slice U8) (M : List Byte) (hmh : bv hash.val = H M) (s_len : Usize) (hsl : s_len.val ≤ 65535) :
    high.pkcs1.encode_pss_sig inst rinst out em_bits rng hash s_len ⦃ r =>
      match r.1 with
      | .Ok () => ∃ salt : List U8, salt.length = s_len.val ∧
          emsaPssEncode H L M (bv salt) em_bits.val = some (bv r.2.1.val)
      | .Err e => e = .RngFailed ∨ (out.length < L + s_len.val + 2 ∧ e = .KeyRejected .RsaModulus) ⦄ := by
  have hHL := hs.out.2.2.2.2
  have hmL : hash.length = L := by rw [← hHL M, ← hmh, bv_length]
  have hL64 : L ≤ 64 := hs.out.2.1
  have hn : out.len.val = out.length := rfl
  have hhn : hash.len.val = L := hmL
  have hoL : out.length = out.val.length := rfl
  unfold high.pkcs1.encode_pss_sig
  step as ⟨i, hi⟩
  step as ⟨i1, hi1⟩
  split
  · rename_i hlt
    simp only [error.Error.Insts.CoreConvertFromKeyFormatError.from, bind_ok, WP.spec_ok]
    right
    exact ⟨by scalar_tac, trivial⟩
  · rename_i hge
    step as ⟨i2, hi2⟩
    step as ⟨db_len, hdb⟩
    step as ⟨salt_start, hss⟩
    step as ⟨i3, hi3⟩
    step as ⟨s0, back, hs0v, hs0l, hback⟩
    step as ⟨s1, hs1l, hs1v⟩
    step as ⟨out2, hout2⟩
    step as ⟨s2, back1, hs2v, hs2l, hback1⟩
    step with hd rng s2 as ⟨r, rng1, s3, hr⟩
    have hge' : L + s_len.val + 2 ≤ out.length := by scalar_tac
    have hi3v : i3.val = out.length - L - s_len.val - 2 := by scalar_tac
    have hssv : salt_start.val = out.length - L - 1 - s_len.val := by scalar_tac
    have hdbv : db_len.val = out.length - L - 1 := by scalar_tac
    have hout2l : out2.val.length = out.length := by
      rw [hout2, Slice.set_val_eq, List.length_set, hback, setSlice!_length']
    rcases r with ⟨⟩ | e
    · simp only [core.result.Result.Insts.CoreOpsTry.branch, bind_ok]
      set Z := (back1 s3) with hZ
      have hZv : Z.val = out2.val.setSlice! salt_start.val s3.val := by rw [hZ, hback1, Slice.setSlice!_val]
      have hZl : Z.val.length = out.length := by rw [hZv, setSlice!_length', hout2l]
      step with hnew as ⟨ctx, hctx⟩
      step as ⟨s4, hs4⟩
      have hs4v : s4.val = List.replicate 8 0#u8 := by
        rw [hs4]; simp only [Std.Array.to_slice, Array.repeat_val]; rfl
      have hs4l : s4.length = 8 := by show s4.val.length = 8; rw [hs4v, List.length_replicate]
      step with hs.update [] ctx s4 hctx (by simp only [List.length_nil]; omega) as ⟨ctx1, hctx1⟩
      step with hs.update _ ctx1 hash hctx1 (by simp only [List.nil_append, hs4v, List.length_replicate]; omega)
        as ⟨ctx2, hctx2⟩
      step as ⟨s5, hs5v, hs5l⟩
      have hs5L : s5.val.length = s_len.val := by
        show s5.length = s_len.val; rw [hs5l, hssv, hdbv]; omega
      have hhL' : hash.val.length = L := hmL
      step with hs.update _ ctx2 s5 hctx2
        (by simp only [List.nil_append, List.length_append, hs4v, List.length_replicate]; omega) as ⟨ctx3, hctx3⟩
      step with hs.finish _ ctx3 hctx3
        (by simp only [List.nil_append, List.length_append, hs4v, List.length_replicate]; omega) as ⟨d, hdl, hdv⟩
      step with digest_as_ref_spec d as ⟨s6, hs6l, hs6v⟩
      rw [hdl] at hs6l
      step as ⟨s7, back2, hs7v, hs7l, hback2⟩
      step with mgf1_xor_spec hs hnew hL s6 (by omega) hash.len hhn s7 (by omega) as ⟨s8, hs8l, hs8v⟩
      step as ⟨i4, hi4⟩
      step as ⟨i5, hi5⟩
      step as ⟨i6, hi6, _⟩
      have hb2 : (back2 s8).length = out.length := by
        show (back2 s8).val.length = _; rw [hback2, setSlice!_length', hZl]
      step as ⟨i7, hi7⟩
      step as ⟨i8, hi8⟩
      step as ⟨out5, hout5⟩
      step as ⟨i9, hi9⟩
      step as ⟨s9, back3, hs9v, hs9l, hback3⟩
      have hs96 : s9.length = s6.length := by rw [hs9l, hs6l, hi9, hdbv, hn]; omega
      step as ⟨s10, hs10⟩
      have hout5l : out5.length = out.length := by
        rw [hout5]; simp only [Slice.length, Slice.set_val_eq, List.length_set]; exact hb2
      have hb3l : (back3 s10).length = out.length := by
        rw [hback3]; simp only [Slice.length, Slice.setSlice!_val, setSlice!_length']; exact hout5l
      step as ⟨out7, hout7⟩
      refine ⟨s5.val, hs5L, ?_⟩
      -- The data block, `PS || 0x01 || salt`.
      have hs1v' : s1.val = List.replicate i3.val 0#u8 := by rw [hs1v, hs0l]
      have hpre : (back s1).val.take i3.val = List.replicate i3.val 0#u8 := by
        rw [hback]
        have h := take_setSlice! out.val s1.val 0 (by rw [hs1v']; simp; omega)
        simpa [hs1v'] using h
      have hZpre : Z.val.take salt_start.val = List.replicate i3.val 0#u8 ++ [1#u8] := by
        rw [hZv, setSlice!_take_prefix _ _ _ (by rw [hout2l]; omega), hout2, Slice.set_val_eq,
          show salt_start.val = i3.val + 1 by omega, take_set_succ _ _ _ (by
            show i3.val < (back s1).val.length; rw [hback, setSlice!_length']; omega), hpre]
      have hDB : s7.val = List.replicate i3.val 0#u8 ++ [1#u8] ++ s5.val := by
        rw [hs7v, List.slice_zero_j, take_eq_take_slice _ salt_start.val _ (by omega), hZpre, hs5v]
      have hs7L : s7.length = out.length - L - 1 := by rw [hs7l, hdbv]
      have hs8L : s8.val.length = db_len.val := by
        show s8.length = _; rw [hs8l, hs7l]
      -- The masked block, then `H`, then `0xbc`.
      have hb2v : (back2 s8).val = s8.val ++ Z.val.drop db_len.val := by
        rw [hback2, setSlice!_eq _ _ _ (by rw [hs8L, hZl]; omega), List.take_zero, List.nil_append, hs8L,
          Nat.zero_add]
      have hi8' : i8 = i7 &&& i6 := by rw [UScalar.eq_equiv]; exact hi8
      have hout7v : out7.val = s8.val.set 0 (s8.val[0]! &&& i6) ++ s6.val ++ [188#u8] := by
        have hi7' : i7 = (s8.val ++ Z.val.drop db_len.val)[0]! := by rw [hi7, ← getElem!_pos, hb2v]
        have hs6L : s6.val.length = L := hs6l
        rw [hout7, Slice.set_val_eq, hback3, Slice.setSlice!_val, hs10, hout5, Slice.set_val_eq, hi8', hi7',
          hb2v, show (0#usize : Usize).val = 0 from rfl, show i9.val = out.length - 1 by omega]
        exact pss_encoded Z.val s8.val s6.val db_len.val out.length i6 hZl hs8L (by omega) (by omega)
      have hmask : i6.bv = BitVec.ofNat 8 (2 ^ (8 - (8 * out.length - em_bits.val)) - 1) := by
        apply BitVec.eq_of_toNat_eq
        rw [mask_toNat _ (by omega)]
        show i6.val = _
        rw [hi6, hi5, hi4, hn]
        rfl
      have hH' : bv s6.val = H (List.replicate 8 0x00 ++ H M ++ bv s5.val) := by
        rw [hs6v, hdv, List.nil_append, bv, List.map_append, List.map_append, ← bv, ← bv, ← bv, hs4v, hmh]
        rfl
      have hDBb : List.replicate (out.length - s_len.val - L - 2) (0x00 : Byte) ++ [0x01] ++ bv s5.val =
          bv s7.val := by
        rw [hDB, show i3.val = out.length - s_len.val - L - 2 by omega]
        simp [bv, List.map_replicate]
      unfold emsaPssEncode
      have hsL : (bv s5.val).length = s_len.val := by rw [bv_length, hs5L]
      dsimp only
      rw [hsL, ← hem, ite_eq_right_of_eq_false _ _ (eq_false (by omega))]
      congr 1
      rw [hout7v, ← hH', hDBb, show out.length - L - 1 = s7.length by omega, ← hs8v, ← hmask,
        ← bv_set_head _ (by omega)]
      simp [bv]
    · simp only [core.result.Result.Insts.CoreOpsTry.branch, bind_ok,
        core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual,
        core.convert.FromSame.from, bind_tc_ok, WP.spec_ok]
      left
      exact hr e rfl

end

/-- `PssSalt::len` is the salt length it names. -/
theorem pss_salt_len_of (salt : high.rsa.PssSalt) (em_len h_len : Usize) (hh : h_len.val ≤ 64)
    (hem : em_len.val ≤ 1024) :
    high.rsa.PssSalt.len salt em_len h_len ⦃ x => x.val = pssSaltLen em_len.val h_len.val salt ∧ x.val ≤ 65535 ⦄ := by
  unfold high.rsa.PssSalt.len
  cases salt with
  | Hash =>
    show (ok h_len : Result Usize) ⦃ x => _ ⦄
    simp only [WP.spec_ok, pssSaltLen]
    exact ⟨trivial, by omega⟩
  | Max =>
    show (do
      let i ← h_len + 2#usize
      ok (core.num.Usize.saturating_sub em_len i) : Result Usize) ⦃ x => _ ⦄
    step as ⟨i, hi⟩
    simp only [pssSaltLen]
    rw [usize_saturating_sub_val, hi]
    omega
  | Len l =>
    show core.convert.IntoFrom.into core.convert.FromUsizeU16 l ⦃ x => _ ⦄
    simp only [core.convert.IntoFrom.into, WP.spec_ok, pssSaltLen, core.convert.num.FromUsizeU16.from_val_eq]
    exact ⟨trivial, by scalar_tac⟩

section
variable {Self C S : Type} {inst : high.hash.Hash Self C S} {H : List Byte → List Byte}
  {B L max : Nat} {Abs : List U8 → S → Prop} {CAbs : List U8 → C → Prop}

/-- `_sign_pss` refuses a buffer shorter than the modulus, a salt too long
for its encoded message, and a failed draw, and otherwise signs the
EMSA-PSS encoding of `message` with the salt it drew. -/
theorem sign_pss_core_spec (hs : HashSpec inst H B L max Abs CAbs) (hnew : inst.new ⦃ c => CAbs [] c ⦄)
    (hL : 0 < L) (hmax : 2048 ≤ max) (hd : Draws mid.rng.SystemRandom.Insts.RindMidRngRandomSource)
    (havx : ∃ t, low.x86_64.cpu.HaveAvx2.check = ok t)
    (t : low.x86_64.cpu.HaveBmi2Adx) (hadx : low.x86_64.cpu.HaveBmi2Adx.check = ok (some t))
    (hifma : IfmaCheckReturns) (key : high.rsa.SigningKey) (hinv : PrivKeyInv key)
    (hPn : MontProducts key.public.n.used.val)
    (hcrt : key.ifma.w = 0#usize → MontProducts key.p.used.val ∧
      (key.p.used.val = 16 ∨ key.p.used.val = 32) ∧ NoRsazPair key.p.used.val)
    (salt : high.rsa.PssSalt) (signature message : Slice U8) (hm : message.length ≤ max)
    (hroom : octetLen (keyN key) ≤ signature.length) :
    high.rsa.SigningKey._sign_pss inst key salt signature message ⦃ r sig' =>
      (∃ e, r = .Err e ∧ (e = .RngFailed ∨ (e = .KeyRejected .RsaModulus ∧
        ((keyN key).size - 1 + 7) / 8 < L + pssSaltLen (((keyN key).size - 1 + 7) / 8) L salt + 2))) ∨
      ∃ salt' : List U8, salt'.length = pssSaltLen (((keyN key).size - 1 + 7) / 8) L salt ∧
        ∃ EM : List U8, emsaPssEncode H L (bv message.val) (bv salt') ((keyN key).size - 1) = some (bv EM) ∧
          SignedAs key EM r ∧ ∀ s, r = .Ok s → sig'.length = signature.length ∧ sig'.val.take s.length = s.val ⦄ := by
  have hpub := hinv.1
  obtain ⟨hk2, hk, hodd, hn0, hmont, he, he3, hs1, hs2, htop⟩ := hpub
  have hL64 : L ≤ 64 := hs.out.2.1
  unfold high.rsa.SigningKey._sign_pss mid.rsa_priv.RsaPrivateKey.modulus_len_bytes
  step with modulus_len_bytes_spec key.public hinv.1 as ⟨k, hkv⟩
  split
  · rename_i hlt
    exfalso
    have h1 : signature.len.val < k.val := hlt
    have h2 : signature.len.val = signature.length := rfl
    unfold keyN at hroom
    omega
  · step with hs.hash_spec message hm as ⟨d, hdl, hdv⟩
    unfold mid.rsa_priv.RsaPrivateKey.modulus_len_bits mid.rsa_pub.RsaPublicKey.modulus_len_bits
    step with len_bits_spec key.public.n hk as ⟨b, hb⟩
    step as ⟨em_bits, hemb⟩
    have hemb' : em_bits.val = (keyN key).size - 1 := by rw [hemb, hb]
    unfold core.num.Usize.div_ceil
    simp only [show ¬ (8#usize).val = 0 by decide, _root_.dite_false, bind_ok]
    step as ⟨em1, _b, hem1, hem1l, _⟩
    have hemL : em1.length = ((keyN key).size - 1 + 7) / 8 := by rw [hem1l, hemb']; omega
    step with digest_as_ref_spec d as ⟨sh, hshl, hshv⟩
    rw [hdl] at hshl
    step with pss_salt_len_of salt em1.len sh.len (by show sh.length ≤ 64; omega)
      (by show em1.length ≤ 1024; rw [hemL]; unfold keyN; omega) as ⟨sl, hslv, hslb⟩
    have hslv' : sl.val = pssSaltLen (((keyN key).size - 1 + 7) / 8) L salt := by
      rw [hslv, show em1.len.val = em1.length from rfl, hemL, show sh.len.val = sh.length from rfl, hshl]
    have hHL := hs.out.2.2.2.2
    step with encode_pss_sig_spec hs hnew hL hmax _ hd () em1 em_bits (by rw [hemL, hemb'])
      (by rw [hemL]; unfold keyN; omega) sh (bv message.val) (by rw [hshv, hdv]) sl hslb as ⟨r, em2, hr⟩
    rcases r with ⟨⟩ | e
    · obtain ⟨salt', hsl', henc⟩ := hr
      simp only [core.result.Result.Insts.CoreOpsTry.branch, bind_ok, low.ct.public_slice]
      obtain ⟨hEMl, hEMlt⟩ := emsaPssEncode_lt H L hL hHL _ _ _ _ henc
      rw [bv_length] at hEMl
      have hlt : beNat em2.val < keyN key := by
        rw [← os2ip_bv]
        calc _ < 2 ^ ((keyN key).size - 1) := by rw [← hemb']; exact hEMlt
          _ ≤ keyN key := two_pow_size_le _ (by unfold keyN; omega)
      have hem2L : em2.val.length ≤ 1024 := by rw [hEMl, hemb']; unfold keyN; omega
      step with posint_from_bytes_spec em2 (beNat_lt_8192 _ hem2L) as ⟨r, c, hr, hcu, hcz, hcv, _⟩
      subst hr
      simp only [bind_ok]
      step with private_op_spec havx t hadx hifma key hinv hPn hcrt c hcu hcz as ⟨r1, hr1⟩
      have henc' : emsaPssEncode H L (bv message.val) (bv salt') ((keyN key).size - 1) = some (bv em2.val) := by
        rw [← hemb']; exact henc
      have hsl'' : salt'.length = pssSaltLen (((keyN key).size - 1 + 7) / 8) L salt := by rw [hsl', hslv']
      cases r1 with
      | Err e =>
        simp only [PrivateOpResult] at hr1
        rcases hr1 with ⟨-, hge⟩ | ⟨rfl, -, hne⟩
        · exfalso; unfold keyN at hlt; rw [hcv] at hge; omega
        · simp only [core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual,
            core.convert.FromSame.from, bind_ok, bind_tc_ok]
          refine (WP.spec_ok _).mpr ?_
          simp only [WP.uncurry'_pair]
          exact Or.inr ⟨salt', hsl'', em2.val, henc', ⟨rfl, by rw [hcv] at hne; exact hne⟩, fun s h => nomatch h⟩
      | Ok sv =>
        obtain ⟨-, hsu, hsv, hchk⟩ := hr1
        simp only [low.ct.into_public, bind_ok]
        have hsN : wordsNat (lowWords sv sv.used) < keyN key := by
          rw [hsv]; exact keyRsasp1_lt key hinv _
        step with to_signature_spec key hinv.1 sv (by rw [hsu]; exact hk) hsN signature hroom
          as ⟨r2, sig', s, hr2, hsl, hsb, hsig'l, hsig'v⟩
        subst hr2
        refine Or.inr ⟨salt', hsl'', em2.val, henc', ?_,
          fun s' h => by injection h with h; subst h; exact ⟨hsig'l, hsig'v⟩⟩
        simp only [SignedAs]
        rw [← hcv, ← hsv, ← hsb, ← hsl, i2osp_beNat]
    · simp only [core.result.Result.Insts.CoreOpsTry.branch, bind_ok,
        core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual,
        core.convert.FromSame.from, bind_tc_ok]
      refine (WP.spec_ok _).mpr ?_
      simp only [WP.uncurry'_pair]
      left
      refine ⟨e, rfl, ?_⟩
      rcases hr with h | ⟨hl, he⟩
      · exact Or.inl h
      · right; refine ⟨he, ?_⟩; rw [hemL, hslv'] at hl; exact hl

end

/-- RSASSA-PSS-SIGN with SHA-256 and MGF1 with SHA-256: `sign_pss_sha256`
signs the EMSA-PSS encoding of `message` with a salt of the length `salt`
names, which the system random source drew, or refuses a salt too long for
the modulus, a failed draw, or what `private_op`'s fault check refuses. -/
theorem sign_pss_sha256_spec (h : Runs) (hb : Sha256Blocks) (hfill : Fills)
    (t : low.x86_64.cpu.HaveBmi2Adx) (hadx : low.x86_64.cpu.HaveBmi2Adx.check = ok (some t))
    (hifma : IfmaCheckReturns) (key : high.rsa.SigningKey) (hinv : PrivKeyInv key)
    (hPn : MontProducts key.public.n.used.val)
    (hcrt : key.ifma.w = 0#usize → MontProducts key.p.used.val ∧
      (key.p.used.val = 16 ∨ key.p.used.val = 32) ∧ NoRsazPair key.p.used.val)
    (salt : high.rsa.PssSalt) (signature message : Slice U8) (hm : message.length ≤ maxInput)
    (hroom : octetLen (keyN key) ≤ signature.length) :
    high.rsa.SigningKey.sign_pss_sha256 key salt signature message ⦃ r sig' =>
      (∃ e, r = .Err e ∧ (e = .RngFailed ∨ (e = .KeyRejected .RsaModulus ∧
        ((keyN key).size - 1 + 7) / 8 < 32 + pssSaltLen (((keyN key).size - 1 + 7) / 8) 32 salt + 2))) ∨
      ∃ salt' : List U8, salt'.length = pssSaltLen (((keyN key).size - 1 + 7) / 8) 32 salt ∧
        ∃ EM : List U8, emsaPssEncode sha256.hash 32 (bv message.val) (bv salt') ((keyN key).size - 1) =
            some (bv EM) ∧
          SignedAs key EM r ∧ ∀ s, r = .Ok s → sig'.length = signature.length ∧ sig'.val.take s.length = s.val ⦄ := by
  unfold high.rsa.SigningKey.sign_pss_sha256
  step with new_secret_spec h
  exact sign_pss_core_spec (sha256_hashSpec hb) sha256_ctx_new_spec (by decide) maxInput_ge (system_draws hfill)
    h.2.2.2 t hadx hifma key hinv hPn hcrt salt signature message hm hroom

/-! ## Loading a signing key -/

/-- `from_secret_bytes`'s check of the bytes beyond its width: whether those
read so far are all zero. -/
theorem from_secret_bytes_loop0_spec (bytes : Slice U8) (iter : core.ops.range.Range Usize)
    (hend : iter.end.val ≤ bytes.length) (hstart : iter.start.val ≤ iter.end.val) (high : U8)
    (hhigh : high.val = 0 ↔ ∀ x ∈ bytes.val.take iter.start.val, x = 0#u8) :
    low.posint.PosInt.from_secret_bytes_loop0 iter bytes high ⦃ a =>
      a.val = 0 ↔ ∀ x ∈ bytes.val.take iter.end.val, x = 0#u8 ⦄ := by
  unfold low.posint.PosInt.from_secret_bytes_loop0
  apply loop.spec_decr_nat (fun x => x.1.end.val - x.1.start.val)
    (fun x : core.ops.range.Range Usize × U8 => x.1.end = iter.end ∧ x.1.start.val ≤ x.1.end.val ∧
      (x.2.val = 0 ↔ ∀ y ∈ bytes.val.take x.1.start.val, y = 0#u8))
  · rintro ⟨it, a⟩ ⟨he, hs, ha⟩
    simp only at he hs ha
    have h2 : it.end.val = iter.end.val := by rw [he]
    have hbL : bytes.length = bytes.val.length := rfl
    unfold low.posint.PosInt.from_secret_bytes_loop0.body
    step as ⟨o, iter1, ho, hend1⟩
    cases o with
    | none =>
      have : it.start.val = iter.end.val := by
        split at ho
        · simp at ho
        · omega
      simp only [WP.spec_ok]
      rw [ha, this]
    | some i =>
      have hlt : it.start.val < it.end.val := by
        by_contra hc; simp [hc] at ho
      simp only [hlt, ↓reduceIte, Option.some.injEq] at ho
      obtain ⟨rfl, hst⟩ := ho
      have h3 : iter1.end.val = it.end.val := by rw [hend1]
      step as ⟨b, hb⟩
      step as ⟨a1, ha1⟩
      refine ⟨by rw [hend1, he], by omega, ?_, by omega⟩
      rw [ha1, UScalar.val_or, Nat.or_eq_zero_iff, ha, hst, List.take_add_one,
        List.getElem?_eq_getElem (by omega)]
      simp only [Option.toList_some, List.mem_append, List.mem_singleton]
      constructor
      · rintro ⟨h1, h2⟩ y (hy | rfl)
        · exact h1 y hy
        · rw [← hb]; simpa [UScalar.eq_equiv] using h2
      · intro h
        refine ⟨fun y hy => h y (Or.inl hy), ?_⟩
        have := h _ (Or.inr rfl)
        rw [← hb] at this
        simpa [UScalar.eq_equiv] using this
  · exact ⟨rfl, hstart, hhigh⟩

theorem from_secret_bytes_loop1_eq {N : Usize} :
    @low.posint.PosInt.from_secret_bytes_loop1 N = @low.posint.PosInt.from_secret_bytes_loop2 N := by
  funext iter bytes r len
  rfl

/-- A number below `256^len` fills at most `⌈len / 8⌉` words: those above
are zero. -/
theorem clean_of_lt {N : Usize} (p : low.posint.PosInt N) (len : Nat) (hu : p.used.val = (len + 7) / 8)
    (hv : wordsNat p.words.val < 256 ^ len) : PrivKey.Clean p := by
  unfold PrivKey.Clean lowWords
  rw [wordsNat_take_mod]
  symm
  apply Nat.mod_eq_of_lt
  calc _ < 256 ^ len := hv
    _ = 2 ^ (8 * len) := by rw [pow_mul]; norm_num
    _ ≤ 2 ^ (64 * p.used.val) := Nat.pow_le_pow_right (by norm_num) (by omega)

/-- `from_secret_bytes` reads big-endian bytes as the number they encode, in
at most its `N` words, with nothing above its width. -/
theorem from_secret_bytes_gen_spec (N : Usize) (hN : N.val ≤ 128) (bytes : Slice U8) :
    low.posint.PosInt.from_secret_bytes N bytes ⦃ r => ∀ p, r = .Ok p →
      p.used.val ≤ N.val ∧ PrivKey.Clean p ∧ wordsNat (lowWords p p.used) = beNat bytes.val ⦄ := by
  unfold low.posint.PosInt.from_secret_bytes low.posint.PosInt.zero
  step as ⟨i1, hi1⟩
  have hbl : bytes.length = bytes.val.length := rfl
  have hbn : bytes.len.val = bytes.length := rfl
  split
  · rename_i hgt
    have hgt' : 8 * N.val < bytes.length := by
      have : (Slice.len bytes).val > i1.val := hgt; simp at this; omega
    step as ⟨excess, hex⟩
    step with from_secret_bytes_loop0_spec bytes { start := 0#usize, «end» := excess } (by simp; omega)
      (by simp) 0#u8 (by simp) as ⟨high, hhigh⟩
    simp only [lift, core.cmp.impls.PartialEqU8.eq, bind_ok, low.ct.into_public]
    split
    · rename_i hz
      have hz' : ∀ x ∈ bytes.val.take excess.val, x = 0#u8 := by
        rw [← hhigh]; simpa [UScalar.eq_equiv] using hz
      step as ⟨bytes1, hb1v, hb1l⟩
      rw [from_secret_bytes_loop1_eq]
      have hl1 : bytes1.val.length = 8 * N.val := by
        have := hb1l; have : bytes1.length = bytes1.val.length := rfl; scalar_tac
      step with from_secret_bytes_loop2_spec bytes1 (Slice.len bytes1) (by simp) (by simp; omega)
        { start := 0#usize, «end» := Slice.len bytes1 } rfl (by simp)
        { words := Array.repeat N 0#u64, used := 0#usize }
        (by rw [Array.repeat_val, wordsNat_replicate_zero]; simp [beNat, leNat]) as ⟨r1, hu, hv⟩
      unfold core.num.Usize.div_ceil
      simp only [show ¬ (8#usize).val = 0 by decide, _root_.dite_false, bind_ok, WP.spec_ok]
      rintro p ⟨⟩
      have hv' : wordsNat r1.words.val = beNat bytes.val := by
        rw [hv, hb1v, beNat_drop_zeros _ _ hz']
      set q : low.posint.PosInt N :=
        { words := r1.words, used := UScalar.ofNatCore ((bytes1.len.val + (8#usize : Usize).val - 1) / (8#usize : Usize).val) (by scalar_tac) } with hq
      have hqu : q.used.val = (bytes1.val.length + 7) / 8 := by
        rw [hq, UScalar.ofNatCore_val_eq]; rfl
      have hqc : PrivKey.Clean q := clean_of_lt q bytes1.val.length hqu (by rw [hq]; dsimp only; rw [hv]; exact beNat_lt _)
      refine ⟨by rw [hqu, hl1]; omega, hqc, ?_⟩
      rw [← hqc]
      exact hv'
    · simp
  · rename_i hle
    have hle' : bytes.length ≤ 8 * N.val := by
      have : ¬ (Slice.len bytes).val > i1.val := hle; simp at this; omega
    step with from_secret_bytes_loop2_spec bytes (Slice.len bytes) (by simp) (by simp; omega)
      { start := 0#usize, «end» := Slice.len bytes } rfl (by simp)
      { words := Array.repeat N 0#u64, used := 0#usize }
      (by rw [Array.repeat_val, wordsNat_replicate_zero]; simp [beNat, leNat]) as ⟨r1, hu, hv⟩
    unfold core.num.Usize.div_ceil
    simp only [show ¬ (8#usize).val = 0 by decide, _root_.dite_false, bind_ok, WP.spec_ok]
    rintro p ⟨⟩
    set q : low.posint.PosInt N :=
      { words := r1.words, used := UScalar.ofNatCore ((bytes.len.val + (8#usize : Usize).val - 1) / (8#usize : Usize).val) (by scalar_tac) } with hq
    have hqu : q.used.val = (bytes.val.length + 7) / 8 := by
      rw [hq, UScalar.ofNatCore_val_eq]; rfl
    have hqc : PrivKey.Clean q := clean_of_lt q bytes.val.length hqu (by rw [hq]; dsimp only; rw [hv]; exact beNat_lt _)
    refine ⟨by rw [hqu]; omega, hqc, ?_⟩
    rw [← hqc]
    exact hv

/-- `from_unsigned`'s `secret` reads a private component as `from_secret_bytes`
does. -/
theorem secret_spec (N : Usize) (hN : N.val ≤ 128) (x : Slice U8) (err : error.KeyFormatError) :
    high.rsa.SigningKey.from_unsigned.secret N x err ⦃ r => ∀ p, r = .Ok p →
      p.used.val ≤ N.val ∧ PrivKey.Clean p ∧ wordsNat (lowWords p p.used) = beNat x.val ⦄ := by
  unfold high.rsa.SigningKey.from_unsigned.secret
  step with from_secret_bytes_gen_spec N hN x as ⟨r, hr⟩
  rcases r with p | e
  · simp only [core.result.Result.map_err, WP.spec_ok]
    rintro p' ⟨⟩
    exact hr p rfl
  · simp [core.result.Result.map_err,
      high.rsa.SigningKey.from_unsigned.secret.closure.Insts.CoreOpsFunctionFnOnceTupleErrorKeyFormatError.call_once]

/-- `key` is the private key `RsaPrivateKey::new` loaded from the big-endian
components `c`: it meets `PrivKeyInv`, works at the wider prime's width, and
holds the components, which meet RFC 8017's relations but for the primes'
primality. -/
def KeyFrom (c : high.rsa.Components) (key : mid.rsa_priv.RsaPrivateKey) : Prop :=
  PrivKeyInv key ∧ keyN key = beNat c.n.val ∧ key.public.e.val = beNat c.e.val ∧
    wordsNat (lowWords key.d key.d.used) = beNat c.d.val ∧
    wordsNat (lowWords key.p key.p.used) = beNat c.p.val ∧
    wordsNat (lowWords key.q key.p.used) = beNat c.q.val ∧
    wordsNat (lowWords key.dp key.dp.used) = beNat c.dp.val ∧
    wordsNat (lowWords key.dq key.dq.used) = beNat c.dq.val ∧
    wordsNat (lowWords key.iqmp key.p.used) = beNat c.qi.val ∧
    key.p.used.val = keyWords (beNat c.p.val) (beNat c.q.val) ∧
    CrtRelations (beNat c.n.val) (beNat c.p.val) (beNat c.q.val) (beNat c.d.val) (beNat c.dp.val)
      (beNat c.dq.val) (beNat c.qi.val) (beNat c.e.val)

set_option maxHeartbeats 1000000 in
/-- `SigningKey::from_unsigned` returns only a key it loaded from its
components. -/
theorem from_unsigned_priv_spec (hrun : Runs) (h : low.entry.Entry.assert_held = ok ())
    (hifma : IfmaCheckReturns) (hfp16 : ∀ t, ∃ b, low.x86_64.cpu.HaveAvx512ForRsa.fp16 t = ok b)
    (c : high.rsa.Components) (hP : MontProducts (keyWords (beNat c.p.val) (beNat c.q.val))) :
    high.rsa.SigningKey.from_unsigned c ⦃ r => ∀ key, r = .Ok key → KeyFrom c key ⦄ := by
  unfold high.rsa.SigningKey.from_unsigned
  by_cases hN : beNat c.n.val < 2 ^ 8192
  · step with posint_from_bytes_spec c.n hN as ⟨r, n, hr, hnu, hnz, hnv, hnt⟩
    subst hr
    simp only [core.result.Result.map_err, core.result.Result.Insts.CoreOpsTry.branch, bind_ok]
    step with public_exponent_spec c.e as ⟨r2, hr2a, hr2b⟩
    rcases r2 with e | err
    · have hev : e.val = beNat c.e.val := by
        by_cases hel : c.e.length ≤ 8
        · obtain ⟨v, hv, hvv⟩ := hr2a hel; cases hv; exact hvv
        · obtain ⟨err, h⟩ := hr2b (by omega); cases h
      simp only [bind_ok]
      step with secret_spec 64#usize (by decide) c.p _ as ⟨r3, hr3⟩
      rcases r3 with p | err
      swap
      · simp [core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual,
          error.Error.Insts.CoreConvertFromKeyFormatError.from, core.convert.FromSame.from]
      obtain ⟨hpu, hpc, hpv⟩ := hr3 p rfl
      simp only [bind_ok]
      step with secret_spec 64#usize (by decide) c.q _ as ⟨r4, hr4⟩
      rcases r4 with q | err
      swap
      · simp [core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual,
          error.Error.Insts.CoreConvertFromKeyFormatError.from, core.convert.FromSame.from]
      obtain ⟨hqu, hqc, hqv⟩ := hr4 q rfl
      simp only [bind_ok]
      step with secret_spec 128#usize (by decide) c.d _ as ⟨r5, hr5⟩
      rcases r5 with d | err
      swap
      · simp [core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual,
          error.Error.Insts.CoreConvertFromKeyFormatError.from, core.convert.FromSame.from]
      obtain ⟨hdu, hdc, hdv⟩ := hr5 d rfl
      simp only [bind_ok]
      step with secret_spec 64#usize (by decide) c.dp _ as ⟨r6, hr6⟩
      rcases r6 with dp | err
      swap
      · simp [core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual,
          error.Error.Insts.CoreConvertFromKeyFormatError.from, core.convert.FromSame.from]
      obtain ⟨hdpu, hdpc, hdpv⟩ := hr6 dp rfl
      simp only [bind_ok]
      step with secret_spec 64#usize (by decide) c.dq _ as ⟨r7, hr7⟩
      rcases r7 with dq | err
      swap
      · simp [core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual,
          error.Error.Insts.CoreConvertFromKeyFormatError.from, core.convert.FromSame.from]
      obtain ⟨hdqu, hdqc, hdqv⟩ := hr7 dq rfl
      simp only [bind_ok]
      step with secret_spec 64#usize (by decide) c.qi _ as ⟨r8, hr8⟩
      rcases r8 with qi | err
      swap
      · simp [core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual,
          error.Error.Insts.CoreConvertFromKeyFormatError.from, core.convert.FromSame.from]
      obtain ⟨hiu, hic, hiv⟩ := hr8 qi rfl
      simp only [bind_ok]
      step with rsa_private_key_new_spec hrun h hifma hfp16 p q dp dq qi d n e hpu hqu hdpu hdqu hiu hdu hnu
        hpc hqc hdpc hdqc hic (by rw [hnv]; exact hnt) (by rw [hpv, hqv]; exact hP) as ⟨r9, hr9⟩
      rcases r9 with key | err
      swap
      · simp [core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual,
          core.convert.FromSame.from]
      simp only [bind_ok, WP.spec_ok]
      rintro key' ⟨⟩
      obtain ⟨hinv, hn, he, hpw, hpv', hqv', hdv', hdpv', hdqv', hiv', hcrt⟩ := hr9
      rw [hpv, hqv, hdv, hdpv, hdqv, hiv, hnv, hev] at hcrt
      refine ⟨hinv, ?_, by rw [he, hev], by rw [hdv', hdv], by rw [hpv', hpv], by rw [hqv', hqv],
        by rw [hdpv', hdpv], by rw [hdqv', hdqv], by rw [hiv', hiv], by rw [hpw, hpv, hqv], hcrt⟩
      unfold keyN; rw [hn, hnv]
    · simp [core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual,
        error.Error.Insts.CoreConvertFromKeyFormatError.from, core.convert.FromSame.from]
  · step with posint_from_bytes_long_spec c.n (by omega) as ⟨r, err, hr⟩
    rw [hr]
    simp [core.result.Result.map_err, core.result.Result.Insts.CoreOpsTry.branch,
      core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual,
      error.Error.Insts.CoreConvertFromKeyFormatError.from,
      high.rsa.SigningKey.from_unsigned.closure.Insts.CoreOpsFunctionFnOnceTupleErrorKeyFormatError.call_once]

/-- `SigningKey::from_components` returns only a key it loaded from its
components. -/
theorem signing_from_components_spec (hrun : Runs) (h : low.entry.Entry.assert_held = ok ())
    (hifma : IfmaCheckReturns) (hfp16 : ∀ t, ∃ b, low.x86_64.cpu.HaveAvx512ForRsa.fp16 t = ok b)
    (c : high.rsa.Components) (hP : MontProducts (keyWords (beNat c.p.val) (beNat c.q.val))) :
    high.rsa.SigningKey.from_components c ⦃ r => ∀ key, r = .Ok key → KeyFrom c key ⦄ := by
  unfold high.rsa.SigningKey.from_components
  step with new_secret_spec hrun
  simp only [core.slice.Slice.first, core.option.Option.Insts.CoreCmpPartialEqOption.eq, bind_ok]
  apply WP.spec_bind (Pₘ := fun _ => True)
  · split <;> simp_all [core.cmp.impls.PartialEqShared.eq]
  intro b _
  split
  · simp [error.Error.Insts.CoreConvertFromKeyFormatError.from]
  apply WP.spec_bind (Pₘ := fun _ => True)
  · split <;> simp_all [core.cmp.impls.PartialEqShared.eq]
  intro b1 _
  split
  · simp [error.Error.Insts.CoreConvertFromKeyFormatError.from]
  exact from_unsigned_priv_spec hrun h hifma hfp16 c hP

/-- A private key's public key is a copy of its own. -/
theorem priv_public_key_spec (key : mid.rsa_priv.RsaPrivateKey) :
    mid.rsa_priv.RsaPrivateKey.public_key key ⦃ vk => vk = key.public ⦄ := by
  unfold mid.rsa_priv.RsaPrivateKey.public_key mid.rsa_pub.RsaPublicKey.Insts.CoreCloneClone.clone
  step with clone_spec as ⟨n, hn⟩
  simp only [lift, core.clone.impls.CloneU64.clone, bind_ok]
  step with clone_spec as ⟨m, hm⟩
  subst hn hm
  simp only

/-- A signing key's public key is its own. -/
theorem signing_public_key_spec (hrun : Runs) (key : high.rsa.SigningKey) :
    high.rsa.SigningKey.public_key key ⦃ vk => vk = key.public ⦄ := by
  unfold high.rsa.SigningKey.public_key
  step with new_public_spec hrun
  step with priv_public_key_spec key as ⟨vk, hvk⟩
  exact hvk

/-- A signing key's modulus's length in bytes. -/
theorem signing_modulus_len_bytes_spec (hrun : Runs) (key : high.rsa.SigningKey) (hinv : PubKeyInv key.public) :
    high.rsa.SigningKey.modulus_len_bytes key ⦃ k => k.val = octetLen (keyN key) ⦄ := by
  unfold high.rsa.SigningKey.modulus_len_bytes
  step with new_public_spec hrun
  step with priv_public_key_spec key as ⟨vk, hvk⟩
  subst hvk
  exact modulus_len_bytes_spec key.public hinv

/-- A public key meeting `PubKeyInv` is the RSA public key its modulus and
exponent are, in exactly the modulus's words. -/
theorem keyLoaded_of_inv (key : mid.rsa_pub.RsaPublicKey) (hinv : PubKeyInv key) :
    KeyLoaded key (wordsNat (lowWords key.n key.n.used)) key.e.val := by
  refine ⟨hinv, rfl, rfl, ?_⟩
  obtain ⟨hk2, hk, -, -, -, -, -, -, -, htop⟩ := hinv
  have hlt := wordsNat_lt' (lowWords key.n key.n.used)
  rw [lowWords_length _ hk] at hlt
  have h1 := (Nat.size_le).mpr hlt
  have h2 : ¬ (wordsNat (lowWords key.n key.n.used)).size ≤ 64 * (key.n.used.val - 1) := by
    rw [Nat.size_le]; omega
  omega

end rind.x86_64
