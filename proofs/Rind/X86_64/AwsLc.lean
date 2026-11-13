import Rind.X86_64.Funs
import Rind.Sha2Lemmas
open Aeneas Aeneas.Std Result rind.spec

/-!
# aws-lc's SHA-512 contract on x86_64

aws-lc-verification's SAW proof that aws-lc's `sha512_block_data_order_avx`
meets `sha512_block_data_order_array_spec`, at the revision rind's README
cites (79730247), restated as an axiom about the opaque Rust wrapper
`compress_avx` around rind's copy of that routine. rind copies it from aws-lc
91c93a8e, whose `sha512-x86_64.pl` is the proven c21d40da's.

The spec's preconditions hold for every call `compress_avx`'s safety contract
allows: `state` and `blocks` are distinct allocations, `blocks` is a whole
number of blocks, at least one, and the token proves AVX. Its precondition on
`OPENSSL_ia32cap_P` names a global that rind's copy of the routine does not
read. rind runs that routine only on Intel's CPUs with AVX but without AVX2;
the others it runs, OpenSSL's for the SHA512 instructions and for AVX2 and
aws-lc's scalar one, have no proof.

The restatement, and that rind's naked function is aws-lc's object code with
the wrapper passing the pointers and block count the spec names, are trusted.
-/

namespace rind.x86_64

/-- `sha512_block_data_order_array_spec`, which SAW's
`llvm_verify_fixpoint_x86` proves of `sha512_block_data_order_avx`,
https://github.com/awslabs/aws-lc-verification/blob/797302470c1703cbb1a3a6fa98daffef0bfd3d80/SAW/proof/SHA512/SHA512-common.saw#L61
with the spec at
https://github.com/awslabs/aws-lc-verification/blob/797302470c1703cbb1a3a6fa98daffef0bfd3d80/SAW/proof/SHA512/SHA512-common-specs.saw#L101 :
for `num` blocks, `len = num * 128` bytes and not zero, the state becomes
cryptol-specs' `processBlocks state data 0 num`, which `compress` restates. -/
@[step]
axiom compress_avx_spec (t : low.x86_64.cpu.HaveAvx) (state : Std.Array U64 8#usize)
    (blocks : Slice U8) (hm : blocks.length % 128 = 0) (hn : blocks.length ≠ 0) :
    low.x86_64.sha512.compress_avx t state blocks ⦃ r => r.val = compress state.val blocks.val ⦄

/-- rind's SHA-512 runs aws-lc's AVX routine on this CPU, which is Intel's and
has AVX and SSSE3 but not AVX2, and its entry guard and the debug build's
check that one is held pass. None reads an input. -/
def RunsSha512 : Prop :=
  (∃ e, low.entry.Entry.new_secret = ok e) ∧ low.entry.Entry.assert_held = ok () ∧
    ∃ t, low.x86_64.sha512.path = ok (low.x86_64.sha512.Path.Avx t)

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

/-- The dispatch runs the AVX routine on a whole number of blocks, and returns
the state for none. -/
@[step]
theorem sha512_compress_blocks_spec (h : RunsSha512) (state : Std.Array U64 8#usize)
    (blocks : Slice U8) (hm : blocks.length % 128 = 0) :
    low.x86_64.sha512.sha512_compress_blocks state blocks ⦃ r =>
      r.val = compress state.val blocks.val ⦄ := by
  obtain ⟨-, -, t, ht⟩ := h
  unfold low.x86_64.sha512.sha512_compress_blocks
  step*
  · simp_all [compress_short]
  · rw [ht]
    step with compress_avx_spec
    simp_all

end rind.x86_64
