# [L] Ed25519 verification on AVX2 without ADX is proven

## Goal

Ed25519 verification on x86_64 CPUs with AVX2 but without ADX (Haswell, and virtual CPUs that hide ADX) drops the `RunsDouble` hypothesis: rind's port of curve25519-dalek's AVX2 backend, which computes `[S]B - [k]A` there, is proven, so `ed25519-verify` earns the ✓ on the no-ADX tier.

## Plan

- Runs: `low/x86_64/edwards25519_scalarmuldouble_avx2.rs`, about 1,550 lines of AVX2 intrinsics: dalek's field arithmetic over four lanes of 25.5-bit limbs, its extended-coordinate point formulas, width-5 and width-8 non-adjacent forms of the two public scalars, and a 10 KiB table of the base point's odd multiples. It is variable-time over public inputs only. It measured 1.08x curve25519-dalek's time against 1.30x for s2n-bignum's proven `edwards25519_scalarmuldouble_alt`, so switching back fails the speed rule.
- In place: `admin/prove` translates the module, its intrinsics modelled in `proofs/Rind/X86_64/Avx2.lean` and tested on hardware by `admin/simd-vectors.rs`. `Rind/Ed25519.lean`'s `edMul` and `edPow` transliterate HOL Light, and `Rind/Ed25519Group.lean` proves them the group of `Rind/Edwards.lean`, vendored from the Beneficial AI Foundation's dalek simulation. Proven: dalek's doubling, addition, `Cached::from`, and `Cached::neg` over the field (`Rind/Ed25519Points.lean`), the base point table (`Rind/X86_64/Ed25519Avx2Table.lean`), and the non-adjacent forms (`Rind/X86_64/Ed25519Avx2Naf.lean`). `S2nBignum.lean` states `bignum_mul_p25519_alt` and `bignum_inv_p25519`'s contracts, which the wrapper calls.
- Remains, in `Rind/X86_64/`:
  - Lane lemmas: `lane32 (ofLanes32 f) i = f i` and its 64-bit and unpacked forms, so each `Fe4` loop (`shuffle`, `blend`, `add`, `negate_lazy`, `diff_sum`, `unpack`, `mul_small`) states per-lane limbs as `Rind/Ed25519Limbs.lean`'s `limbsOf`.
  - The field: `mul`, `square_and_negate_d`, `reduce64`, `reduce`, and `neg` give each lane's value mod p, under dalek's limb bounds, with no 32- or 64-bit lane overflowing; the products' sums are a ring identity once `2^255 = 19`.
  - The points: `Extended::double` and `add`, `Cached::from`, `neg`, and `load` keep `IsExtended` and `IsCached` of the lanes' values, and bounds each next call accepts.
  - The loop: `double_base`'s odd multiples of `A`, its `top`, and its main loop's invariant `q = Σ_{j ≥ i} (a_j A + b_j B) 2^(j - i)`, from the NAF and table specs.
  - The wrapper: `Fe4::new`, `split`, and `reduce_to_words`, and `edwards25519_scalarmuldouble` meeting s2n-bignum's contract for a point with reduced coordinates and scalars below 2^255; then `RunsDouble` goes from `edwards25519_scalarmuldouble_mux_spec` and its callers, with the axiom guards, `proofs/README.md`, and the verified marks.
