# [M] AES-GCM on x86_64 with AVX-512 runs pyca/verified-garbage's code where it is faster

## Goal

On x86_64 CPUs with AVX-512, VAES, and VPCLMULQDQ, AES-GCM seal and open run pyca/verified-garbage's (VG) AVX-512 kernels under rind's glue and behavior at every direction and message length where VG measures at least as fast as what rind runs there today, and rind's own code everywhere else.

## Plan

Decided 2026-11-21 (orchestrator, for the maintainer, in [kixel-ai/rind#949](https://github.com/kixel-ai/rind/pull/949)'s merge pick): ✅ keep this quest (rejected: drop it and record a reason in `benchmarks/gaps.toml`). It does not duplicate [the VAES proof quest](/quest/m4/verified/aes-gcm-x86-vaes.md), which proves BoringSSL's kernels and plans no switch; each links the other.

- Found by `fedora`'s first report run (Ryzen 9 9950X, Zen 5), two quiet runs at [`8451c61f`](https://github.com/kixel-ai/rind/commit/8451c61f2ff869812224ab83a75f58d82d84a4a7) and [`fbdc801e`](https://github.com/kixel-ai/rind/commit/fbdc801e090ec1d476a01ca8c24be688baed5a7f), in ns, rind / VG per run:

  | Size | AES-128 seal | AES-128 open | AES-256 seal | AES-256 open |
  |---|---|---|---|---|
  | 32 B | 26/33, 29/35 | 26/31, 31/33 | 28/36, 30/37 | 27/34, 28/35 |
  | 1350 B | 87/84, 91/86 | 82/107, 86/108 | 105/91, 106/93 | 88/110, 95/121 |
  | 16 KB | 501/450, 506/470 | 564/502, 650/587 | 584/527, 626/578 | 628/590, 680/649 |

  VG wins seal at 1350 B and 16 KB (by 1.03 to 1.15×) and open at 16 KB (1.05 to 1.12×). rind wins every size at 32 B and open at 1350 B. So this is a length switch per direction, not a whole switch.
- What runs today (`low/x86_64/aes_gcm_vaes.rs`): rind's AVX-512 by-16 and by-8 intrinsics below 2 KB, and BoringSSL's `aes_gcm_{enc,dec}_update_vaes_avx512` from 2 KB. VG's candidates at `0aa40d6c` are `vg_aes_gcm_{encrypt,decrypt}_blocks_vaes_vpclmul_avx512` and their `_prepared_` forms, which take a precomputed key-power table, as rind's key does.
- Re-measure seal and open at every AEAD size the speed bar sets (32, 128, 256, 512, 1200, 1350 B, 16 KB) and at 2 KB, 4 KB, and 8 KB around BoringSSL's threshold, on the weekly bench's `x86_64` tier (Zen 4 and Xeon runners) and `fedora`, with a `bench` dispatch naming `aes_gcm`. Switch each direction from the shortest length where VG holds on every AVX-512 CPU measured. If VG takes everything from 2 KB, it retires BoringSSL's AVX-512 kernels, and [the VAES proof quest](/quest/m4/verified/aes-gcm-x86-vaes.md) drops them.
- Take VG's lowest routine that leaves rind's API and behavior intact, and keep rind's glue, as [the epic](/quest/m2/verified-garbage/README.md)'s Plan settles. Prefer a `_prepared_` form whose table rind's key setup can build once, so the per-message cost has no key expansion. Vendor it with `admin/import-vg`.
- Wycheproof and the aws-lc-rs differential tests already cover AES-GCM. Extend the ctgrind tests to the new path.
- Drop `benchmarks/gaps.toml`'s `fedora` AES-GCM entry once the next `fedora` run shows the gap closed.
