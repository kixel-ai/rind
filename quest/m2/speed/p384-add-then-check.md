# [L] P-384 verification adds first and checks for equal points only at a zero z

## Goal

P-384 ECDSA verification's mixed addition, `public_add_affine` in `rind/src/mid/p384.rs`, adds first and compares y's only when the sum's z is zero, as P-256's does since [kixel-ai/rind#1074](https://github.com/kixel-ai/rind/pull/1074), wherever that measures faster on the same CPU; the proofs keep covering it.

## Plan

- Each addition now pays a squaring, a multiplication, and a compare before `p384_montjmixadd`. P-256's change took 3.2% off one-shot verification on armv7 (Neoverse-N2, 342.89 to 332.06 µs), up to 5% on an EPYC 7763 with ADX denied, and nothing on a Core Ultra 7 270K, whose out-of-order window seems to hide the check.
- Copy P-256's route: a HOL Light lemma per `p384_montjmixadd` block rind runs (x86_64 with and without ADX, aarch64's `_alt`), from s2n-bignum's simulation of the routine's code, that equal or opposite points leave z zero (`proofs/hol-light/<arch>/p256_montjmixadd*.ml` show how), restated in `Rind/<Arch>/S2nBignum.lean`'s `p384_montjmixadd_spec`, and `Rind/X86_64/P384Ecdsa.lean`'s `add_affine_spec` reworked as P-256's was. armv7 and the portable backend run rind's own formula in `low/generic/p384.rs`, over fiat-crypto's field, whose z is z1 times x2 z1² - x1, so they need no assembly lemma; check that it holds there and state it in that function's comment, as `low/generic/p256.rs` does.
- Bench `p384` before and after on runs that drew the same CPU; drop the change on any tier it slows.
