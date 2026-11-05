# [S] x86_64 SHA-256 of short messages as fast as RustCrypto

## Goal

SHA-256 of a 64 B message on x86_64 with the SHA extensions is level with RustCrypto and graviola, without slowing longer messages.

## Plan

Planned on 2026-11-04 from the first [BENCHMARKS.md](/BENCHMARKS.md) (the maintainer delegated the gap triage).

- rind's time at 64 B over RustCrypto's is 1.38 on `nixos` (Zen 3, 80 ns against 58) and 1.44 on `desktop` (Arrow Lake, 56 ns against 39); over graviola's, 1.18 and 1.40. From 1350 B rind is level. Short hashes dominate HMAC and HKDF in a TLS handshake.
- The closed sha256-64b quest only reached ring. rind runs graviola's SHA-NI block routine, so the 13-16 ns rind spends over graviola is glue around it: the `digest::Context`, the entry guard, buffering, padding, and finishing. On Zen 3, RustCrypto is 9 ns faster than graviola as well, so its block routine or finish is worth reading too.
- [moq-dev/rind#338](https://github.com/moq-dev/rind/pull/338) proves SHA-256's glue with Aeneas and Lean. Once it merges, keep the glue translatable by Aeneas and its proofs passing.
- Measure on the GitHub runners and the report's hosts, and remove this gap's entry from `benchmarks/gaps.toml` when the report's refresh shows it closed.
