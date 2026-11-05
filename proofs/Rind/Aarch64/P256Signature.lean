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
  rw [ite_eq_left (by simp [hsl]; scalar_tac)]
  simp only [bind_ok]
  step with static_public_key_uncompressed_spec hG h k hk0 hk as ⟨a, ha⟩
  have hx : x.val = 65 := by scalar_tac
  have ha65 : a.val.length = 65 := a.property
  have hcp : core.slice.Slice.copy_from_slice core.marker.CopyU8
      (Slice.from (List.slice (0#usize).val x.val s.val) (by simp [List.slice])) a.to_slice =
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
  intro rng s
  obtain ⟨⟨fr, fs⟩, hf⟩ := hfill s
  simp only [
    mid.rng.SystemRandom.Insts.RindMidRngRandomSource.fill, hf, bind_ok]
  rcases fr with _ | e <;>
    simp [core.result.Result.map_err,
      
      mid.rng.RandomSourceSystemRandom.fill.closure.Insts.CoreOpsFunctionFnOnceTupleErrorError.call_once]

theorem signing_generate_spec (hG : P256Laws) (h : Runs) (hfill : Fills) :
    high.ecdsa.SigningKey.generate P256C ⦃ r =>
      (∀ key, r = .Ok key → ∃ d, SigningKeyOf key d) ∧ ∀ e, r = .Err e → e = .RngFailed ⦄ := by
  unfold high.ecdsa.SigningKey.generate
  step with new_secret_spec h
  step with static_generate_spec h _ (system_draws hfill) () as ⟨rr, hrr⟩
  obtain ⟨hok, herr⟩ := hrr
  rcases rr with k | e
  · obtain ⟨hk0, hk⟩ := hok k rfl
    simp only [core.result.Result.Insts.CoreOpsTry.branch, bind_ok]
    apply WP.spec_mono (signing_new_spec hG h k hk0 hk)
    rintro r ⟨key, rfl, hkey⟩
    exact ⟨fun key' h' => by cases h'; exact ⟨_, hkey⟩, fun e h => nomatch h⟩
  · simpa [core.result.Result.Insts.CoreOpsTry.branch,
      core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual, core.convert.FromSame.from]
      using herr e rfl

theorem public_key_bytes_spec (key : P256SigningKey) (hl : key.public_key_len.val = 65) :
    high.ecdsa.SigningKey.public_key_uncompressed P256C key ⦃ s =>
      s.val = key.public_key.val.take 65 ⦄ := by
  unfold high.ecdsa.SigningKey.public_key_uncompressed
  have hl' : (key.public_key.val).length = 133 := key.public_key.property
  step*
  simp [s_post, List.slice, hl]

theorem split_first_spec {T : Type} (s : Slice T) :
    core.slice.Slice.split_first s ⦃ o =>
      match s.val with
      | [] => o = none
      | x :: rest => ∃ t : Slice T, o = some (x, t) ∧ t.val = rest ⦄ := by
  unfold core.slice.Slice.split_first
  split <;> rename_i h <;> simp [h]

end P256

theorem compress_tag (b : U8) : (2#u8 ||| (b &&& 1#u8)) = 2#u8 ∨ (2#u8 ||| (b &&& 1#u8)) = 3#u8 := by
  have : ∀ v : BitVec 8, (2#8 ||| (v &&& 1#8)) = 2#8 ∨ (2#8 ||| (v &&& 1#8)) = 3#8 := by decide
  rcases this b.bv with h | h
  · left; exact (UScalar.eq_equiv_bv_eq _ _).mpr h
  · right; exact (UScalar.eq_equiv_bv_eq _ _).mpr h

/-- X9.62's compressed encoding of the point whose uncompressed encoding is
`b`: 2 or 3 by the parity of y's last byte, then x. -/
def x962Compress (b : List U8) : List U8 :=
  (2#u8 ||| (b.getLastD 0#u8 &&& 1#u8)) :: b.slice 1 33

namespace P256

theorem is_public_key_spec (key : P256SigningKey) (hl : key.public_key_len.val = 65)
    (h4 : (key.public_key.val.take 65).head? = some 4#u8) (enc : Slice U8) :
    high.ecdsa.SigningKey.is_public_key P256C key enc ⦃ b =>
      b ↔ enc.val = key.public_key.val.take 65 ∨ enc.val = x962Compress (key.public_key.val.take 65) ⦄ := by
  have h133 : key.public_key.val.length = 133 := key.public_key.property
  obtain ⟨xy, hxy⟩ : ∃ xy, key.public_key.val.take 65 = 4#u8 :: xy := by
    revert h4
    cases key.public_key.val.take 65 with
    | nil => simp
    | cons a t => intro h4; simp at h4; exact ⟨t, by rw [h4]⟩
  have hxyl : xy.length = 64 := by
    have := congrArg List.length hxy; simp [h133] at this; omega
  rw [hxy]
  unfold high.ecdsa.SigningKey.is_public_key high.sec1.is_public_key
  step with public_key_bytes_spec key hl as ⟨s, hs⟩
  rw [hxy] at hs
  step with split_first_spec s as ⟨o, ho⟩
  rw [hs] at ho
  obtain ⟨t, rfl, ht⟩ := ho
  simp only
  step*
  have hi1 : i1.val = 32 := by
    rw [i1_post]; simp only [Slice.len_val]; rw [Slice.length, ht, hxyl]
  rw [hi1, ht] at x_post2 x_post3
  have hyne : (xy.drop 32) ≠ [] := by simp [hxyl]
  have hlast : (4#u8 :: xy).getLastD 0#u8 = (xy.drop 32).getLast hyne := by
    have hxne : xy ≠ [] := by intro h; simp [h] at hxyl
    rw [List.getLastD_eq_getLast?, List.getLast?_cons, List.getLast_drop, List.getLast?_eq_some_getLast hxne]
    rfl
  have hcomp : x962Compress (4#u8 :: xy) = (2#u8 ||| ((xy.drop 32).getLast hyne &&& 1#u8)) :: x.val := by
    rw [x962Compress, hlast, x_post2]; simp [List.slice]
  rw [hcomp]
  step with split_first_spec enc as ⟨o1, ho1⟩
  rcases he : enc.val with _ | ⟨tag, rest⟩
  · rw [he] at ho1
    subst ho1
    simp only
    step with slice_eq_spec enc s as ⟨b, hb⟩
    rw [hb, he, hs]; simp
  · rw [he] at ho1
    obtain ⟨cs, rfl, hcs⟩ := ho1
    simp only
    have hy : y.val.getLast? = some ((xy.drop 32).getLast hyne) := by
      rw [x_post3, List.getLast?_eq_some_getLast hyne]
    have h4ne2 : (4#u8 : U8) ≠ 2#u8 := by decide
    have h4ne3 : (4#u8 : U8) ≠ 3#u8 := by decide
    generalize (4#u8 : U8) = four at hs h4ne2 h4ne3 ⊢
    generalize hc : (2#u8 ||| (List.drop 32 xy).getLast hyne &&& 1#u8) = c
    have hcase : ∀ t : U8, t ≠ four →
        (do
          let b ← core.slice.cmp.PartialEqSlice.eq core.cmp.PartialEqU8 cs x
          if b = true then do
              let o2 ← core.slice.Slice.last y
              core.option.Option.is_some_and
                high.sec1.is_public_key.closure.Insts.CoreOpsFunctionFnOnceTupleShared0U8Bool
                o2 t
            else ok false) ⦃ b => b = true ↔ t :: rest = four :: xy ∨ t :: rest = c :: x.val ⦄ := by
      intro t ht
      step with slice_eq_spec cs x as ⟨b, hb⟩
      rw [hcs] at hb
      split
      · have hr : rest = x.val := hb.mp ‹_›
        simp only [core.slice.Slice.last, bind_ok, hy, core.option.Option.is_some_and,
          
          high.sec1.is_public_key.closure.Insts.CoreOpsFunctionFnOnceTupleShared0U8Bool.call_once,
          Shared0U8.Insts.CoreOpsBitBitAndU8U8.bitand, lift, WP.spec_ok, hc]
        simp [hr, ht]
      · have hr : rest ≠ x.val := fun h => ‹¬b = true› (hb.mpr h)
        simp [hr, ht]
    have hc23 : c = 2#u8 ∨ c = 3#u8 := hc ▸ compress_tag _
    conv => lhs; whnf
    split
    · exact hcase _ (fun h => h4ne2 (h ▸ UScalar.eq_of_val_eq rfl))
    · exact hcase _ (fun h => h4ne3 (h ▸ UScalar.eq_of_val_eq rfl))
    · rename_i hn2 hn3
      step with slice_eq_spec enc s as ⟨b, hb⟩
      rw [hb, he, hs]
      have hnc : tag ≠ c := by
        rintro rfl
        rcases hc23 with h | h
        · exact hn2 (h.trans (UScalar.eq_of_val_eq rfl))
        · exact hn3 (h.trans (UScalar.eq_of_val_eq rfl))
      simp [hnc]

theorem from_scalar_spec (hG : P256Laws) (h : Runs) (sk pk : Slice U8) :
    high.ecdsa.SigningKey.from_private_key_and_public_key P256C sk pk ⦃ r =>
      if sk.length ≠ 32 then r = .Err (.KeyRejected .WrongLength)
      else if 0 < beNat sk.val ∧ beNat sk.val < n256 then
        ∃ b, p256PublicKey (beNat sk.val) b ∧
          if pk.val = b ∨ pk.val = x962Compress b then ∃ key, r = .Ok key ∧ SigningKeyOf key (beNat sk.val)
          else r = .Err (.KeyRejected .MismatchedPublicKey)
      else r = .Err (.KeyRejected .ScalarOutOfRange) ⦄ := by
  unfold high.ecdsa.SigningKey.from_private_key_and_public_key
  step with new_secret_spec h
  simp only [mid.p256.Scalar.Insts.RindHighCurveScalar.LEN_BYTES, mid.p256.Scalar.BYTES]
  by_cases hl : sk.length = 32
  · have hne : (Slice.len sk != 32#usize) = false := by
      simp only [bne_eq_false_iff_eq]
      apply UScalar.eq_of_val_eq
      simpa [Slice.len, Slice.length] using hl
    simp only [hne, Bool.false_eq_true, ↓reduceIte, hl, ne_eq, not_true_eq_false]
    simp only [mid.p256.StaticPrivateKey.Insts.RindHighCurvePrivateKeyScalar.from_bytes,
      mid.p256.StaticPrivateKey.from_bytes]
    step with new_secret_spec h
    step with from_bytes_spec sk hl as ⟨r, hr⟩
    split_ifs at hr ⊢ with hin
    · obtain ⟨k, rfl, hk⟩ := hr
      simp only [core.result.Result.map, P.Insts.CoreOpsFunctionFnOnceTuplePrivateKeyStaticPrivateKey.call_once,
        mid.p256.StaticPrivateKey.constructor, bind_ok, core.result.Result.Insts.CoreOpsTry.branch]
      have hk' : scNat k.scalar = beNat sk.val := hk
      step with signing_new_spec hG h k (hk' ▸ hin.1) (hk' ▸ hin.2)
      subst r1_post
      have hkey := r1_post1
      rw [hk'] at hkey
      obtain ⟨-, -, -, hkl, hkp⟩ := id hkey
      simp only [bind_ok]
      step with is_public_key_spec key hkl hkp.2.1 pk as ⟨b, hb⟩
      split
      · rename_i hbt
        simp only [WP.spec_ok]
        refine ⟨_, hkp, ?_⟩
        rw [ite_eq_left (hb.mp hbt)]
        exact ⟨_, rfl, hkey⟩
      · rename_i hbf
        simp only [error.Error.Insts.CoreConvertFromKeyFormatError.from, bind_ok, WP.spec_ok]
        refine ⟨_, hkp, ?_⟩
        rw [ite_eq_right (fun h => hbf (hb.mpr h))]
        trivial
    · subst hr
      simp [core.result.Result.map, core.result.Result.Insts.CoreOpsTry.branch,
        core.result.Result.Insts.CoreOpsTry_traitFromResidualResult.from_residual]
  · have hne : (Slice.len sk != 32#usize) = true := by
      simp only [bne_iff_ne, ne_eq]
      intro h'
      exact hl (by simpa [Slice.len, Slice.length] using congrArg UScalar.val h')
    simp [hne, hl, error.Error.Insts.CoreConvertFromKeyFormatError.from]

/-- `Buffer::copy_from` of bytes that fit. -/
theorem copy_from_spec (N : Usize) (bytes : Slice U8) (hN : bytes.length ≤ N.val) :
    high.signature.Buffer.copy_from N bytes ⦃ r => ∃ b, r = .Ok b ∧ b.len.val = bytes.length ∧
      b.bytes.val.take bytes.length = bytes.val ⦄ := by
  unfold high.signature.Buffer.copy_from high.signature.Buffer.new
  step*
  have hsl : s.length = N.val := by simp [Slice.length, s_post]
  have hle : bytes.len ≤ s.length := by scalar_tac
  simp only [core.slice.Slice.get_mut, core.slice.index.SliceIndexRangeToUsizeSlice.get_mut, hle,
    ↓reduceIte]
  step*
  rw [span1_post]
  have hbl : bytes.length = bytes.len.val := by simp [Slice.length, Slice.len]
  have hs : s.val.length = N.val := hsl
  refine ⟨_, rfl, hbl.symm, ?_⟩
  split_ifs
  simp only [to_slice_mut_back_post]
  rw [Array.from_slice_val _ _ (by simp [hs])]
  have := take_setSlice! s.val bytes.val 0 (by simp [Slice.length] at hN; omega)
  simpa using this

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
  obtain ⟨hsd, hd0, hd, hl, hpk⟩ := id hs
  step with public_key_bytes_spec signing hl as ⟨pk, hpkv⟩
  have hpkl : pk.length = 65 := by
    have := hpk.1; simp only [Slice.length, hpkv]; exact this
  step with copy_from_spec 133#usize pk (by rw [hpkl]; decide)
  subst point_post
  simp only
  step with buffer_as_ref_spec b (by rw [point_post1, hpkl]; decide) as ⟨sl, hsl⟩
  have hslv : sl.val = signing.public_key.val.take 65 := by rw [hsl, point_post1, point_post2, hpkv]
  step with ecdsa_vk_from_x962_spec h hheld hc sl as ⟨vr, hvr⟩
  obtain ⟨hl65, h4, hq⟩ := hpk
  obtain ⟨x, y, hxy, hon⟩ := g_mult hG d hd0 hd
  rw [hq] at hxy
  rw [← hxy] at hon
  unfold x962Outcome at hvr
  rw [hslv, h4] at hvr
  simp only [↓reduceIte, hl65, hon] at hvr
  obtain ⟨vk, rfl, hvk⟩ := hvr
  simp only [WP.spec_ok]
  refine ⟨_, rfl, signing, vk, rfl, hs, by rw [hq]; exact hvk, by rw [point_post1, hpkl], ?_⟩
  rw [← hpkl, point_post2, hpkv, hpkl]

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

namespace P256

/-- A verifying key's clone has its point. -/
theorem vk_clone_spec (hc : Cached) (v : P256VerifyingKey) :
    high.ecdsa.VerifyingKey.Insts.CoreCloneClone.clone P256C mid.p256.VerifyingKey.Insts.CoreCloneClone v
      ⦃ v' => v'.public_key.point = v.public_key.point ⦄ := by
  unfold high.ecdsa.VerifyingKey.Insts.CoreCloneClone.clone
  simp only [mid.p256.VerifyingKey.Insts.CoreCloneClone.clone,
    mid.p256.AffineMontPoint.Insts.CoreCloneClone.clone, bind_ok]
  obtain ⟨c', hc'⟩ := hc.clone v.public_key.odd_multiples
  obtain ⟨c'', hc''⟩ := hc.clone v.public_key.more_odd_multiples
  rw [hc', hc'']
  simp

/-- `Buffer::widen`. -/
theorem widen_buffer_spec {N : Usize} (M : Usize) (w : high.signature.Buffer N) (hM : N.val ≤ M.val) :
    high.signature.Buffer.widen M w ⦃ w' => w'.len = w.len ∧ w'.bytes.val.take N.val = w.bytes.val ⦄ := by
  unfold high.signature.Buffer.widen high.signature.Buffer.new
  step*
  have hb : w.bytes.val.length = N.val := w.bytes.property
  have hr : (Array.repeat M 0#u8).val.length = M.val := (Array.repeat M 0#u8).property
  have := take_setSlice! (Array.repeat M 0#u8).val w.bytes.val 0 (by omega)
  rw [s_post2, s2_post, s1_post, Array.val_to_slice]
  simpa [hb] using this

/-- What the generic layer's verification outcome says, as a verdict on `e`. -/
theorem verdict_of_outcome {Q : P256Point} {dg sig : List U8} {r : core.result.Result Unit error.Error}
    (h : ecdsaVerifyOutcome Q dg sig r) : ecdsaVerdict Q (beNat (dg.take 32) % n256) sig r := by
  unfold ecdsaVerifyOutcome at h
  unfold ecdsaVerdict
  rcases h with ⟨h1, h2, rfl⟩ | ⟨hv, rfl⟩
  · rw [ite_eq_left ⟨h1, h2⟩]
  · rw [ite_eq_right hv]

end P256

/-! ## The signature API, `high::signature`, through the modelled dispatch -/

/-- A generated key pair's private scalar is in [1, n), drawn from the system
random source, and generation is refused only if the draws fail. The draws
themselves are outside the functional spec. -/
theorem p256_ecdsa_generate (ho : P256Order) (h : Runs) (hheld : Held) (hc : Cached) (hfill : Fills) :
    high.signature.EcdsaKeyPair.generate high.signature.sign.ECDSA_P256_SHA256_FIXED ⦃ r =>
      (∀ kp, r = .Ok kp → ∃ d, EcdsaKeyPairOf kp d) ∧ ∀ e, r = .Err e → e = .RngFailed ⦄ := by
  have hG := P256Laws.of_order ho
  unfold high.signature.EcdsaKeyPair.generate high.signature.sign.ECDSA_P256_SHA256_FIXED
    high.signature.EcdsaKeyPair.load_p256_sha256_fixed
  simp only
  step with signing_generate_spec hG h hfill as ⟨r, hok, herr⟩
  rcases r with signing | e
  · obtain ⟨d, hd⟩ := hok signing rfl
    simp only
    apply WP.spec_mono (load_tail_spec hG h hheld hc signing d hd)
    rintro r ⟨kp, rfl, hkp⟩
    exact ⟨fun kp' h' => by cases h'; exact ⟨d, hkp⟩, fun e h => (nomatch h)⟩
  · simp only [WP.spec_ok]
    exact ⟨fun kp h => (nomatch h), fun e' h' => by cases h'; exact herr e rfl⟩

open Classical in
/-- A key pair loaded from a private scalar and the public key it claims:
refused unless the scalar is 32 bytes, in [1, n), and the public key is its
uncompressed or compressed encoding, and otherwise its private scalar is the
scalar. -/
theorem p256_ecdsa_from_private_key_and_public_key (ho : P256Order) (h : Runs) (hheld : Held)
    (hc : Cached) (sk pk : Slice U8) :
    high.signature.EcdsaKeyPair.from_private_key_and_public_key high.signature.sign.ECDSA_P256_SHA256_FIXED
      sk pk ⦃ r =>
      if sk.length ≠ 32 then r = .Err (.KeyRejected .WrongLength)
      else if 0 < beNat sk.val ∧ beNat sk.val < n256 then
        ∃ b, p256PublicKey (beNat sk.val) b ∧
          if pk.val = b ∨ pk.val = x962Compress b then ∃ kp, r = .Ok kp ∧ EcdsaKeyPairOf kp (beNat sk.val)
          else r = .Err (.KeyRejected .MismatchedPublicKey)
      else r = .Err (.KeyRejected .ScalarOutOfRange) ⦄ := by
  have hG := P256Laws.of_order ho
  unfold high.signature.EcdsaKeyPair.from_private_key_and_public_key high.signature.sign.ECDSA_P256_SHA256_FIXED
    high.signature.EcdsaKeyPair.load_p256_sha256_fixed
  simp only
  step with from_scalar_spec hG h sk pk as ⟨r, hr⟩
  split_ifs at hr ⊢ with hl hin
  · subst hr; simp
  · obtain ⟨b, hb, hr⟩ := hr
    by_cases hm : pk.val = b ∨ pk.val = x962Compress b
    · rw [ite_eq_left hm] at hr
      obtain ⟨key, rfl, hkey⟩ := hr
      simp only
      apply WP.spec_mono (load_tail_spec hG h hheld hc key _ hkey)
      rintro r ⟨kp, rfl, hkp⟩
      exact ⟨b, hb, by rw [ite_eq_left hm]; exact ⟨kp, rfl, hkp⟩⟩
    · rw [ite_eq_right hm] at hr
      subst hr
      simp only [WP.spec_ok]
      exact ⟨b, hb, by simp [hm]⟩
  · subst hr; simp

/-- A signature's bytes, if signing returns: the big-endian r and s of the
ECDSA signature of `msg`'s SHA-256 under the key pair's scalar, for some
nonce in [1, n), neither zero. Signing is refused only if the nonce's random
input cannot be drawn. The nonces, RFC 6979's hedged with that input, are
outside the functional spec. -/
theorem p256_ecdsa_sign (ho : P256Order) (h : Runs) (hdrbg : Drbg) (hfill : Fills)
    (kp : high.signature.EcdsaKeyPair) (d : Nat) (hkp : EcdsaKeyPairOf kp d) (msg : Slice U8) (e : Nat)
    (he : Sha256E msg e) :
    high.signature.EcdsaKeyPair.sign kp msg ⦃ r =>
      (∀ sig, r = .Ok sig → high.signature.Signature.Insts.CoreConvertAsRefSliceU8.as_ref sig ⦃ b =>
        b.length = 64 ∧ ∃ k, 0 < k ∧ k < n256 ∧
          ecdsaP256Sign d k e = some (beNat (b.val.take 32), beNat (b.val.drop 32)) ∧
          beNat (b.val.take 32) ≠ 0 ∧ beNat (b.val.drop 32) ≠ 0 ⦄) ∧
      ∀ err, r = .Err err → err = .RngFailed ⦄div := by
  have hG := P256Laws.of_order ho
  obtain ⟨signing, verifying, hkey, hs, -, -, -⟩ := hkp
  obtain ⟨hsd, -, hd, -, -⟩ := hs
  obtain ⟨dd, dg, hhash, hdg', hdg, rfl⟩ := he
  unfold high.signature.EcdsaKeyPair.sign high.signature.Buffer.write high.signature.Buffer.new
  rw [hkey]
  simp only [lift, bind_ok, Array.to_slice_mut]
  apply WP.dspec_bind (ecdsa_sign_spec hG h hdrbg hfill Sha256Sig signing (by rw [hsd]; exact hd) msg _ dg dd
    hhash hdg' hdg)
  rintro ⟨r, s1⟩ ⟨hok, herr⟩
  rw [hsd] at hok
  have hr : (Array.repeat 1024#usize 0#u8).to_slice.length = 1024 := by
    simp only [Slice.length, Array.val_to_slice]; exact (Array.repeat 1024#usize 0#u8).property
  rw [hr] at hok herr
  rcases r with out | err
  · obtain ⟨hl64, hs1l, htake, k, hk0, hk, hsign, hr0, hs0⟩ := hok out rfl
    simp only [WP.dspec_ok]
    refine ⟨fun sig hsig => ?_, fun e h => (nomatch h)⟩
    cases hsig
    unfold high.signature.Signature.Insts.CoreConvertAsRefSliceU8.as_ref
    have hlen : out.len.val = 64 := by simpa [Slice.len, Slice.length] using hl64
    apply WP.spec_mono (buffer_as_ref_spec _ (by simp [hlen]))
    intro b hb
    have hbv : b.val = out.val := by
      rw [hb]
      simp only [hlen]
      rw [Array.from_slice_val _ _ (by simp only [Slice.length] at hs1l; rw [hs1l]; rfl)]
      exact htake
    have hbl : b.length = 64 := by simp only [Slice.length, hbv]; exact hl64
    rw [hbv] at ⊢
    exact ⟨hbl, k, hk0, hk, hsign, hr0, hs0⟩
  · simp only [WP.dspec_ok]
    refine ⟨fun sig h => (nomatch h), fun e h => ?_⟩
    cases h
    rcases herr err rfl with ⟨hlt, -⟩ | hrng
    · omega
    · exact hrng

/-- A key pair's public key's bytes: X9.62's uncompressed encoding of its
scalar times the generator. -/
theorem p256_ecdsa_key_pair_public_key (hc : Cached) (kp : high.signature.EcdsaKeyPair) (d : Nat)
    (hkp : EcdsaKeyPairOf kp d) :
    (do
      let pk ← high.signature.EcdsaKeyPair.impl.public_key kp
      high.signature.PublicKey.Insts.CoreConvertAsRefSliceU8.as_ref pk) ⦃ b =>
      p256PublicKey d b.val ⦄ := by
  obtain ⟨signing, verifying, hkey, hs, -, hpl, hpb⟩ := hkp
  obtain ⟨-, -, -, -, hpk⟩ := hs
  unfold high.signature.EcdsaKeyPair.impl.public_key high.signature.PublicKey.Insts.CoreConvertAsRefSliceU8.as_ref
  rw [hkey]
  simp only
  step with vk_clone_spec hc verifying as ⟨v', hv'⟩
  step with widen_buffer_spec 1088#usize kp.point (by decide) as ⟨w, hwl, hwb⟩
  step with buffer_as_ref_spec w (by rw [hwl, hpl]; decide) as ⟨b, hb⟩
  have hb' : b.val = signing.public_key.val.take 65 := by
    rw [hb, hwl, hpl, ← hpb]
    have := congrArg (List.take 65) hwb
    rw [List.take_take] at this
    simpa using this
  rw [hb']
  exact hpk

/-- Verification with a key pair's public key: ECDSA's verification of
`msg`'s SHA-256 under its scalar times the generator. -/
theorem p256_ecdsa_key_pair_verify (ho : P256Order) (h : Runs) (hc : Cached)
    (kp : high.signature.EcdsaKeyPair) (d : Nat) (hkp : EcdsaKeyPairOf kp d) (msg sig : Slice U8) (e : Nat)
    (he : Sha256E msg e) :
    (do
      let pk ← high.signature.EcdsaKeyPair.impl.public_key kp
      high.signature.PublicKey.verify pk msg sig) ⦃ r =>
      ecdsaVerdict (p256Pow p256G d) e sig.val r ⦄ := by
  have hG := P256Laws.of_order ho
  obtain ⟨signing, verifying, hkey, -, hvk, -, -⟩ := hkp
  obtain ⟨dd, dg, hhash, hdg', hdg, rfl⟩ := he
  unfold high.signature.EcdsaKeyPair.impl.public_key high.signature.PublicKey.verify
  rw [hkey]
  simp only
  step with vk_clone_spec hc verifying as ⟨v', hv'⟩
  step with widen_buffer_spec 1088#usize kp.point (by decide) as ⟨w, hwl, hwb⟩
  have hvk' : VKey (p256Pow p256G d) v'.public_key := by
    obtain ⟨h1, h2, h3⟩ := hvk; exact ⟨h1, h2, by rw [hv']; exact h3⟩
  exact WP.spec_mono (ecdsa_verify_spec hG h hc Sha256Sig v' _ hvk' msg sig dg dd hhash hdg' hdg)
    fun r hr => verdict_of_outcome hr

/-- A P-256 public key parsed from its encoding: refused unless it is an
X9.62 uncompressed point on the curve, and otherwise its verification is
ECDSA's of a message's SHA-256 under that point. -/
theorem p256_ecdsa_public_key_new (ho : P256Order) (h : Runs) (hheld : Held) (hc : Cached)
    (bytes : Slice U8) :
    high.signature.PublicKey.new high.signature.verify.ECDSA_P256_SHA256_FIXED bytes ⦃ r =>
      x962Outcome bytes.val (fun pk => ∀ (msg sig : Slice U8) (e : Nat), Sha256E msg e →
        high.signature.PublicKey.verify pk msg sig ⦃ v =>
          ecdsaVerdict (some (x962Coords bytes.val)) e sig.val v ⦄) r ⦄ := by
  have hG := P256Laws.of_order ho
  unfold high.signature.PublicKey.new high.signature.verify.ECDSA_P256_SHA256_FIXED
    high.signature.parse_ecdsa_p256_sha256_fixed
  simp only
  step with ecdsa_vk_from_x962_spec h hheld hc bytes as ⟨r, hr⟩
  unfold x962Outcome at hr ⊢
  rcases hb : bytes.val.head? with _ | b0
  · simp only [hb] at hr ⊢; subst hr; simp
  · simp only [hb] at hr ⊢
    split_ifs at hr ⊢ with h4 hl hon
    · obtain ⟨vk, rfl, hvk⟩ := hr
      simp only
      step with copy_from_ok 1088#usize bytes (by simp [hl]) as ⟨b, enc, hb'⟩
      subst hb'
      simp only [WP.spec_ok]
      refine ⟨_, rfl, fun msg sig e he => ?_⟩
      obtain ⟨dd, dg, hhash, hdg', hdg, rfl⟩ := he
      exact WP.spec_mono (ecdsa_verify_spec hG h hc Sha256Sig vk _ hvk msg sig dg dd hhash hdg' hdg)
        fun r hr => verdict_of_outcome hr
    · subst hr; simp
    · subst hr; simp
    · subst hr; simp

end rind.aarch64
