import Rind.X86_64.Sha512
open Aeneas Aeneas.Std Result rind.spec

/-!
# The digest API, `high::digest`, through the modelled dispatch

`digest` and `Context` compute FIPS 180-4's SHA-1, SHA-256, SHA-384, and
SHA-512, through the dispatch `Rind.X86_64.DigestDispatch` models, down to
each hash's `HashSpec`. `CtxOf` says what a `Context` has been given.
`admin/prove` writes the aarch64 proof from this file by renaming the target.
-/

namespace rind.x86_64

/-! ## Over any hash meeting `HashSpec` -/

section
variable {Self C S : Type} {inst : high.hash.Hash Self C S} {H : List Byte → List Byte}
  {B L max : Nat} {Abs : List U8 → S → Prop} {CAbs : List U8 → C → Prop}

/-- `Hash::hash`, the default every `Hash` impl keeps. -/
theorem hash_default_spec (hs : HashSpec inst H B L max Abs CAbs) (data : Slice U8)
    (hl : data.length ≤ max) :
    high.hash.Hash.hash.default inst data ⦃ d =>
      outLen d.algorithm = L ∧ digestBytes d = H (bv data.val) ⦄ := by
  unfold high.hash.Hash.hash.default
  apply WP.spec_bind hs.initial
  intro s h0
  have := hs.finish_with [] s data h0 (by simpa using hl)
  simpa only [List.nil_append] using this

theorem hashing_update_spec (hs : HashSpec inst H B L max Abs CAbs)
    (V : high.digest.Variant C) (hV : V.hashHashContextInst = inst.HashContextInst)
    (p : List U8) (h : high.digest.Hashing C) (hc : CAbs p h.context) (data : Slice U8)
    (hl : p.length + data.length ≤ max) :
    high.digest.Hashing.update V h data ⦃ h' => CAbs (p ++ data.val) h'.context ⦄ := by
  unfold high.digest.Hashing.update
  rw [hV]
  step with hs.update p _ data hc hl as ⟨c, hc'⟩
  exact hc'

theorem hashing_finish_spec (hs : HashSpec inst H B L max Abs CAbs)
    (V : high.digest.Variant C) (hV : V.hashHashContextInst = inst.HashContextInst)
    (hfr : V.finish_reset = high.digest.Variant.finish_reset.default V)
    (hnew : V.NEW ⦃ c => CAbs [] c ⦄) (p : List U8) (h : high.digest.Hashing C)
    (hc : CAbs p h.context) (hl : p.length ≤ max) :
    high.digest.Hashing.finish V h ⦃ r =>
      outLen r.1.algorithm = L ∧ digestBytes r.1 = H (bv p) ∧ CAbs [] r.2.context ⦄ := by
  unfold high.digest.Hashing.finish
  rw [hfr]
  unfold high.digest.Variant.finish_reset.default
  rw [hV]
  step with hs.finish p _ hc hl as ⟨d, hd1, hd2⟩
  step with hnew as ⟨c, hc0⟩
  exact ⟨hd1, hd2, hc0⟩

end

/-! ## Each variant's fresh context -/

theorem sha1_variant_new_spec :
    high.hash.Sha1Context.Insts.RindHighDigestVariant.NEW ⦃ c => Sha1Ctx [] c ⦄ := by
  unfold high.hash.Sha1Context.Insts.RindHighDigestVariant.NEW mid.sha1.Sha1Context.new
  step with sha1_new_spec as ⟨s, hs⟩
  step with sha1_resume_spec [] s hs as ⟨c, hc⟩
  exact hc

theorem sha256_variant_new_spec :
    high.hash.Sha256Context.Insts.RindHighDigestVariant.NEW ⦃ c => Sha256Ctx [] c ⦄ := by
  unfold high.hash.Sha256Context.Insts.RindHighDigestVariant.NEW mid.sha2.Sha256Context.new
  step with sha256_new_spec as ⟨s, hs⟩
  step with sha256_resume_spec [] s hs as ⟨c, hc⟩
  exact hc

