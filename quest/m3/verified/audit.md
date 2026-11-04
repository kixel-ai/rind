# [M] Verification audit

## Goal

A report, kept in the PR and summarized in the [epic](/quest/m3/verified/README.md), lists every exported operation on every path. For each it gives the code that runs, which parts a published proof covers and which proof, and the cheapest route to a whole-computation proof for every unproven part, ordered by how common the operation is.

## Plan

See the epic for the routes and the settled decisions.

- Start from `benchmarks/verified.toml` (the report's ✓ table) and README's Sources table, and extend them rather than duplicating them.
- For each gap, estimate the work and the speed cost of each route, citing tools and existing proofs, such as HACL*'s SHA-2, HMAC, and HKDF, libcrux's AEADs, and s2n-bignum's ECDSA pieces.
- Plan no quests yourself; the maintainer plans them from the report.
