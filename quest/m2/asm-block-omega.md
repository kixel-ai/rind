# [M] The x86_64 bignum block proofs stop spending minutes in omega

## Goal

`omega` stops being the costliest tactic in rind's Lean proofs: the block lemmas of `bn_mul4x_mont`, `bn_mulx4x_mont`, and `bn_sqrx8x_internal` (`Rind/X86_64/Mul4xAsm.lean`, `Mul4xTailAsm.lean`, `Mulx4xAsm.lean`) and `Rind/Portable/Mont.lean`'s CIOS loop build in half their CPU time or less, with the same theorem statements.

Non-goals: weakening a statement or a side condition, or replacing a checked proof with an axiom, `native_decide`, or `bv_decide`'s compiled checker, which [the TCB ledger](/proofs/README.md#tcb--axiom-ledger) would have to trust.

## Plan

Measured 2026-11-27 with `profiler = true` and `profiler.threshold = 500` over all of `Rind` ([kixel-ai/rind#1176](https://github.com/kixel-ai/rind/pull/1176)): `omega` calls of 0.5 s or more add up to 1,337 s of the corpus's 10,087 CPU seconds, 580 s of them in `Mul4xAsm.lean`, 241 s in `Portable/Mont.lean`, 232 s in `Mulx4xAsm.lean`, and 96 s in `Mul4xTailAsm.lean`. Single calls take 1 to 18 s. In the assembly files they come from the block tactics, `mul4x_block` (`Rind/X86_64/Mul4xRun.lean`) and its copies, whose discharger tries each region a block may touch in turn with `bv_omega`, and whose last step calls `omega`; which of those calls are the slow ones is not known yet.

Tried on `Mul4xAsm.lean` alone, run beside an unchanged copy under the same load, and refused:

- `omega` without `splitDisjunctions` in the region alternatives: the proofs fail, since `omega` needs case splits for truncated subtraction.
- Clearing the four separation disjunctions before the region alternatives: no change (130 s against 127 s wall).
- `simp only [bitvec_to_nat]` on the goal alone instead of `bv_omega`'s `at *`: 111 s against 115 s wall, within noise.

Next: find which calls are slow with `set_option trace.profiler true` and `trace.omega` on one block lemma, such as `first_ok`, and whether they are failed alternatives, the `Apart` goals, or the block tactic's final `omega`. Then pick the region from the address's base syntactically, or state the facts a goal needs as `have`s so `omega` sees fewer atoms.

## Related

- [Every Lean file in rind's proofs is a module](/quest/m2/lean-modules.md) - the other lever on the same build
