# [M] x86_64 SHA-2 bulk as fast as OpenSSL

## Goal

SHA-512 on x86_64, and SHA-256 on CPUs without the SHA extensions, hash long messages as fast as OpenSSL.

## Plan

Planned on 2026-11-04 from the first [BENCHMARKS.md](/BENCHMARKS.md) (the maintainer delegated the gap triage). Lower priority than the [RSA-2048](/quest/m2/speed/x86-rsa2048-sign.md) and [short SHA-256](/quest/m2/speed/x86-sha256-short.md) gaps.

- rind's time at 16 KB over OpenSSL's: SHA-512 1.37 on `nixos` (Zen 3), 1.16 on `desktop` (Arrow Lake), and 1.15 on `nixos2` (i7-8700); SHA-256 1.11 on `nixos2`, which lacks the SHA extensions. Every other library is level with rind there.
- rind runs aws-lc's SHA-512 routines: its scalar one on AMD and its verified ✓ AVX one on Intel, and aws-lc's AVX SHA-256 on Intel without the SHA extensions. aws-lc carries no AVX2 and BMI2 routine for either hash, which OpenSSL has: the first lead. Arrow Lake's SHA-512 instructions are another, if a permissive source uses them.
- A faster unverified routine replaces the verified AVX one on Intel only when it is more than about 10% faster; per the maintainer, a clear slowdown still loses to speed, and the ✓ goes with it.
- Measure on the GitHub runners and the report's hosts, and remove this gap's entries from `benchmarks/gaps.toml` when the report's refresh shows them closed.
