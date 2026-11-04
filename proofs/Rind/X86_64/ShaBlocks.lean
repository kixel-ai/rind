import Rind.X86_64.Blockwise
open Aeneas Aeneas.Std Result rind.spec

/-!
# SHA-1 and SHA-256's block functions on x86_64

No proof covers any block function x86_64 runs for SHA-1 or SHA-256, so the
theorems over them take `ShaBlocks` as a hypothesis instead of an axiom: each
routine's contract, FIPS 180-4's block function over every whole block it is
given, and that rind's checks pass. Once a routine's published proof lands,
an axiom restating it under the composition rule discharges its field.
-/

namespace rind.x86_64

/-- What the SHA-1 and SHA-256 theorems assume of the code below rind's
padding on x86_64: each routine computes FIPS 180-4's block function, the CPU
dispatch picks one, and the entry checks pass. None reads an input. -/
structure ShaBlocks : Prop where
  entry : ∃ e, low.entry.Entry.new_secret = ok e
  held : low.entry.Entry.assert_held = ok ()
  path : ∃ p, low.x86_64.sha256_mux.path = ok p
  sha1 : Compresses sha1.compress low.x86_64.sha1_mux.sha1_compress_blocks
  shaext : ∀ t h (b l : Slice U8), b.length % 64 = 0 → l.length % 64 = 0 →
    low.x86_64.sha256.sha256_compress_blocks_shaext h b l t ⦃ h' =>
      words h'.val = (blocks 64 (bv (b.val ++ l.val))).foldl sha256.compress (words h.val) ⦄
  avx : ∀ t, Compresses sha256.compress fun h b => low.x86_64.sha256.sha256_compress_blocks_avx h b t
  avx2 : ∀ t, Compresses sha256.compress fun h b =>
    low.x86_64.sha256.sha256_compress_blocks_avx2 h b t
  ssse3 : ∀ t, Compresses sha256.compress fun h b =>
    low.x86_64.sha256.sha256_compress_blocks_ssse3 h b t
  nohw : Compresses sha256.compress low.x86_64.sha256.sha256_compress_blocks_nohw

theorem sha256_compress_blocks_spec (hb : ShaBlocks) :
    Compresses sha256.compress low.x86_64.sha256_mux.sha256_compress_blocks := by
  intro h b hl
  obtain ⟨p, hp⟩ := hb.path
  unfold low.x86_64.sha256_mux.sha256_compress_blocks
  rw [hp]
  cases p with
  | Shaext t =>
    step*
    have hs : s.val = [] := by rw [s_post]; rfl
    apply WP.spec_mono (hb.shaext t h b _ hl (by simp only [Slice.length, hs]; rfl))
    intro h' hh
    rw [hh, hs, List.append_nil]
  | Avx t => exact (by simpa using hb.avx t h b hl)
  | Avx2 t => exact (by simpa using hb.avx2 t h b hl)
  | Ssse3 t => exact (by simpa using hb.ssse3 t h b hl)
  | Nohw => exact (by simpa using hb.nohw h b hl)

/-- SHA-256's block function as `Sha256State` calls it. -/
theorem sha256_block_spec (hb : ShaBlocks) : Compresses sha256.compress mid.sha2.Sha256State.compress := by
  intro h b hl
  unfold mid.sha2.Sha256State.compress
  rw [hb.held]
  simpa using sha256_compress_blocks_spec hb h b hl

/-- SHA-1's block function as `Sha1State` calls it. -/
theorem sha1_block_spec (hb : ShaBlocks) :
    Compresses sha1.compress mid.sha1.Sha1State.Insts.RindLowGenericBlockwiseCompressArrayU325.compress := by
  intro h b hl
  unfold mid.sha1.Sha1State.Insts.RindLowGenericBlockwiseCompressArrayU325.compress
  rw [hb.held]
  simpa using hb.sha1 h b hl

