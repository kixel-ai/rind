# [L] Ed25519 verification on AVX2 without ADX is proven

## Goal

Ed25519 verification on x86_64 CPUs with AVX2 but without ADX (Haswell, and virtual CPUs that hide ADX) drops the `RunsDouble` hypothesis: rind's port of curve25519-dalek's AVX2 backend, which computes `[S]B - [k]A` there, is proven, so `ed25519-verify` earns the ✓ on the no-ADX tier.

## Plan

- Runs: `low/x86_64/edwards25519_scalarmuldouble_avx2.rs`, about 1,300 lines of AVX2 intrinsics: dalek's field arithmetic over four lanes of 25.5-bit limbs, its extended-coordinate point formulas, width-5 and width-8 non-adjacent forms of the two public scalars, and a 10 KiB table of the base point's odd multiples. It is variable-time over public inputs only. It measured 1.08x curve25519-dalek's time against 1.30x for s2n-bignum's proven `edwards25519_scalarmuldouble_alt`, so switching back fails the speed rule.
- Route: Aeneas to Lean, the AVX2 intrinsics modelled as `Rind/X86_64/Simd.lean` models AES-GCM's, against `Rind/Ed25519.lean`'s spec, with a table proof like `Rind/Aarch64/P256Table.lean`. Reuse any published Lean proof of curve25519-dalek's field and point layers where its lemmas fit.
