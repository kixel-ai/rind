import Rind.Aarch64.Blockwise
import Rind.S2nSha256
import Rind.Sha2Lemmas
open Aeneas Aeneas.Std Result rind.spec

/-!
# SHA-256's block function with the crypto extension on aarch64

rind's HOL Light proof `SHA256_HW_SUBROUTINE_CORRECT`, in
`proofs/hol-light/aarch64/sha256_block_data_order_hw.ml` at rind's commit,
that rind's naked function `sha256_block_data_order_hw`, as rind's build
emits it, computes s2n-bignum's `sha256_hash_blocks`, restated as an axiom
about the Rust wrapper `compress_hw` around it. `admin/prove` checks the HOL
Light proof against the object code rind's release build emits, its
instructions, relocations, and the `K256` table they read.

The theorem's hypotheses hold for every call `compress_hw`'s safety contract
allows: `state` and `blocks` are distinct allocations, neither overlapping the
code, the table, or the 16 bytes below the stack pointer the routine saves its
frame to; `blocks` is a whole number of blocks, at least one and, as a slice,
fewer than 2^64; the linker places the table within the reach of the `adrp`
that addresses it; and the ABI keeps the stack pointer 16-byte aligned. The
restatement, and that the wrapper passes the pointers and block count the
theorem names, are trusted.

`S2nSha256` proves s2n-bignum's spec FIPS 180-4's, as `Rind.HashSpec` states
it, so the dispatch meets `Compresses` wherever the CPU has the extension.
-/

namespace rind.aarch64

/-- `SHA256_HW_SUBROUTINE_CORRECT`: for `n` blocks, at least one, whose `i`th
block's `j`th word, read big-endian, is the `j`th word of `m i`, the state's
eight words, read little-endian, become `sha256_hash_blocks m state n`. -/
@[step]
axiom sha256_block_data_order_hw_spec (c : low.aarch64.cpu.HaveCryptoExt)
    (state : Std.Array U32 8#usize) (blocks : Slice U8)
    (hm : blocks.length % 64 = 0) (hn : blocks.length ≠ 0) :
    low.aarch64.sha256.compress_hw c state blocks ⦃ r =>
      words r.val = s2n.hashBlocks (fun i => rind.spec.words (((bv blocks.val).drop (64 * i)).take 64))
        (words state.val) (blocks.length / 64) ⦄

/-- The dispatch, on a CPU with the crypto extension, compresses every whole
block, and returns the state for none. -/
theorem sha256_compress_blocks_hw_spec (hc : ∃ c, low.aarch64.cpu.HaveCryptoExt.check = ok (some c)) :
    Compresses sha256.compress low.aarch64.sha256.sha256_compress_blocks := by
  intro h s hl
  obtain ⟨c, hc⟩ := hc
  unfold low.aarch64.sha256.sha256_compress_blocks
  step*
  · have hs : s.val = [] := by
      rw [← List.length_eq_zero_iff]; simp_all
    rw [hs, show bv ([] : List U8) = [] from rfl, blocks]
    simp
  · rw [hc]
    step with sha256_block_data_order_hw_spec as ⟨r, hr⟩
    rw [hr]
    simpa [bv] using s2n.hashBlocks_eq (words h.val) (by simp [words]) (bv s.val)

end rind.aarch64
