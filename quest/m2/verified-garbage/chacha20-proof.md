# [M] cipher::ChaCha20 earns the ✓ from pyca/verified-garbage's proof

## Goal

Every VG routine `cipher::ChaCha20` runs is imported as a theorem, so it earns the ✓ on the tiers and lengths that run it: on x86_64, `vg_chacha20_init` with `vg_chacha20_apply_avx2` and `vg_chacha20_apply_avx512vl` from 256 bytes ([kixel-ai/rind#811](https://github.com/kixel-ai/rind/pull/811)), and on aarch64 whatever [its switch](/quest/m2/verified-garbage/chacha20.md) adopts.

## Plan

- x86_64's import and glue landed in [kixel-ai/rind#853](https://github.com/kixel-ai/rind/pull/853): `Rind/X86_64/VgChaCha20.lean` restates `Stream.init_verified` and `Stream.apply_verified` for AVX2 and AVX-512 VL as one axiom per wrapper, and proves `chacha20_apply_keystream` from them over the split and the counter the kernel's tail resumes from, with the kernel's contract as the hypothesis `Kernel`, which [the x86_64 cipher proof](/quest/m4/verified/chacha20-poly1305-x86/cipher.md) discharges. What is left there is the ✓ itself, in `ALGORITHMS.md`'s rows and its `verified-garbage` dependency row, once `admin/import-vg` re-pins to VG's x86-64 fix.
- aarch64: import each routine its switch adopts the same way, under [the m3 epic's composition rule](/quest/m3/verified/README.md), as [the epic](/quest/m2/verified-garbage/README.md)'s Plan settles, and prove rind's glue around it. The AArch64 model at `admin/import-vg`'s pin has the stack-slot fix ([pyca/verified-garbage#5391](https://github.com/pyca/verified-garbage/pull/5391)), so that ✓ waits only on the switch.
- `benchmarks/verified.toml` takes no entry: bare ChaCha20 is not a report row, and the report's ChaCha20-Poly1305 rows run aws-lc's one-pass routines, not these.
- Model gaps, which the maintainer ruled on 2026-11-17 ([kixel-ai/rind#815](https://github.com/kixel-ai/rind/pull/815#issuecomment-6943056592)) as [the epic](/quest/m2/verified-garbage/README.md)'s Plan records: ✅ the stack-slot gap is reported upstream and this ✓ waits for VG's fix and a re-pin (rejected: a rind-side check that each stack load reads only bytes its own frame stored; accepting the model as is). ✅ The `NoResidue` undefined-flags gap is reported upstream and does not hold this ✓, since rind imports no `NoResidue` theorem (rejected: not reporting it).

## Waiting

- pyca/verified-garbage: fix the x86-64 stack-slot model, [pyca/verified-garbage#5378](https://github.com/pyca/verified-garbage/pull/5378) (a freed frame's bytes keep their values in the model, so a proof can read back a value hardware may have lost; [#5321](https://github.com/pyca/verified-garbage/issues/5321) closed with the AArch64 and RISC-V fixes only); then re-pin `admin/import-vg`'s `REV`, which `admin/import-vg-models` also reads, to a commit with it. Check: `admin/import-vg`'s `REV` contains the PR's merge commit, `0aa40d6c` (merged 2026-11-17, after this quest's re-pin to `9eed89c2`).

## Required

- [aarch64 cipher::ChaCha20 runs pyca/verified-garbage's code where it is faster](/quest/m2/verified-garbage/chacha20.md) - the aarch64 routines this proves
