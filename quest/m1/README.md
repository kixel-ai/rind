# m1: MoQ coverage

## Goal

rind carries everything [MoQ](https://github.com/moq-dev/moq) needs to take
all its cryptography from rind, on every target MoQ releases, and publishes it.

## Required

- [rind covers MoQ](/quest/m1/moq/README.md) - the primitives, CPU check, armv7 backend, and `rind-*` adapters MoQ needs, verified and released
- [Every public entry point runs inside the entry guard](/quest/m1/entry-guard.md) - HMAC, HKDF, PBKDF2, digest, and constant-time compare get DIT and the CPU check
- [Benchmark report on real hardware](/quest/m1/benchmarks/README.md) - BENCHMARKS.md compares rind with the usual libraries on four machines, with build cost and ✓ for verified code, linked from a README that sells rind
