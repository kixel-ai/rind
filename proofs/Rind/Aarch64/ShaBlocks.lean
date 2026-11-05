import Rind.Aarch64.Blockwise
open Aeneas Aeneas.Std Result rind.spec

/-!
# SHA-1 and SHA-256's block functions on aarch64

No proof covers aws-lc's SHA-1 or SHA-256 routines that aarch64 runs, so the
theorems over them take `ShaBlocks` as a hypothesis instead of an axiom, as on
x86_64. `Rind.X86_64.ShaBlocks` states the same names for x86_64.
-/

namespace rind.aarch64

/-- What the SHA-1 and SHA-256 theorems assume of the code below rind's
padding on aarch64: each routine computes FIPS 180-4's block function, and
the entry checks pass. None reads an input. -/
structure ShaBlocks : Prop where
  entry : ∃ e, low.entry.Entry.new_secret = ok e
  held : low.entry.Entry.assert_held = ok ()
  sha1 : Compresses sha1.compress low.aarch64.sha1.sha1_compress_blocks
  sha256 : Compresses sha256.compress low.aarch64.sha256.sha256_compress_blocks

/-- SHA-256's block function as `Sha256State` calls it. -/
theorem sha256_block_spec (hb : ShaBlocks) : Compresses sha256.compress mid.sha2.Sha256State.compress := by
  intro h b hl
  unfold mid.sha2.Sha256State.compress
  rw [hb.held]
  simpa using hb.sha256 h b hl

/-- SHA-1's block function as `Sha1State` calls it. -/
theorem sha1_block_spec (hb : ShaBlocks) :
    Compresses sha1.compress mid.sha1.Sha1State.compress := by
  intro h b hl
  unfold mid.sha1.Sha1State.compress
  rw [hb.held]
  simpa using hb.sha1 h b hl

/-- SHA-1's padded last blocks. -/
theorem sha1_compress_padded_spec (hb : ShaBlocks) (P : List U8) (state : Std.Array U32 5#usize)
    (message : Slice U8) (length : Std.Array U8 8#usize)
    (hR : Absorbed sha1.compress sha1.H0 P state) :
    low.aarch64.sha1.sha1_compress_padded state message length ⦃ h' =>
      Absorbed sha1.compress sha1.H0
        (P ++ message.val ++ [128#u8] ++ List.replicate (padZeros 64 8 message.length) 0#u8 ++
          length.val) h' ⦄ := by
  unfold low.aarch64.sha1.sha1_compress_padded
  step with split_tail_spec (N := 64#usize) (L := 8#usize) message (by decide) (by scalar_tac)
    (by decide) as ⟨bl, re, hs1, hs2, hs3, hs4⟩
  exact compress_tail_spec low.aarch64.sha1.sha1_compress_blocks (Absorbed sha1.compress sha1.H0)
    (P.length + message.length + 9 + 64)
    (fun p s b hR hl _ => by
      apply WP.spec_mono (hb.sha1 s b hl)
      intro h' hh
      exact absorbed_append hR hl hh)
    P message bl re length state hR (by decide) (by scalar_tac) (by decide) ⟨hs1, hs2, hs3, hs4⟩
    (by have h64 : (64#usize).val = 64 := by simp
        have h8 : (8#usize).val = 8 := by simp
        have := padZeros_lt (64#usize).val (8#usize).val message.length (by omega)
        omega)

/-- SHA-256's padded last blocks. -/
theorem sha256_compress_padded_spec (hb : ShaBlocks) (P : List U8) (state : Std.Array U32 8#usize)
    (message : Slice U8) (length : Std.Array U8 8#usize)
    (hR : Absorbed sha256.compress sha256.H0 P state) :
    low.aarch64.sha256.sha256_compress_padded state message length ⦃ h' =>
      Absorbed sha256.compress sha256.H0
        (P ++ message.val ++ [128#u8] ++ List.replicate (padZeros 64 8 message.length) 0#u8 ++
          length.val) h' ⦄ := by
  have tail : ∀ blocks rest : Slice U8, blocks.length % (64#usize).val = 0 ∧
      blocks.val ++ rest.val = message.val ∧ rest.length + 1 + (8#usize).val ≤ 2 * (64#usize).val ∧
      padZeros (64#usize).val (8#usize).val rest.length =
        padZeros (64#usize).val (8#usize).val message.length →
      (do
        let b ← core.slice.Slice.is_empty blocks
        let state1 ← if b then ok state else low.aarch64.sha256.sha256_compress_blocks state blocks
        let a := Std.Array.repeat 64#usize 0#u8
        let last := Std.Array.repeat 2#usize a
        let (s, _) ← low.generic.blockwise.pad rest length last
        low.aarch64.sha256.sha256_compress_blocks state1 s) ⦃ h' =>
        Absorbed sha256.compress sha256.H0
          (P ++ message.val ++ [128#u8] ++ List.replicate (padZeros 64 8 message.length) 0#u8 ++
            length.val) h' ⦄ :=
    fun blocks rest hs => compress_tail_spec low.aarch64.sha256.sha256_compress_blocks
      (Absorbed sha256.compress sha256.H0) (P.length + message.length + 9 + 64)
      (fun p s b hR hl _ => by
        apply WP.spec_mono (hb.sha256 s b hl)
        intro h' hh
        exact absorbed_append hR hl hh)
      P message blocks rest length state hR (by decide) (by scalar_tac) (by decide) hs
      (by have h64 : (64#usize).val = 64 := by simp
          have h8 : (8#usize).val = 8 := by simp
          have := padZeros_lt (64#usize).val (8#usize).val message.length (by omega)
          omega)
  unfold low.aarch64.sha256.sha256_compress_padded
  step with split_tail_spec (N := 64#usize) (L := 8#usize) message (by decide) (by scalar_tac)
    (by decide) as ⟨bl, re, hs1, hs2, hs3, hs4⟩
  exact tail bl re ⟨hs1, hs2, hs3, hs4⟩

/-- SHA-256's digest of what `state` has absorbed followed by `message`. -/
theorem sha256_finish_spec (hb : ShaBlocks) (P : List U8) (state : Std.Array U32 8#usize)
    (message : Slice U8) (length : Std.Array U8 8#usize)
    (hR : Absorbed sha256.compress sha256.H0 P state) :
    low.aarch64.sha256.sha256_finish state message length ⦃ r =>
      bv r.val = sha256Finished P message.val length.val ⦄ := by
  unfold low.aarch64.sha256.sha256_finish
  step with sha256_compress_padded_spec hb P state message length hR as ⟨h', hh'⟩
  apply WP.spec_mono (sha256_digest_spec h')
  intro r hr
  rw [hr, hh'.1]
  rfl

end rind.aarch64
