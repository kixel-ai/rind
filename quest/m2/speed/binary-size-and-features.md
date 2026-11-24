# [M] Shrink x86_64's rustls+rind-rustls binary toward aws-lc-rs's by sharing or dropping assembly tables and tiers

## Goal

A release `rustls + rind-rustls` client on x86_64 Linux shrinks from 5.44 MB stripped toward `aws-lc-rs`'s 4.11 MB without slowing a tier the benchmarks cover, and `admin/binary-size.txt` records each step.

## Plan

Planned with the maintainer on 2026-11-21 (`/quest-plan`): ✅ keep `rind`'s `default` feature enabling all algorithms (additive, no breaking change) and have `rind-rustls` opt into `default-features = false` with only what TLS needs (rejected: making legacy/niche algorithms opt-in in a breaking 0.5 release; skipping Cargo algorithm features).

Done in [kixel-ai/rind#1008](https://github.com/kixel-ai/rind/pull/1008): the `ml-dsa` and `slh-dsa` features, which the adapters leave off (5.67 MB to 5.44 MB on x86_64, 3.28 MB to 3.12 MB on aarch64); CPU checks that are true at compile time for features the target enables, so a build for one CPU links no lower tier (4.49 MB with `-C target-cpu=icelake-server`); and `admin/binary-size`, which `just ci` runs.

What is left is all on x86_64, whose three tiers (no ADX, ADX, AVX-512 IFMA) each carry their own routines: of the client's 5.44 MB, rind is 4.03 MB, the tables 0.72 MB, the IFMA routines 0.65 MB, the ADX ones 0.49 MB, the other AVX-512 ones 0.32 MB, and s2n-bignum's `_alt` twins 0.30 MB. Every routine left is one TLS reaches, so no Cargo feature removes more. Measure with `nm -S --size-sort -C` on `target/release/build-cost-rustls` after `admin/binary-size`. The candidates, largest first:

- `VG_P384_COMB`, 338 KB on x86_64 and aarch64: pyca/verified-garbage's table for P-384 `d·G`, beside rind's own 30 KB comb table that the remaining paths read.
- pyca/verified-garbage's IFMA RSA, 380 KB in three routines (`vg_rsa_public_precomputed_checked_ifma`, `vg_rsa_private_crt_precomputed_ifma`, and its `ifma512` twin), and its P-256 ECDSA verification, 136 KB with IFMA and 98 KB with ADX: each is one unrolled routine, so only a smaller routine from upstream, or dropping a tier, shrinks them.
- `VG_P256_COMB` and `mid::p256::precomp::CURVE_GENERATOR_PRECOMP`, 148 KB each and byte for byte the same table on x86_64: one for pyca/verified-garbage's ADX `d·G`, one for rind's Booth driver, which Lean proves over the translated table (`proofs/Rind/X86_64/P256Table.lean`). The routine reads it with unaligned loads, so the `u64` table's alignment is enough.

## Waiting

- Maintainer: share the P-256 generator table (148 KB, 2.7% of the client)? (a) point the generated `sym` operand of `vg_p256_mul_base_adx` at `mid`'s table, with `admin/structure` allowing that one generated line to name `mid` from `low`, `admin/vg-bytes` mapping the name, and a test holding the bytes to pyca/verified-garbage's (recommended: both proofs stand, and the code it runs reads a table Lean proves); (b) move the table into `low` and re-prove `P256Table.lean` over it, which keeps the layering but touches the proof; (c) leave both.
- Maintainer: trade P-384 `d·G` speed for 338 KB by running rind's 30 KB comb table in place of `VG_P384_COMB`? Recommended: no, unless a `bench` run of `ecdsa` and `agreement` shows the P-384 signing and key generation rows staying ahead of aws-lc-rs, since speed wins here; decide from that run.
- Maintainer: drop a whole x86_64 tier's routine for RSA or P-256 where a lower tier is within a few percent? Recommended: no for now, and ask pyca/verified-garbage for looped variants of its IFMA RSA and P-256 routines instead, which would shrink them without leaving a tier.
- Maintainer: add finer Cargo features to `rind` (`rsa`, `ec`, `hpke`, `legacy`, and so on, as the plan's first list suggests)? Recommended: no. The linker already drops every algorithm a program does not name; only `rind::KeyPair::from_pkcs8` links algorithms unnamed, which `ml-dsa` and `slh-dsa` cover, so more features would add build combinations to test and remove no bytes.

## Related

- [Gate coverage regressions, test feature powersets, and execute wasm32 tests](/quest/m2/confidence/coverage-powerset-wasm-gates.md)
