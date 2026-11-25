import Rind.Aarch64.Funs
import Rind.VgPbkdf2
open Aeneas Aeneas.Std Result rind.spec

/-!
# pyca/verified-garbage's SHA-512 block function on aarch64

On the SHA-512 instructions, `low::aarch64::sha512::compress_hw` calls VG's
`vg_sha512_compress_sha512`, which `admin/import-vg` vendors. The axiom below
restates VG's Lean theorem about it,
[`compress_verified`](https://github.com/pyca/verified-garbage/blob/0aa40d6c21fd02943fe5b38a5b69b6213d07764d/lean/VerifiedGarbage/Proof/Sha512/AArch64/Sha3/Compress.lean#L658),
that the code meets `compressAArch64`
([`Proof/Sha512/AArch64/Compress.lean`](https://github.com/pyca/verified-garbage/blob/0aa40d6c21fd02943fe5b38a5b69b6213d07764d/lean/VerifiedGarbage/Proof/Sha512/AArch64/Compress.lean#L405)),
about that wrapper, over VG's spec, which `Rind.VgPbkdf2`'s
`sha512_compressList` proves rind's.

The routine is internal to VG, so its contract is in VG's proofs rather than
its trusted specification, as for the RSA routines rind runs on x86_64. The
contract: for `n` blocks at `x1`, the state stored at `x0` as eight
little-endian words becomes `compressBlocks` of it over the blocks, which
reads each block as `compressList` does the same bytes; it may read the
blocks and read and write the state and a 640-byte scratch at `x3`, none
overlapping another. Its precondition holds for every call safe Rust makes:
`state` is a `&mut` borrow, `blocks` a shared one, and the scratch a local of
the wrapper's, so the three are distinct objects, none of which wraps the
address space; and a `HaveSha3` exists only once the CPU check has found the
SHA-512 instructions.

Trusted: the restatement, and that the wrapper passes the routine the state's
and the blocks' pointers, the block count, and the scratch's pointer.
-/

namespace rind.aarch64

/-- `compressAArch64`: the state's eight words, read as VG's hash value `H`,
become `compressList` of `H` over `blocks`' whole blocks. -/
axiom vg_sha512_compress_sha512_spec (c : low.aarch64.cpu.HaveSha3)
    (state : Std.Array U64 8#usize) (blocks : Slice U8) (H : VG.Spec.Sha512.HashValue)
    (hH : H.toList = state.val.map (·.bv)) (hm : blocks.length % 128 = 0) :
    low.aarch64.sha512.compress_hw c state blocks ⦃ r =>
      r.val.map (·.bv) =
        (VG.Spec.Sha512.compressList H (blocks.val.map (·.bv)) (blocks.val.length / 128)).toList ⦄

/-- The wrapper computes rind's `compress`. -/
@[step]
theorem compress_hw_spec (c : low.aarch64.cpu.HaveSha3) (state : Std.Array U64 8#usize)
    (blocks : Slice U8) (hm : blocks.length % 128 = 0) :
    low.aarch64.sha512.compress_hw c state blocks ⦃ r => r.val = compress state.val blocks.val ⦄ := by
  apply WP.spec_mono (vg_sha512_compress_sha512_spec c state blocks
    ⟨(state.val.map (·.bv)).toArray, by simpa using state.property⟩ rfl hm)
  intro r hr
  apply List.map_injective_iff.2 fun x y h => by cases x; cases y; simp_all
  rw [hr, vg.sha512_compressList blocks.val state.val _ rfl]

end rind.aarch64
