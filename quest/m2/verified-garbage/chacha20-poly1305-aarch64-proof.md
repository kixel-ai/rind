# [M] ChaCha20-Poly1305 on aarch64 earns the ✓ from pyca/verified-garbage's proof

## Goal

VG's SVE2 `vg_chacha20_poly1305_seal_sve2` and `vg_chacha20_poly1305_open_sve2`, which rind runs on aarch64 CPUs with SVE2 (`rind/src/low/aarch64/chacha20poly1305.rs`), are imported as theorems, so ChaCha20-Poly1305 and XChaCha20-Poly1305's one pass on aarch64 earn the ✓ on SVE2 CPUs.

## Plan

- Import each routine's VG theorem as one axiom about rind's opaque wrapper, under [the m3 epic's composition rule](/quest/m3/verified/README.md), as [the epic](/quest/m2/verified-garbage/README.md)'s Plan settles, and add the `benchmarks/verified.toml` entries for the switched tiers.
- Prove rind's glue around it as the m3 and m4 epics prove rind's other glue.
- The ✓'s CPU features: `rind-cpuid` and `admin/bench-report`'s `CPU_FEATURES` name no `sve2` yet; add it, so the entries can require it.

## Required

- [VG's ISA models are cosimulated](/quest/m2/verified-garbage/cosim.md) - the instructions those routines run, checked against the CPU
