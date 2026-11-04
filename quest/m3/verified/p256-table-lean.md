# [L] rind's P-256 base-point table is proven in Lean

## Goal

The `Tabulated` hypothesis of aarch64 P-256's proofs is retired: a Lean proof shows that rind's generator table, which `admin/p256-precomp` writes, holds the multiples of G that s2n-bignum's `p256_scalarmulbase` theorem assumes (`p256_tabulates G 6`), so `benchmarks/verified.toml`'s P-256 entries no longer state the assumption.

## Plan

Decided with the maintainer on 2026-11-04, from [moq-dev/rind#336](https://github.com/moq-dev/rind/pull/336), to keep the ✓ with the assumption stated until this lands. s2n-bignum's theorem takes the table as an argument, so rind's own is unproven: only the `base_point_precomp` test checks it.

- The table's entries are multiples under `group_pow p256_group`, which `proofs/` keeps opaque. Proving them needs the group law stated concretely and tied to HOL Light's (`P256_GROUP` gives `group_mul` as `weierstrass_add`), which the composition rule does not yet allow beyond group membership. Settle with the maintainer how far to amend the rule before starting.
- The table has 43 rows of 32 points. Check the cost of kernel-checked evaluation against a proof that avoids recomputing each point; `native_decide` would add the compiler to the trust base.
