# [S] AES-GCM opens under 256 B run Vale's kernel on VAES CPUs

## Goal

On x86_64 CPUs with VAES, with or without AVX-512, AES-GCM opens under 256 B run Vale's kernel instead of rind's SSE `by8` loop, so an ACK-sized QUIC receive costs what Vale's tier costs on the same core. Seals keep whichever path measures fastest at each length.

## Plan

Approved by the maintainer on 2026-11-05, from [moq-dev/rind#387](https://github.com/moq-dev/rind/pull/387). Bulk encryption takes the fastest source outright, so this routing holds only where Vale measures fastest.

Today `low/x86_64/aes_gcm.rs` sends a message to Vale only when the GHASH table is `GhashTable::Avx` (AVX and MOVBE without VAES). `VaesAvx2` and `Avx512` run `by8` below 256 B, whose decrypt hashes the sub-128 B tail through the generic `ClmulTable::add` while its encrypt hashes each block inline. So opens trail seals at small sizes. Forcing Vale with `--cfg rind_cpu_disable` measured, as ratios to aws-lc-rs:

| | Arrow Lake | Zen 3 | Zen 4 | Zen 5 |
|---|---|---|---|---|
| open 32 B | 1.51 → 2.29 | 2.08 → 2.40 | 1.98 → 2.36 | 1.39 → 1.98 |
| open 64 B | 1.32 → 2.13 | 1.92 → 2.16 | 1.87 → 2.17 | 1.49 → 1.97 |
| seal 32 B | 1.96 → 2.03 | 2.28 → 2.17 | 2.17 → 1.99 | 1.73 → 1.79 |
| rustls recv 32 B | 1.04 → 1.50 | 1.52 → 1.97 | 1.45 → 2.01 | 1.44 → 1.90 |

- Give `VaesAvx2` and `Avx512` the key powers Vale's kernel reads, wiped with the rest of the table, and route short opens to it. Every VAES CPU has the AVX and MOVBE Vale needs.
- Measure the crossover per tier rather than assuming 256 B: Vale may also beat the VAES kernels a little above it, and seals stay on `by8` where it wins (Zen 3 and 4 at 32-64 B).
- Add 32 B and 64 B opens with a 13 B AAD, QUIC's short header, to `rind-bench`, whose existing rows don't separate them.
- Extend the length sweep in `aes_gcm.rs`'s tests across the new crossover on each tier.