theorem pad_message_spec {N L : Usize} (message : Slice U8) (length : Std.Array U8 L)
    (hN : 0 < N.val) (hN2 : 2 * N.val ≤ Usize.max) (hL : L.val + 1 ≤ N.val) :
    low.generic.blockwise.pad_message message length
      (Std.Array.repeat 2#usize (Std.Array.repeat N 0#u8)) ⦃ r _ =>
      r.1.length % N.val = 0 ∧ r.2.length % N.val = 0 ∧
      r.1.val ++ r.2.val = message.val ++ [128#u8] ++
        List.replicate (padZeros N L message.length) 0#u8 ++ length.val ⦄ := by
  unfold low.generic.blockwise.pad_message
  have hlen : message.len.val = message.length := by simp [Slice.len, Slice.length]
  have hmod := Nat.mod_add_div message.length N.val
  have hlt := Nat.mod_lt message.length hN
  have hdm := Nat.div_mul_le_self message.length N.val
  step*
  have hst : i2.val = N.val * (message.length / N.val) := by
    rw [i2_post, i1_post, hlen, Nat.mul_comm]
  have hpz : padZeros N.val L.val rest.length = padZeros N.val L.val message.length := by
    rw [blocks_post1, hst]
    exact padZeros_sub (Nat.mul_mod_right _ _) (by omega)
  step with pad_spec rest length hN hN2 hL (by rw [blocks_post1, hst]; omega) as ⟨s, _, hs⟩
  refine ⟨by rw [blocks_post, hst]; exact Nat.mul_mod_right _ _, ?_, ?_⟩
  · have : s.length = rest.length + 1 + L.val + padZeros N.val L.val rest.length := by
      simp only [Slice.length] at *; rw [hs]; simp; omega
    rw [this]; exact pad_mod _ hN
  · rw [hs, hpz, blocks_post2, blocks_post3]
    simp only [List.append_assoc]
    rw [← List.append_assoc (List.take _ _), List.take_append_drop]

/-- SHA-256's padded last blocks, which the SHA extensions' routine takes as a
second run of blocks. -/
theorem sha256_compress_padded_spec (hb : ShaBlocks) (P : List U8) (state : Std.Array U32 8#usize)
    (message : Slice U8) (length : Std.Array U8 8#usize)
    (hR : Absorbed sha256.compress sha256.H0 P state) :
    low.x86_64.sha256_mux.sha256_compress_padded state message length ⦃ h' =>
      Absorbed sha256.compress sha256.H0
        (P ++ message.val ++ [128#u8] ++ List.replicate (padZeros 64 8 message.length) 0#u8 ++
          length.val) h' ⦄ := by
  obtain ⟨p, hp⟩ := hb.path
  unfold low.x86_64.sha256_mux.sha256_compress_padded
  rw [hp]
  have generic := compress_padded_spec (N := 64#usize)
    low.x86_64.sha256_mux.Blocks.Insts.RindLowGenericBlockwiseCompressArrayU328
    (Absorbed sha256.compress sha256.H0) (P.length + message.length + 9 + 64)
    (fun p s b hR hl _ => by
      apply WP.spec_mono (sha256_compress_blocks_spec hb s b hl)
      intro h' hh
      exact absorbed_append hR hl hh)
    P message length state hR (by decide) (by scalar_tac) (by decide)
    (by have h64 : (64#usize).val = 64 := by simp
        have h8 : (8#usize).val = 8 := by simp
        have := padZeros_lt (64#usize).val (8#usize).val message.length (by omega)
        omega)
  cases p with
  | Shaext t =>
    simp only [bind_ok]
    step with pad_message_spec message length (N := 64#usize) (by decide) (by scalar_tac) (by decide)
      as ⟨bl, la, _, h1, h2, h3⟩
    apply WP.spec_mono (hb.shaext t state bl la h1 h2)
    intro h' hh
    have := absorbed_append (b := bl.val ++ la.val) hR
      (by simp only [Slice.length] at h1 h2; simp [Nat.add_mod, h1, h2]) hh
    rw [h3] at this
    simpa [List.append_assoc] using this
  | Avx t => simpa using generic
  | Avx2 t => simpa using generic
  | Ssse3 t => simpa using generic
  | Nohw => simpa using generic

end rind.x86_64
