# [M] x86_64 RSA-2048 signing as fast as ring and graviola

## Goal

RSA-2048 PKCS#1 and PSS signing on x86_64 with ADX is level with ring and graviola, and with it the full handshake under an RSA-2048 certificate. JWT's RS256, the most common JWT algorithm, reaches the [adoption epic](/quest/m2/adoption/README.md)'s Bun, pyrind, and llrt through it.

## Plan

Planned on 2026-11-04 from the first [BENCHMARKS.md](/BENCHMARKS.md) (the maintainer delegated the gap triage).

- rind's signing time over the fastest: 1.12-1.15 on `nixos` (Zen 3, graviola and ring), 1.11-1.19 on `desktop` (Arrow Lake, all three others), and 1.20-1.31 on `nixos2` (i7-8700, every other library). The RSA-2048 full handshake follows: graviola 1.11-1.13, and ring 1.19 on `nixos2`.
- A sign is two 1024-bit exponentiations, 16 words each. Since [moq-dev/rind#224](https://github.com/moq-dev/rind/pull/224), with ADX they run s2n-bignum's verified Karatsuba and gather each window entry with s2n-bignum's scalar `bignum_copy_row_from_table`, which that PR measured at about 3,800 instructions per gather at 17 words. graviola runs the same Karatsuba with a 4-bit window and its AVX2 `bignum_copy_row_from_table_16_avx2`, which #224 deleted, so the gather is the first lead. The maintainer kept Karatsuba over aws-lc's `bn_powerx5` at 16 words there (it trailed 13% on Zen 5); don't reopen that without new numbers.
- Time the gather, the window width, and the CRT and fault-check glue around the exponentiations before picking a change. A faster gather that is unverified loses its place to a verified one within about 10%.
- Cover a new path in ctgrind and the forced-path tests.
- Measure on the GitHub runners and the report's hosts, and remove this gap's entries from `benchmarks/gaps.toml` when the report's refresh shows them closed.
