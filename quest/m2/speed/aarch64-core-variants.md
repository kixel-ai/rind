# [M] aarch64 runs s2n-bignum's faster verified variant for each core

## Goal

On aarch64, each curve operation that s2n-bignum ships in two verified variants (such as `curve25519_x25519` and `curve25519_x25519_alt`) runs the faster one on Apple cores and on Neoverse cores, chosen by `MIDR_EL1` where they differ.

## Plan

Decided with the maintainer on 2026-11-07: plan in m2 speed the optimizations only the maintainer's hardware can measure. `kixtop` is an Apple M4, and GitHub has Neoverse N2 and a virtual M1. s2n-bignum's aarch64 non-`_alt` routines mix in SIMD multiplies tuned for Graviton, while `_alt` is scalar. Apple's wide scalar multipliers may favour `_alt`. Both variants are verified, so the faster wins with no tie margin.

- Inventory the pairs rind uses on aarch64: X25519 and its base-point form, Ed25519's scalar multiplications, and the P-256, P-384, and P-521 field and point routines. Note which of them rind imports today.
- Time each pair on `kixtop` (M4, held with `quest gate --host kixtop`), GitHub's macOS runner (M1, virtual), and GitHub's N2 runner, comparing only matching `CPU:` lines.
- Where the faster variant differs by core, dispatch on `MIDR_EL1` once at CPU detection, as `rind/src/low/aarch64/cpu.rs` already reads it for DIT. Where one variant wins everywhere, switch to it and keep no dispatch.
- Update the Lean proofs' dispatch hypotheses for any new branch (`admin/prove`), import any new variant through the existing s2n-bignum tooling, and run ctgrind on the changed paths.
