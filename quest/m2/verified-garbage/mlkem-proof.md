# [M] ML-KEM-768 earns the ✓ from pyca/verified-garbage's proof

## Goal

Every VG routine ML-KEM-768 runs is imported as a theorem, so ML-KEM-768 earns the ✓ on the tiers that run it: its encapsulation key check and encapsulation on every x86_64 CPU and on aarch64 with the SHA-3 instructions, and its key generation and decapsulation on x86_64 with AVX-512 (`low/<arch>/mlkem768_vg.rs`, vendored by `admin/import-vg`).

## Plan

- Import each routine's VG theorem as one axiom about rind's opaque wrapper, under [the m3 epic's composition rule](/quest/m3/verified/README.md), as [the epic](/quest/m2/verified-garbage/README.md)'s Plan settles, and add the `benchmarks/verified.toml` entries for the switched tiers.
- Prove rind's glue around it as the m3 and m4 epics prove rind's other glue: `mid/mlkem.rs` picks VG's routine per key, encodes a VG key as FIPS 203's `dk` for decapsulation, and falls back to rind's arithmetic when a routine reports that a `SampleNTT` reached VG's bound.
- That fallback is rind's arithmetic, which on CPUs with AVX-512 VBMI2 samples the matrix with Graviola's unproven AVX-512 eight-way sampler (`low/x86_64/mlkem_sample_poly_ntt_8x.rs`), the only path on which ML-KEM-768 still runs it. The ✓ needs it covered: recommended, route the fallback to the proven four-way sampler, since speed does not matter at a probability below 2^-261, rather than prove the sampler.
- Elsewhere ML-KEM-768 keeps rind's arithmetic, whose ✓ [the construction quest](/quest/m4/verified/mlkem-construction.md) and [the portable arithmetic quest](/quest/m4/verified/mlkem-portable.md) cover.

## Required

- [VG's ISA models are cosimulated](/quest/m2/verified-garbage/cosim.md) - the instructions those routines run, checked against the CPU