theorem sha384_variant_new_spec :
    high.hash.Sha384Context.Insts.RindHighDigestVariant.NEW ⦃ c =>
      Hashed sha384Iv c.inner [] ⦄ := by
  unfold high.hash.Sha384Context.Insts.RindHighDigestVariant.NEW mid.sha2.Sha384Context.new
    mid.sha2.Sha384Context.resume
  step with sha384_initial_spec as ⟨s, hh, hn⟩
  step with absorbed_resume_spec _ [] s (absorbed_initial _ s hh hn) as ⟨c, hc⟩
  exact hc

theorem sha512_variant_new_spec :
    high.hash.Sha512Context.Insts.RindHighDigestVariant.NEW ⦃ c => Hashed sha512Iv c [] ⦄ := by
  unfold high.hash.Sha512Context.Insts.RindHighDigestVariant.NEW mid.sha2.Sha512Context.new
  step with sha512_initial_spec as ⟨s, hh, hn⟩
  step with absorbed_resume_spec _ [] s (absorbed_initial _ s hh hn) as ⟨c, hc⟩
  exact hc

/-! ## The API -/

/-- The hash each digest algorithm runs, over spec bytes, for those proven. -/
def digestHash : high.digest.Algorithm → List Byte → List Byte
  | .SHA1 => sha1.hash
  | .SHA256 => sha256.hash
  | .SHA384 => sha384Bytes
  | .SHA512 => sha512Bytes
  | _ => fun _ => []

/-- What the digest API under `a` needs: `a` is SHA-1, SHA-256, SHA-384, or
SHA-512, the entry guard passes, and the CPU runs the hash's routines
(`ShaBlocks` for SHA-1 and SHA-256, `RunsSha512` for SHA-384 and SHA-512). -/
def RunsDigest (a : high.digest.Algorithm) : Prop :=
  (∃ e, low.entry.Entry.new_secret = ok e) ∧
    match a with
    | .SHA1 | .SHA256 => ShaBlocks
    | .SHA384 | .SHA512 => RunsSha512
    | _ => False

/-- `c` is a `Context` of `a` that has been given `p`. -/
def CtxOf (a : high.digest.Algorithm) (p : List U8) : high.digest.State → Prop
  | .Sha1 h => a = .SHA1 ∧ Sha1Ctx p h.context
  | .Sha256 h => a = .SHA256 ∧ Sha256Ctx p h.context
  | .Sha384 h => a = .SHA384 ∧ Hashed sha384Iv h.context.inner p
  | .Sha512 h => a = .SHA512 ∧ Hashed sha512Iv h.context p
  | _ => False

/-- `digest::digest`. -/
theorem digest_spec (a : high.digest.Algorithm) (hr : RunsDigest a) (data : Slice U8)
    (hl : data.length ≤ maxInput) :
    high.digest.digest a data ⦃ d =>
      outLen d.algorithm = outLen a ∧ digestBytes d = digestHash a (bv data.val) ⦄ := by
  obtain ⟨⟨e, he⟩, hb⟩ := hr
  unfold high.digest.digest
  rw [he, bind_ok]
  cases a <;> simp only at hb
  · exact hash_default_spec (sha1_hashSpec hb) data hl
  · exact hash_default_spec (sha256_hashSpec hb) data hl
  · exact hash_default_spec (sha384_hashSpec hb) data hl
  · exact hash_default_spec (sha512_hashSpec hb) data hl

/-- `Context::new`. -/
theorem digest_ctx_new_spec (a : high.digest.Algorithm) (hr : RunsDigest a) :
    high.digest.Context.new a ⦃ c => CtxOf a [] c ⦄ := by
  have hb := hr.2
  unfold high.digest.Context.new
  cases a <;> simp only at hb
  all_goals simp only [high.digest.Algorithm.start, high.digest.Hashing.start,
    high.hash.Sha1Context.Insts.RindHighDigestVariant.state,
    high.hash.Sha256Context.Insts.RindHighDigestVariant.state,
    high.hash.Sha384Context.Insts.RindHighDigestVariant.state,
    high.hash.Sha512Context.Insts.RindHighDigestVariant.state]
  · step with sha1_variant_new_spec as ⟨c, hc⟩
    exact ⟨rfl, hc⟩
  · step with sha256_variant_new_spec as ⟨c, hc⟩
    exact ⟨rfl, hc⟩
  · step with sha384_variant_new_spec as ⟨c, hc⟩
    exact ⟨rfl, hc⟩
  · step with sha512_variant_new_spec as ⟨c, hc⟩
    exact ⟨rfl, hc⟩

