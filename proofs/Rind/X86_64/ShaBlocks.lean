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
  shaext : ∀ t, Compresses sha256.compress fun h b =>
    low.x86_64.sha256.sha256_compress_blocks_shaext h b t
  /-- The SHA extensions' finish: the blocks, then `last`'s first `used`
  bytes padded and closed by `length`, and the result's words big-endian. -/
  shaext_finish : ∀ t h (b : Slice U8) (last : Std.Array U8 64#usize) (used : Usize)
    (length : Std.Array U8 8#usize), b.length % 64 = 0 → used.val ≤ 64 →
    low.x86_64.sha256.sha256_finish_shaext h b last used length t ⦃ r =>
      bv r.val = ((blocks 64 (bv (b.val ++ last.val.take used.val ++ [128#u8] ++
        List.replicate (padZeros 64 8 used.val) 0#u8 ++ length.val))).foldl sha256.compress
          (words h.val)).flatMap BitVec.toBEBytes ⦄
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
  | Shaext t => exact (by simpa using hb.shaext t h b hl)
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
    Compresses sha1.compress mid.sha1.Sha1State.compress := by
  intro h b hl
  unfold mid.sha1.Sha1State.compress
  rw [hb.held]
  simpa using hb.sha1 h b hl

/-- SHA-256's padded last blocks, on the routines that do not finish a hash
themselves. -/
theorem sha256_compress_padded_spec (hb : ShaBlocks) (P : List U8) (state : Std.Array U32 8#usize)
    (message : Slice U8) (length : Std.Array U8 8#usize)
    (hR : Absorbed sha256.compress sha256.H0 P state) :
    low.x86_64.sha256_mux.sha256_compress_padded state message length ⦃ h' =>
      Absorbed sha256.compress sha256.H0
        (P ++ message.val ++ [128#u8] ++ List.replicate (padZeros 64 8 message.length) 0#u8 ++
          length.val) h' ⦄ := by
  have tail : ∀ blocks rest : Slice U8, blocks.length % (64#usize).val = 0 ∧
      blocks.val ++ rest.val = message.val ∧ rest.length + 1 + (8#usize).val ≤ 2 * (64#usize).val ∧
      padZeros (64#usize).val (8#usize).val rest.length =
        padZeros (64#usize).val (8#usize).val message.length →
      (do
        let b ← core.slice.Slice.is_empty blocks
        let state1 ← if b then ok state else low.x86_64.sha256_mux.sha256_compress_blocks state blocks
        let a := Std.Array.repeat 64#usize 0#u8
        let last := Std.Array.repeat 2#usize a
        let (s, _) ← low.generic.blockwise.pad rest length last
        low.x86_64.sha256_mux.sha256_compress_blocks state1 s) ⦃ h' =>
        Absorbed sha256.compress sha256.H0
          (P ++ message.val ++ [128#u8] ++ List.replicate (padZeros 64 8 message.length) 0#u8 ++
            length.val) h' ⦄ :=
    fun blocks rest hs => compress_tail_spec low.x86_64.sha256_mux.sha256_compress_blocks
      (Absorbed sha256.compress sha256.H0) (P.length + message.length + 9 + 64)
      (fun p s b hR hl _ => by
        apply WP.spec_mono (sha256_compress_blocks_spec hb s b hl)
        intro h' hh
        exact absorbed_append hR hl hh)
      P message blocks rest length state hR (by decide) (by scalar_tac) (by decide) hs
      (by have h64 : (64#usize).val = 64 := by simp
          have h8 : (8#usize).val = 8 := by simp
          have := padZeros_lt (64#usize).val (8#usize).val message.length (by omega)
          omega)
  unfold low.x86_64.sha256_mux.sha256_compress_padded
  step with split_tail_spec (N := 64#usize) (L := 8#usize) message (by decide) (by scalar_tac)
    (by decide) as ⟨bl, re, hs1, hs2, hs3, hs4⟩
  exact tail bl re ⟨hs1, hs2, hs3, hs4⟩

/-- The routines that do not finish a hash: the padded last blocks, then the
digest's encoding. -/
theorem sha256_finish_padded_spec (hb : ShaBlocks) (P : List U8) (state : Std.Array U32 8#usize)
    (message : Slice U8) (length : Std.Array U8 8#usize)
    (hR : Absorbed sha256.compress sha256.H0 P state) :
    (do
      let state1 ← low.x86_64.sha256_mux.sha256_compress_padded state message length
      low.generic.blockwise.sha256_digest state1) ⦃ r =>
        bv r.val = sha256Finished P message.val length.val ⦄ := by
  step with sha256_compress_padded_spec hb P state message length hR as ⟨h', hh'⟩
  apply WP.spec_mono (sha256_digest_spec h')
  intro r hr
  rw [hr, hh'.1]
  rfl

/-- SHA-256's digest of what `state` has absorbed followed by `message`. -/
theorem sha256_finish_spec (hb : ShaBlocks) (P : List U8) (state : Std.Array U32 8#usize)
    (message : Slice U8) (length : Std.Array U8 8#usize)
    (hR : Absorbed sha256.compress sha256.H0 P state) :
    low.x86_64.sha256_mux.sha256_finish state message length ⦃ r =>
      bv r.val = sha256Finished P message.val length.val ⦄ := by
  obtain ⟨p, hp⟩ := hb.path
  unfold low.x86_64.sha256_mux.sha256_finish
  rw [hp]
  cases p with
  | Shaext t =>
    simp only [bind_ok]
    have hml : message.len.val = message.length := by simp [Slice.len, Slice.length]
    step*
    simp only [Slice.length] at blocks_post blocks_post1 hml
    have hbl : (↑blocks : List U8).length % 64 = 0 := by rw [blocks_post, i2_post]; omega
    have hrl : (↑rest : List U8).length < 64 := by rw [blocks_post1, i2_post, i1_post, hml]; omega
    have hrl' : rest.len.val = (↑rest : List U8).length := by simp [Slice.len]
    apply WP.spec_mono (hb.shaext_finish t state blocks _ _ length
      (by simpa [Slice.length] using hbl) (by rw [hrl']; omega))
    intro r hr
    have hlast : (index_mut_back s1).val.take rest.len.val = rest.val := by
      rw [s_post2, s1_post, hrl']
      have := rind.spec.take_setSlice! (Array.repeat 64#usize 0#u8).val rest.val 0 (by simp; omega)
      simpa using this
    rw [hr, hlast, hrl', sha256Finished_split hR hbl, blocks_post2, blocks_post3,
      List.take_append_drop]
  | Avx t => simp only [bind_ok]; exact sha256_finish_padded_spec hb P state message length hR
  | Avx2 t => simp only [bind_ok]; exact sha256_finish_padded_spec hb P state message length hR
  | Ssse3 t => simp only [bind_ok]; exact sha256_finish_padded_spec hb P state message length hR
  | Nohw => simp only [bind_ok]; exact sha256_finish_padded_spec hb P state message length hR

/-- SHA-256's digest of what `state` has absorbed followed by `block`'s first
`used` bytes. -/
theorem sha256_finish_block_spec (hb : ShaBlocks) (P : List U8) (state : Std.Array U32 8#usize)
    (block : Std.Array U8 64#usize) (used : Usize) (length : Std.Array U8 8#usize)
    (hR : Absorbed sha256.compress sha256.H0 P state) (hu : used.val ≤ 64) :
    low.x86_64.sha256_mux.sha256_finish_block state block used length ⦃ r =>
      bv r.val = sha256Finished P (block.val.take used.val) length.val ⦄ := by
  obtain ⟨p, hp⟩ := hb.path
  unfold low.x86_64.sha256_mux.sha256_finish_block
  rw [hp]
  have fallback :
      (do
        let s ← core.array.Array.index (core.ops.index.IndexSlice
          (core.slice.index.SliceIndexRangeToUsizeSlice Std.U8)) block { «end» := used }
        let state1 ← low.x86_64.sha256_mux.sha256_compress_padded state s length
        low.generic.blockwise.sha256_digest state1) ⦃ r =>
          bv r.val = sha256Finished P (block.val.take used.val) length.val ⦄ := by
    step as ⟨s, hs⟩
    apply WP.spec_mono (sha256_finish_padded_spec hb P state s length hR)
    intro r hr
    rw [hr, hs]
    simp [List.slice]
  cases p with
  | Shaext t =>
    simp only [bind_ok]
    step*
    have hs0 : s.val = [] := by rw [s_post]; rfl
    apply WP.spec_mono (hb.shaext_finish t state s block used length (by simp [Slice.length, hs0]) hu)
    intro r hr
    have htl : (block.val.take used.val).length = used.val := by simp; omega
    have := sha256Finished_split (b := []) (rest := block.val.take used.val) (length := length.val)
      hR (by simp)
    rw [hr, hs0]
    simpa [htl] using this
  | Avx t => simp only [bind_ok]; exact fallback
  | Avx2 t => simp only [bind_ok]; exact fallback
  | Ssse3 t => simp only [bind_ok]; exact fallback
  | Nohw => simp only [bind_ok]; exact fallback

end rind.x86_64
