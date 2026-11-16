# [M] cipher::ChaCha20 earns the ✓ from pyca/verified-garbage's proof

## Goal

Every VG routine `cipher::ChaCha20` runs is imported as a theorem, so it earns the ✓ on the tiers and lengths that run it: on x86_64, `vg_chacha20_init` with `vg_chacha20_apply_avx2` and `vg_chacha20_apply_avx512vl` from 256 bytes ([kixel-ai/rind#811](https://github.com/kixel-ai/rind/pull/811)), and on aarch64 whatever [its switch](/quest/m2/verified-garbage/chacha20.md) adopts.

## Plan

- Import each routine's VG theorem as one axiom about rind's opaque wrapper, under [the m3 epic's composition rule](/quest/m3/verified/README.md), as [the epic](/quest/m2/verified-garbage/README.md)'s Plan settles, and add the `benchmarks/verified.toml` entries for the switched tiers.
- Prove rind's glue around it as the m3 and m4 epics prove rind's other glue: on x86_64, the split that runs a tail of two to four blocks after VG's eight-block loop on rind's two-block kernel, which [the x86_64 cipher proof](/quest/m4/verified/chacha20-poly1305-x86/cipher.md) proves, and the counter it resumes from.
- [The cosimulation quest](/quest/m2/verified-garbage/cosim.md) does not cover this routine's instructions; extend it here.

## Required

- [VG's ISA models are cosimulated](/quest/m2/verified-garbage/cosim.md) - the cosimulation harness this extends