/-- `Context::update`. -/
theorem digest_ctx_update_spec (a : high.digest.Algorithm) (hr : RunsDigest a) (p : List U8)
    (c : high.digest.Context) (hc : CtxOf a p c) (data : Slice U8)
    (hl : p.length + data.length ≤ maxInput) :
    high.digest.Context.update c data ⦃ c' => CtxOf a (p ++ data.val) c' ⦄ := by
  have hb := hr.2
  unfold high.digest.Context.update high.digest.State.update
  cases c <;> simp only [CtxOf] at hc
  all_goals obtain ⟨rfl, hc⟩ := hc
  · step with hashing_update_spec (sha1_hashSpec hb)
      high.hash.Sha1Context.Insts.RindHighDigestVariant rfl p _ hc data hl as ⟨h', hh⟩
    exact ⟨rfl, hh⟩
  · step with hashing_update_spec (sha256_hashSpec hb)
      high.hash.Sha256Context.Insts.RindHighDigestVariant rfl p _ hc data hl as ⟨h', hh⟩
    exact ⟨rfl, hh⟩
  · step with hashing_update_spec (sha384_hashSpec hb)
      high.hash.Sha384Context.Insts.RindHighDigestVariant rfl p _ hc data hl as ⟨h', hh⟩
    exact ⟨rfl, hh⟩
  · step with hashing_update_spec (sha512_hashSpec hb)
      high.hash.Sha512Context.Insts.RindHighDigestVariant rfl p _ hc data hl as ⟨h', hh⟩
    exact ⟨rfl, hh⟩

/-- `Context::finish`, which leaves the context fresh. -/
theorem digest_ctx_finish_spec (a : high.digest.Algorithm) (hr : RunsDigest a) (p : List U8)
    (c : high.digest.Context) (hc : CtxOf a p c) (hl : p.length ≤ maxInput) :
    high.digest.Context.finish c ⦃ r =>
      outLen r.1.algorithm = outLen a ∧ digestBytes r.1 = digestHash a (bv p) ∧
        CtxOf a [] r.2 ⦄ := by
  obtain ⟨⟨e, he⟩, hb⟩ := hr
  unfold high.digest.Context.finish high.digest.State.finish
  rw [he, bind_ok]
  cases c <;> simp only [CtxOf] at hc
  all_goals obtain ⟨rfl, hc⟩ := hc
  · step with hashing_finish_spec (sha1_hashSpec hb)
      high.hash.Sha1Context.Insts.RindHighDigestVariant rfl rfl sha1_variant_new_spec p _ hc hl
      as ⟨r, hh, h1, h2, h3⟩
    exact ⟨h1, h2, rfl, h3⟩
  · step with hashing_finish_spec (sha256_hashSpec hb)
      high.hash.Sha256Context.Insts.RindHighDigestVariant rfl rfl sha256_variant_new_spec p _ hc
      hl as ⟨r, hh, h1, h2, h3⟩
    exact ⟨h1, h2, rfl, h3⟩
  · step with hashing_finish_spec (sha384_hashSpec hb)
      high.hash.Sha384Context.Insts.RindHighDigestVariant rfl rfl sha384_variant_new_spec p _ hc
      hl as ⟨r, hh, h1, h2, h3⟩
    exact ⟨h1, h2, rfl, h3⟩
  · step with hashing_finish_spec (sha512_hashSpec hb)
      high.hash.Sha512Context.Insts.RindHighDigestVariant rfl rfl sha512_variant_new_spec p _ hc
      hl as ⟨r, hh, h1, h2, h3⟩
    exact ⟨h1, h2, rfl, h3⟩

end rind.x86_64
