# [M] ChaCha20-Poly1305 on x86_64 with AVX-512 runs pyca/verified-garbage's code where it is faster

## Goal

On x86_64 CPUs with AVX-512, ChaCha20-Poly1305 and XChaCha20-Poly1305 seal and open run pyca/verified-garbage's (VG) AVX-512 one-pass routines under rind's glue and behavior at every message length where VG measures at least as fast as aws-lc's stitched AVX2 routine, which rind runs on every AVX2 tier today, or OpenSSL's AVX-512 code at the lengths where that is faster still.

## Plan

Decided 2026-11-21 (orchestrator, for the maintainer, in [kixel-ai/rind#949](https://github.com/kixel-ai/rind/pull/949)'s merge pick): ✅ keep this quest (rejected: drop it and record a reason in `benchmarks/gaps.toml`). It does not duplicate [the m4 x86_64 epic](/quest/m4/verified/chacha20-poly1305-x86/README.md), which proves the code rind runs today and plans no switch.

- Found by `fedora`'s first report run (Ryzen 9 9950X, Zen 5), two quiet runs at [`8451c61f`](https://github.com/kixel-ai/rind/commit/8451c61f2ff869812224ab83a75f58d82d84a4a7) and [`fbdc801e`](https://github.com/kixel-ai/rind/commit/fbdc801e090ec1d476a01ca8c24be688baed5a7f), seal in ns, rind / VG / OpenSSL: 32 B 135-157 / 128-143 / 270-289, 1350 B 480-515 / 359-386 / 610-644, 16 KB 4422-4708 / 2677-2783 / 2552-2669. rind takes the same time as ring and aws-lc-rs, which run the same aws-lc routine, so it is the routine and not rind's glue. rustls's 1 MB ChaCha20-Poly1305 transfer trails OpenSSL's provider by 1.54× for the same reason.
- This reopens a cell [the epic](/quest/m2/verified-garbage/README.md) closed on 2026-11-13, when VG at `d004ffae` lost at 512 B with AVX-512 (1.14) on the weekly tier's Zen 4. The pin is now `0aa40d6c`, whose x86_64 AEAD has `_avx512`, `_avx512vl`, and `_ifma` variants of `vg_chacha20_poly1305_{seal,open}` (and `_seal_split`, `_open_body_avx512vl_large`).
- Re-measure at every AEAD size the speed bar sets (32, 128, 256, 512, 1200, 1350 B, 16 KB), seal and open, on the weekly bench's `x86_64` tier (Zen 4 and Xeon runners) and `fedora`, with a `bench` dispatch naming `chacha20poly1305 xchacha20poly1305`. Switch each variant at the lengths where it holds on every AVX-512 CPU measured, as `cipher::ChaCha20` takes VG from 256 bytes ([kixel-ai/rind#811](https://github.com/kixel-ai/rind/pull/811)). Pick between `_avx512`, `_avx512vl`, and `_ifma` by measurement, not by name.
- OpenSSL's AVX-512 code was 4 to 5% faster than VG at 16 KB on Zen 5 and twice as slow at 32 B. AGENTS.md's source rule takes VG only where it is as fast at every size, so measure OpenSSL's routines at the long lengths too. Where they are faster on every AVX-512 CPU measured, OpenSSL's run there (Apache-2.0), and this quest's PR adds a quest under [the m4 verified epic](/quest/m4/verified/README.md) for their proof.
- Take VG's lowest routine that leaves rind's API and behavior intact, and keep rind's glue, as the epic's Plan settles. Vendor it with `admin/import-vg`. The AVX2 and SSE4.1 tiers keep aws-lc's routine.
- Wycheproof and the aws-lc-rs differential tests already cover the AEAD. Extend the ctgrind tests to the new path.
- Drop `benchmarks/gaps.toml`'s `fedora` ChaCha20-Poly1305 entry once the next `fedora` run shows the gap closed.
