import Rind.Aarch64.P256Ecdsa
import Rind.Aarch64.Ed25519
open Aeneas Aeneas.Std Result rind.spec

/-!
# P-256 ECDSA through the signature API

The `p256_ecdsa_*` theorems state what the signature API returns for
`ECDSA_P256_SHA256_FIXED`, in terms of `Rind.Spec`'s ECDSA, through the
dispatch `Rind.Aarch64.EcdsaDispatch` models, with SHA-256 as
`Rind.Aarch64.Hmac` states it.
-/

namespace rind.aarch64

open P256

/-- `b` is X9.62's uncompressed encoding of `d` times the generator. -/
def p256PublicKey (d : Nat) (b : List U8) : Prop :=
  b.length = 65 ∧ b.head? = some 4#u8 ∧ p256Pow p256G d = some (x962Coords b)

/-- A signing key whose private scalar is `d`, in [1, n), and whose public key
is `d`'s. -/
def SigningKeyOf (key : P256SigningKey) (d : Nat) : Prop :=
  scNat key.private_key.scalar = d ∧ 0 < d ∧ d < n256 ∧ key.public_key_len.val = 65 ∧
    p256PublicKey d (key.public_key.val.take 65)

namespace P256

theorem static_public_key_uncompressed_spec (hG : P256Laws) (h : Runs) (k : mid.p256.StaticPrivateKey)
    (hk0 : 0 < scNat k.scalar) (hk : scNat k.scalar < n256) :
    mid.p256.StaticPrivateKey.public_key_uncompressed k ⦃ b => p256PublicKey (scNat k.scalar) b.val ⦄ := by
  obtain ⟨x, y, hq, hc⟩ := g_mult hG _ hk0 hk
  have := public_key_uncompressed_spec h k x y hq hc
  refine WP.spec_mono this fun b ⟨h4, hxy⟩ => ⟨b.property, h4, ?_⟩
  rw [hq, hxy]

