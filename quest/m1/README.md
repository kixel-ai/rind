# m1: MoQ coverage

## Goal

rind carries everything [MoQ](https://github.com/moq-dev/moq) needs to take
all its cryptography from rind, on every target MoQ releases, and publishes it.

## Required

- [rind covers MoQ](/quest/m1/moq/README.md) - the primitives, CPU check, armv7 backend, and `rind-*` adapters MoQ needs, verified and released
- [Benchmark report on real hardware](/quest/m1/benchmarks/README.md) - BENCHMARKS.md compares rind with the usual libraries on four machines, with build cost and ✓ for verified code, linked from a README that sells rind
- [A binary links only the algorithms it uses](/quest/m1/binary-size.md) - a minimal rind binary is near ring's size, not 5x it
- [rind-rustls lets a caller build a lean provider](/quest/m1/rustls-lean-provider.md) - a rustls client links only the algorithms it uses
- [README and the ✓ table claim only what is proven](/quest/m1/verified-claims.md) - the stale AES-GCM ✓ and the audit's other corrections
