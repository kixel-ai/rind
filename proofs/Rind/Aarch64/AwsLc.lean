import Rind.Aarch64.Funs
import Rind.Sha2Lemmas
open Aeneas Aeneas.Std Result rind.spec

/-!
# aws-lc's SHA-512 contract on aarch64

aws-lc-verification's NSym proof that aws-lc's `sha512_block_data_order_nohw`
computes `sha512_block_data_order_array_spec`, at the revision rind's README
cites (79730247), restated as an axiom about the opaque Rust wrapper
`compress_nohw` around rind's copy of that routine. rind copies it from aws-lc
91c93a8e, whose `sha512-armv8.pl` is the proven c21d40da's.

aws-lc-verification's SAW proof of the C assumes that spec on aarch64 and its
NSym proof discharges it, with the caveats its README lists: NSym's spec of
the block loop, `processBlocks_rec`, recurses from the last block where
cryptol-specs' `processBlocks` loops from the first (ArmSpecGap), which
`compress` restates as the first; and its block function,
`processBlock_Common_rec`, is `processBlock_Common` by `SHA512rec.icry`'s
`:prove processBlock_Common_equiv`. The spec's preconditions hold for every
call `compress_nohw`'s safety contract allows: `state` and `blocks` are
distinct allocations, and `blocks` is a whole number of blocks, at least one
and, as a slice, fewer than 2^57.

NSym's proof of the routine for the SHA-512 instructions,
`sha512_block_data_order_hw`, asserts the digest in registers at the end of
its block loop, before the instruction that stores it to `state`, so no
theorem states `compress_hw`'s result and none is assumed here.

The restatement, and that rind's naked function is aws-lc's object code with
the wrapper passing the pointers and block count the spec names, are trusted.
-/

namespace rind.aarch64

/-- `sha512_block_data_order_array_spec`, which aws-lc-verification assumes of
`sha512_block_data_order_nohw` in its SAW proof,
https://github.com/awslabs/aws-lc-verification/blob/797302470c1703cbb1a3a6fa98daffef0bfd3d80/SAW/proof/SHA512/SHA512-common.saw#L61
with the spec at
https://github.com/awslabs/aws-lc-verification/blob/797302470c1703cbb1a3a6fa98daffef0bfd3d80/SAW/proof/SHA512/SHA512-common-specs.saw#L101 ,
and its NSym proof discharges, whose postcondition is at
https://github.com/awslabs/aws-lc-verification/blob/797302470c1703cbb1a3a6fa98daffef0bfd3d80/NSym/proof/proofs/SHA512/sha512_block_data_order_unbounded.ml#L191 :
for `num` blocks, at least one, the state becomes cryptol-specs'
`processBlocks state data 0 num`, which `compress` restates. -/
@[step]
axiom compress_nohw_spec (state : Std.Array U64 8#usize) (blocks : Slice U8)
    (hm : blocks.length % 128 = 0) (hn : blocks.length ≠ 0) :
    low.aarch64.sha512.compress_nohw state blocks ⦃ r => r.val = compress state.val blocks.val ⦄

/-- rind's SHA-512 runs aws-lc's scalar routine on this CPU, which lacks the
SHA-512 instructions, and its entry guard and the debug build's check that one
is held pass. None reads an input. -/
def RunsSha512 : Prop :=
  (∃ e, low.entry.Entry.new_secret = ok e) ∧ low.entry.Entry.assert_held = ok () ∧
    low.aarch64.cpu.HaveSha3.check = ok none

@[step]
theorem sha512_new_secret_spec (h : RunsSha512) : low.entry.Entry.new_secret ⦃ _ => True ⦄ := by
  obtain ⟨⟨e, he⟩, -⟩ := h
  simp [he]

@[step]
theorem assert_held_spec (h : RunsSha512) : low.entry.Entry.assert_held ⦃ _ => True ⦄ := by
  obtain ⟨-, he, -⟩ := h
  simp [he]

/-- The dispatch runs the scalar routine on a whole number of blocks, and
returns the state for none. -/
@[step]
theorem sha512_compress_blocks_spec (h : RunsSha512) (state : Std.Array U64 8#usize)
    (blocks : Slice U8) (hm : blocks.length % 128 = 0) :
    low.aarch64.sha512.sha512_compress_blocks state blocks ⦃ r =>
      r.val = compress state.val blocks.val ⦄ := by
  obtain ⟨-, -, hc⟩ := h
  unfold low.aarch64.sha512.sha512_compress_blocks
  step*
  · simp_all [compress_short]
  · rw [hc]
    step with compress_nohw_spec
    simp_all

end rind.aarch64
