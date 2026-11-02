# [S] AES-GCM key setup as fast as the fastest source

## Goal

Creating and dropping an AES-GCM key runs at least as fast as the fastest source. Bench run [41472308771](https://github.com/moq-dev/rind/actions/runs/41472308771) timed it (`aes{128,256}-gcm/*/key`) at 1.20x ring on x86_64 (Zen 3, VAES), 1.47x aws-lc-rs without AVX, 1.13x without AES-NI, 1.55x aws-lc-rs on aarch64, 1.28x without the crypto extension, and 1.66x on armv7. After HKDF, as rustls makes one, rind's faster expansion hides most of it on x86_64 (1.02x) but not on aarch64 (1.11x).

## Plan

Planned with the maintainer on 2026-11-02 from the speed audit ([moq-dev/rind#191](https://github.com/moq-dev/rind/pull/191)). Ranked by MoQ impact (armv7 first: it is MoQ's Android target). Measure on the GitHub bench runners, not the shared local host.

[moq-dev/rind#239](https://github.com/moq-dev/rind/pull/239) shortened the x86_64 and aarch64 key schedules and GHASH power chains and wiped each key once. What remains is mostly the work around them:

- Moves between `AesKey::new`, `GhashTable::new`, `AesGcm::new`, and `aead::Key::new`: `memcpy` was about a third of the remaining instructions under callgrind on x86_64. Building in place needs a fill-by-reference constructor at each layer; `#[inline]` alone added copies.
- Powers held twice, each copy built, moved, and wiped: aarch64's `PmullTable` as `powers`/`powers_xor` and as s2n-bignum's `htable`, and x86_64's AVX and VAES kernels beside their `ClmulTable`.
- x86_64 checks `cpu::has` about five times per key.
- armv7 runs aws-lc's own key schedule and GHASH setup, so its gap is all such overhead. The run predates [moq-dev/rind#230](https://github.com/moq-dev/rind/pull/230)'s word-wide armv7 wipes; re-measure first.
- Without AVX, aws-lc-rs sets up a key faster (118 ns) than with it (142 ns on another core); compare its `aeskeygenassist` schedule with rind's `aesenclast` one there.
