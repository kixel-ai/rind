# [M] Edge-limb tests for the unproven bignum assembly

## Goal

The Montgomery, RSAZ, and P-256 assembly that no proof covers is tested differentially on inputs built from edge-case limbs, and on aws-lc's `bn_tests.txt`, on every CPU tier that selects it. A carry dropped between limbs fails a test instead of needing a one-in-2^64 random input.

## Plan

Planned from the 2026-11-09 tooling audit. The routines are aws-lc's, imported unproven:

- `bn_mul_mont` and its 4x, 8x, and `mulx` variants (`rind/src/low/x86_64/mont.rs`, `aarch64/mont.rs`, `arm/mont.rs`);
- RSAZ on AVX2 and on AVX-512 IFMA, and the gathers beside them (`x86_64/rsaz.rs`, `rsaz_avx512.rs`, `mont_exp.rs`);
- the P-256 field and point routines (`x86_64/ecp_nistz256.rs`).

Today each has one or two differential tests over a fixed seed: 16 cases a size in `x86_64/mont.rs:260` and `aarch64/mont.rs:85`, 12 in `arm/mont.rs:148`, 24 in `rsaz.rs:312`, 16 a size in `rsaz_avx512.rs:368`, and two tests in `ecp_nistz256.rs:151,230`. They pin a few extremes, such as the widest and narrowest modulus and operands of zero and m - 1, and take the rest at random. `admin/sync-vectors` imports aws-lc's `miller_rabin_tests.txt` but not the `bn_tests.txt` beside it. Fuzzing does not help: libFuzzer sees no coverage inside assembly.

Their proofs are planned in m4. This quest covers the time until then, and the proofs retire its tests one routine at a time.

- Build operands and moduli limb by limb from a weighted set of zero, one, all ones, and the top bit, as Go's [`weirdLimbs`](https://go.dev/src/crypto/internal/fips140/edwards25519/field/fe_test.go) does. `rind/src/low/generic/bignum.rs:550` already has that strategy for the portable arithmetic; share it.
- The AVX-512 IFMA code works in 52-bit limbs, so its edge cases are limbs of 2^52 - 1, which no 64-bit word pattern produces. Build those inputs in its radix.
- For P-256, cover field elements at 0, p - 1, and the unreduced values a routine accepts, and the point cases the routines branch on: equal inputs, a point and its negation, and infinity.
- Compare with the portable arithmetic, as `matches_generic` does, or with s2n-bignum's proven routines.
- Import `bn_tests.txt` through `admin/sync-vectors` and run the `ModMul`, `ModSquare`, and `ModExp` cases whose sizes rind's routines take.
- These are unit tests: `just ci` runs them on the host's tier, and `build.yml`'s denied tiers, `x86-cpu.yml`'s SDE models, and `just armv7` inherit them. Keep the case count small enough for SDE.
- Add the new vector file and tests to [TESTING.md](/TESTING.md), which `admin/testing` then checks.

## Related

- [Surviving mutants that need crafted inputs](/quest/m2/confidence/mutants-edge-cases.md) - the same idea for rind's Rust, found by mutation testing
- [x86_64's other RSA Montgomery products are proven](/quest/m4/verified/rsa-x86-mont.md) - retires the x86_64 `bn_mul_mont` tests
- [aarch64's RSA Montgomery products are proven](/quest/m4/verified/rsa-aarch64-mont.md) - retires the aarch64 ones
- [x86_64's dual RSAZ IFMA exponentiation is proven](/quest/m4/verified/rsa-x86-ifma.md) - retires the AVX-512 ones
- [P-256 ECDH and ECDSA are proven on x86_64](/quest/m4/verified/p256-x86.md) - retires the P-256 ones
