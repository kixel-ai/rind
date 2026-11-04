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
    Compresses sha1.compress mid.sha1.Sha1State.Insts.RindLowGenericBlockwiseCompressArrayU325.compress := by
  intro h b hl
  unfold mid.sha1.Sha1State.Insts.RindLowGenericBlockwiseCompressArrayU325.compress
  rw [hb.held]
  simpa using hb.sha1 h b hl

/-- SHA-256's padded last blocks. -/
theorem sha256_compress_padded_spec (hb : ShaBlocks) (P : List U8) (state : Std.Array U32 8#usize)
    (message : Slice U8) (length : Std.Array U8 8#usize)
    (hR : Absorbed sha256.compress sha256.H0 P state) :
    low.aarch64.sha256.sha256_compress_padded state message length ⦃ h' =>
      Absorbed sha256.compress sha256.H0
        (P ++ message.val ++ [128#u8] ++ List.replicate (padZeros 64 8 message.length) 0#u8 ++
          length.val) h' ⦄ := by
  unfold low.aarch64.sha256.sha256_compress_padded
  exact compress_padded_spec (N := 64#usize)
    low.aarch64.sha256.Blocks.Insts.RindLowGenericBlockwiseCompressArrayU328
    (Absorbed sha256.compress sha256.H0) (P.length + message.length + 9 + 64)
    (fun p s b hR hl _ => by
      apply WP.spec_mono (hb.sha256 s b hl)
      intro h' hh
      exact absorbed_append hR hl hh)
    P message length state hR (by decide) (by scalar_tac) (by decide)
    (by have h64 : (64#usize).val = 64 := by simp
        have h8 : (8#usize).val = 8 := by simp
        have := padZeros_lt (64#usize).val (8#usize).val message.length (by omega)
        omega)

end rind.aarch64