theorem signing_new_spec (hG : P256Laws) (h : Runs) (k : mid.p256.StaticPrivateKey)
    (hk0 : 0 < scNat k.scalar) (hk : scNat k.scalar < n256) :
    high.ecdsa.SigningKey.new P256C k ⦃ r => ∃ key, r = .Ok key ∧ SigningKeyOf key (scNat k.scalar) ⦄ := by
  unfold high.ecdsa.SigningKey.new
  simp only [mid.p256.StaticPrivateKey.Insts.RindHighCurvePrivateKeyScalar.public_key_encode_uncompressed]
  step*
  have hsl : s.length = 133 := by simp [Slice.length, s_post, Array.repeat]
  simp only [mid.p256.PublicKey.BYTES, mid.p256.FieldElement.BYTES, core.slice.Slice.get_mut,
    core.slice.index.SliceIndexRangeUsizeSlice.get_mut]
  step*
  rw [if_pos (by simp [hsl]; scalar_tac)]
  simp only [bind_ok]
  step with static_public_key_uncompressed_spec hG h k hk0 hk as ⟨a, ha⟩
  have hx : x.val = 65 := by scalar_tac
  have ha65 : a.val.length = 65 := a.property
  have hcp : core.slice.Slice.copy_from_slice core.marker.CopyU8
      (Slice.from (List.slice (0#usize).val x.val s.val) (by simp [List.slice] <;> scalar_tac)) a.to_slice =
      ok a.to_slice := by
    simp [core.slice.Slice.copy_from_slice, Slice.len, List.slice, hx, hsl, ha65]
  simp only [lift, bind_ok, hcp, core.result.Result.Insts.CoreOpsTry.branch, WP.spec_ok]
  have hl : a.to_slice.length = x.val - (0#usize).val := by simp [Slice.length, hx, ha65]
  refine ⟨_, rfl, rfl, hk0, hk, by simp [ha65], ?_⟩
  simp only [hl, ↓reduceDIte, to_slice_mut_back_post]
  have hs : s.val.length = 133 := hsl
  rw [Array.from_slice_val _ _ (by simp [hs])]
  have := take_setSlice! s.val a.val 0 (by omega)
  simp only [Nat.zero_add, List.take_zero, List.nil_append, ha65] at this
  simpa [this] using ha

/-- The system source's draws: `getrandom::fill`'s failure is `RngFailed`. -/
theorem system_draws (hfill : Fills) : Draws mid.rng.SystemRandom.Insts.RindMidRngRandomSource := by
  sorry

theorem signing_generate_spec (hG : P256Laws) (h : Runs) (hfill : Fills) :
    high.ecdsa.SigningKey.generate P256C ⦃ r =>
      (∀ key, r = .Ok key → ∃ d, SigningKeyOf key d) ∧ ∀ e, r = .Err e → e = .RngFailed ⦄ := by
  sorry

theorem public_key_bytes_spec (key : P256SigningKey) (hl : key.public_key_len.val = 65) :
    high.ecdsa.SigningKey.public_key_uncompressed P256C key ⦃ s =>
      s.val = key.public_key.val.take 65 ⦄ := by
  sorry

theorem split_first_spec {T : Type} (s : Slice T) :
    core.slice.Slice.split_first s ⦃ o =>
      match s.val with
      | [] => o = none
      | x :: rest => ∃ t : Slice T, o = some (x, t) ∧ t.val = rest ⦄ := by
  sorry

end P256

/-- X9.62's compressed encoding of the point whose uncompressed encoding is
`b`: 2 or 3 by the parity of y's last byte, then x. -/
def x962Compress (b : List U8) : List U8 :=
  (2#u8 ||| (b.getLastD 0#u8 &&& 1#u8)) :: b.slice 1 33

namespace P256

theorem is_public_key_spec (key : P256SigningKey) (hl : key.public_key_len.val = 65)
    (h4 : (key.public_key.val.take 65).head? = some 4#u8) (enc : Slice U8) :
    high.ecdsa.SigningKey.is_public_key P256C key enc ⦃ b =>
      b ↔ enc.val = key.public_key.val.take 65 ∨ enc.val = x962Compress (key.public_key.val.take 65) ⦄ := by
  sorry

theorem from_scalar_spec (hG : P256Laws) (h : Runs) (sk pk : Slice U8) :
    high.ecdsa.SigningKey.from_private_key_and_public_key P256C sk pk ⦃ r =>
      if sk.length ≠ 32 then r = .Err (.KeyRejected .WrongLength)
      else if 0 < beNat sk.val ∧ beNat sk.val < n256 then
        ∃ b, p256PublicKey (beNat sk.val) b ∧
          if pk.val = b ∨ pk.val = x962Compress b then ∃ key, r = .Ok key ∧ SigningKeyOf key (beNat sk.val)
          else r = .Err (.KeyRejected .MismatchedPublicKey)
      else r = .Err (.KeyRejected .ScalarOutOfRange) ⦄ := by
  sorry

/-- `Buffer::copy_from` of bytes that fit. -/
theorem copy_from_spec (N : Usize) (bytes : Slice U8) (hN : bytes.length ≤ N.val) :
    high.signature.Buffer.copy_from N bytes ⦃ r => ∃ b, r = .Ok b ∧ b.len.val = bytes.length ∧
      b.bytes.val.take bytes.length = bytes.val ⦄ := by
  sorry

end P256

/-- A key pair whose private scalar is `d`, for ECDSA on P-256 with SHA-256
and fixed-length signatures. -/
def EcdsaKeyPairOf (kp : high.signature.EcdsaKeyPair) (d : Nat) : Prop :=
  ∃ signing verifying, kp.key = .P256Sha256Fixed signing verifying ∧ SigningKeyOf signing d ∧
    VKey (p256Pow p256G d) verifying.public_key ∧ kp.point.len.val = 65 ∧
    kp.point.bytes.val.take 65 = signing.public_key.val.take 65

namespace P256

theorem load_tail_spec (hG : P256Laws) (h : Runs) (hheld : Held) (hc : Cached)
    (signing : P256SigningKey) (d : Nat) (hs : SigningKeyOf signing d) :
    (do
      let pk ← high.ecdsa.SigningKey.public_key_uncompressed P256C signing
      let point ← high.signature.Buffer.copy_from 133#usize pk
      match point with
      | .Err e => ok (core.result.Result.Err e)
      | .Ok point =>
        let s ← high.signature.Buffer.Insts.CoreConvertAsRefSliceU8.as_ref point
        let verifying ← high.ecdsa.VerifyingKey.from_x962_uncompressed P256C s
        match verifying with
        | .Err e => ok (core.result.Result.Err e)
        | .Ok verifying => ok (core.result.Result.Ok
            ({ key := .P256Sha256Fixed signing verifying, point } : high.signature.EcdsaKeyPair)) :
      Result (core.result.Result high.signature.EcdsaKeyPair error.Error)) ⦃ r =>
      ∃ kp, r = .Ok kp ∧ EcdsaKeyPairOf kp d ⦄ := by
  sorry

end P256

open Classical in
/-- An ECDSA verification's result: accepted exactly when `sig` is 64 bytes,
the big-endian r and s of a valid signature of `e` under `Q`. -/
def ecdsaVerdict (Q : P256Point) (e : Nat) (sig : List U8) (r : core.result.Result Unit error.Error) : Prop :=
  r = if sig.length = 64 ∧ ecdsaP256Verifies Q e (beNat (sig.take 32)) (beNat (sig.drop 32)) then .Ok ()
    else .Err .BadSignature

/-- `e` is the integer ECDSA signs for `msg`: the SHA-256 digest rind's impl
computes, whose first 32 bytes are read big-endian, mod n. `sha256_hash`
proves that digest FIPS 180-4's, in a module P-256's cannot import, as their
specs share names. -/
def Sha256E (msg : Slice U8) (e : Nat) : Prop :=
  ∃ d dg, Sha256Sig.HashInst.hash msg = ok d ∧
    high.digest.Digest.Insts.CoreConvertAsRefSliceU8.as_ref d = ok dg ∧ 32 ≤ dg.length ∧
    e = beNat (dg.val.take 32) % n256

/-! ## The signature API, `high::signature`, through the modelled dispatch -/

/-- A generated key pair's private scalar is in [1, n), drawn from the system
random source, and generation is refused only if the draws fail. The draws
themselves are outside the functional spec. -/
theorem p256_ecdsa_generate (hG : P256Laws) (h : Runs) (hheld : Held) (hc : Cached) (hfill : Fills) :
    high.signature.EcdsaKeyPair.generate high.signature.sign.ECDSA_P256_SHA256_FIXED ⦃ r =>
      (∀ kp, r = .Ok kp → ∃ d, EcdsaKeyPairOf kp d) ∧ ∀ e, r = .Err e → e = .RngFailed ⦄ := by
  sorry

open Classical in
/-- A key pair loaded from a private scalar and the public key it claims:
refused unless the scalar is 32 bytes, in [1, n), and the public key is its
uncompressed or compressed encoding, and otherwise its private scalar is the
scalar. -/
theorem p256_ecdsa_from_private_key_and_public_key (hG : P256Laws) (h : Runs) (hheld : Held)
    (hc : Cached) (sk pk : Slice U8) :
    high.signature.EcdsaKeyPair.from_private_key_and_public_key high.signature.sign.ECDSA_P256_SHA256_FIXED
      sk pk ⦃ r =>
      if sk.length ≠ 32 then r = .Err (.KeyRejected .WrongLength)
      else if 0 < beNat sk.val ∧ beNat sk.val < n256 then
        ∃ b, p256PublicKey (beNat sk.val) b ∧
          if pk.val = b ∨ pk.val = x962Compress b then ∃ kp, r = .Ok kp ∧ EcdsaKeyPairOf kp (beNat sk.val)
          else r = .Err (.KeyRejected .MismatchedPublicKey)
      else r = .Err (.KeyRejected .ScalarOutOfRange) ⦄ := by
  sorry

/-- A signature's bytes, if signing returns: the big-endian r and s of the
ECDSA signature of `msg`'s SHA-256 under the key pair's scalar, for some
nonce in [1, n), neither zero. Signing is refused only if the nonce's random
input cannot be drawn. The nonces, RFC 6979's hedged with that input, are
outside the functional spec. -/
theorem p256_ecdsa_sign (hG : P256Laws) (h : Runs) (hdrbg : Drbg) (hfill : Fills)
    (kp : high.signature.EcdsaKeyPair) (d : Nat) (hkp : EcdsaKeyPairOf kp d) (msg : Slice U8) (e : Nat)
    (he : Sha256E msg e) :
    high.signature.EcdsaKeyPair.sign kp msg ⦃ r =>
      (∀ sig, r = .Ok sig → high.signature.Signature.Insts.CoreConvertAsRefSliceU8.as_ref sig ⦃ b =>
        b.length = 64 ∧ ∃ k, 0 < k ∧ k < n256 ∧
          ecdsaP256Sign d k e = some (beNat (b.val.take 32), beNat (b.val.drop 32)) ∧
          beNat (b.val.take 32) ≠ 0 ∧ beNat (b.val.drop 32) ≠ 0 ⦄) ∧
      ∀ err, r = .Err err → err = .RngFailed ⦄div := by
  sorry

/-- A key pair's public key's bytes: X9.62's uncompressed encoding of its
scalar times the generator. -/
theorem p256_ecdsa_key_pair_public_key (hc : Cached) (kp : high.signature.EcdsaKeyPair) (d : Nat)
    (hkp : EcdsaKeyPairOf kp d) :
    (do
      let pk ← high.signature.EcdsaKeyPair.impl.public_key kp
      high.signature.PublicKey.Insts.CoreConvertAsRefSliceU8.as_ref pk) ⦃ b =>
      p256PublicKey d b.val ⦄ := by
  sorry

/-- Verification with a key pair's public key: ECDSA's verification of
`msg`'s SHA-256 under its scalar times the generator. -/
theorem p256_ecdsa_key_pair_verify (hG : P256Laws) (h : Runs) (hc : Cached)
    (kp : high.signature.EcdsaKeyPair) (d : Nat) (hkp : EcdsaKeyPairOf kp d) (msg sig : Slice U8) (e : Nat)
    (he : Sha256E msg e) :
    (do
      let pk ← high.signature.EcdsaKeyPair.impl.public_key kp
      high.signature.PublicKey.verify pk msg sig) ⦃ r =>
      ecdsaVerdict (p256Pow p256G d) e sig.val r ⦄ := by
  sorry

/-- A P-256 public key parsed from its encoding: refused unless it is an
X9.62 uncompressed point on the curve, and otherwise its verification is
ECDSA's of a message's SHA-256 under that point. -/
theorem p256_ecdsa_public_key_new (hG : P256Laws) (h : Runs) (hheld : Held) (hc : Cached)
    (bytes : Slice U8) :
    high.signature.PublicKey.new high.signature.verify.ECDSA_P256_SHA256_FIXED bytes ⦃ r =>
      x962Outcome bytes.val (fun pk => ∀ (msg sig : Slice U8) (e : Nat), Sha256E msg e →
        high.signature.PublicKey.verify pk msg sig ⦃ v =>
          ecdsaVerdict (some (x962Coords bytes.val)) e sig.val v ⦄) r ⦄ := by
  sorry

end rind.aarch64
