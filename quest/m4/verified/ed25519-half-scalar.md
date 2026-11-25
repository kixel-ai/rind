# [L] Ed25519 verification on x86_64 is proven again

## Goal

`ed25519-verify` earns the ✓ again on x86_64 wherever s2n-bignum's point routines run it (with ADX, and Intel CPUs with AVX but not AVX2): rind's Lean proof covers the half-size check `mid::ed25519::VerifyingKey::commits` from the signature API down to s2n-bignum's contracts, and `ed25519_public_key_new` and `ed25519_key_pair_verify` hold on x86_64 as they do on aarch64.

## Plan

- Done: `Rind/X86_64/Ed25519Verify.lean` proves `commits`, `verify`, `ed25519_public_key_new`, and `ed25519_key_pair_verify` on x86_64, over `Rind/Ed25519Group.lean`'s `half_size_iff`, the correctness argument in `mid/half_size.rs`'s module doc, and `Rind/X86_64/HalfSize.lean`'s proof of `mid::half_size::split`. `edMul` and `edPow` transliterate HOL Light's `edwards_add` and `group_pow`, whose group laws `Rind/Edwards.lean` proves, as [kixel-ai/rind#646](https://github.com/kixel-ai/rind/pull/646) first did. The theorems take two hypotheses that no axiom states: `RunsMsm`, the multi-scalar multiplication's contract, and `EdOrders`, the group's orders. So the ✓ waits on the rest.
- Prove `EdOrders`, then delete it, by `Rind/NistOrder.lean`'s elementary count, since Mathlib has no Hasse bound.
  - Each y gives at most two points, so the group has at most `2p + 2`.
  - `B` has order `L`, a kernel computation: prove `Rind/SpecTest/Upstream.lean`'s double-and-add `edPow` equal to the spec's through the group law, and evaluate `[L]B` in the kernel, as `Rind/NistGroup.lean` checks the NIST generators' orders.
  - A point of order 8 is checked the same way.
  - So `8L` divides the group's size, which is `8L` since `16L > 2p + 2`, and Lagrange gives every point's `[8L]P = O`.
- Prove `RunsMsm`, then delete it. `low::x86_64::adx_mux::edwards25519_msm`, opaque in `Rind/X86_64/FunsExternal.lean`, dispatches to `low::generic::edwards25519_msm` everywhere but AVX2 without ADX, whose port [its own quest](/quest/m4/verified/ed25519-avx2-verify.md) proves: Straus's method over width-5 non-adjacent forms of `u` and `v`, tables of `-R`'s and `±A`'s odd multiples, and width-8 forms over static 64-entry tables of `B`'s and `[2^128]B`'s odd multiples, on s2n-bignum's `edwards25519_epadd`, `edwards25519_epdouble`, and `edwards25519_pdouble` (and their `_alt` twins), whose HOL Light theorems hold every output fully reduced. That needs those routines' contracts as axioms, as `Rind/X86_64/S2nBignum.lean` states the others, in `Rind.X86_64.Ed25519Verify`'s `Projective` and `ExProjective`; the static tables proven to hold `B`'s and `[2^128]B`'s odd multiples, as `Rind/Aarch64/P256Table.lean` proves P-256's; and the recoding's sum, as `Rind/X86_64/Naf.lean` proves P-256's.
- Then move `mid_verify_spec` and the three theorems above it back from both targets' `Ed25519Verify.lean` into the shared `Rind/X86_64/Ed25519.lean`, once [the aarch64 measurement](/quest/m2/speed/ed25519-half-scalar-aarch64.md) settles which check aarch64 runs, and give `ed25519-verify` back to x86_64's ✓ rows in `benchmarks/verified.toml`: Intel's AVX without AVX2, and AVX2 with ADX, which [kixel-ai/rind#629](https://github.com/kixel-ai/rind/pull/629) proved over s2n-bignum's `edwards25519_scalarmuldouble` and [kixel-ai/rind#768](https://github.com/kixel-ai/rind/pull/768) dropped (maintainer, [2026-11-15](https://github.com/kixel-ai/rind/pull/768#issuecomment-6889289395): land the speedup and drop the ✓ until this proves the new check ✅, rejected: hold x86_64 on the proven routine until then; remeasure first). The AVX2 sign row's proof text then names verification and the routines it adds again.

## Related

- [Ed25519 verification on AVX2 without ADX is proven](/quest/m4/verified/ed25519-avx2-verify.md) - the AVX2 tier's four-point multiplication, on top of this one's split and identity test
- [aarch64's Ed25519 verification uses half-size scalars](/quest/m2/speed/ed25519-half-scalar-aarch64.md) - decides whether aarch64's proof moves to this check too
