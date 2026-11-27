import Rind.Armv7.Blockwise
import Rind.Sha2Lemmas
open Aeneas Aeneas.Std Result rind.spec

/-!
# SHA-512's block function as armv7's SHA-512 context calls it

`Rind.Armv7.Sha512Context`, which `admin/prove` writes from x86_64's, takes
`RunsSha512` and the block function's contract from here, as x86_64's takes
them from `Rind.X86_64.AwsLc`. armv7's block function runs aws-lc's
`sha512-armv4` assembly, NEON's routine or the integer one, which no proof
covers yet, so `RunsSha512` takes its contract.
-/

namespace rind.armv7

/-- What armv7's SHA-512 theorems assume: its entry guard and the debug
build's check that one is held pass, which read no input, and
`low::arm::sha_armv4::sha512_compress_blocks` computes FIPS 180-4's block
function on any whole number of blocks. -/
def RunsSha512 : Prop :=
  (∃ e, low.entry.Entry.new_secret = ok e) ∧ low.entry.Entry.assert_held = ok () ∧
    ∀ (state : Std.Array U64 8#usize) (blocks : Slice U8), blocks.length % 128 = 0 →
      low.arm.sha_armv4.sha512_compress_blocks state blocks ⦃ r => r.val = compress state.val blocks.val ⦄

@[step]
theorem sha512_new_secret_spec (h : RunsSha512) : low.entry.Entry.new_secret ⦃ _ => True ⦄ := by
  obtain ⟨⟨e, he⟩, -⟩ := h
  simp [he]

@[step]
theorem assert_held_spec (h : RunsSha512) : low.entry.Entry.assert_held ⦃ _ => True ⦄ := by
  obtain ⟨-, he, -⟩ := h
  simp [he]

/-- The entry guard is held, as `ct_equal` checks, which every target's
`RunsSha512` states. -/
theorem RunsSha512.held (h : RunsSha512) : low.entry.Entry.assert_held = ok () := h.2.1

/-- SHA-512's block function on a whole number of blocks. -/
@[step]
theorem sha512_compress_blocks_spec (h : RunsSha512) (state : Std.Array U64 8#usize)
    (blocks : Slice U8) (hm : blocks.length % 128 = 0) :
    low.arm.sha_armv4.sha512_compress_blocks state blocks ⦃ r =>
      r.val = compress state.val blocks.val ⦄ :=
  h.2.2 state blocks hm

end rind.armv7
