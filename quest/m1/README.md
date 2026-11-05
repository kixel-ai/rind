# m1: MoQ coverage

## Goal

rind carries everything [MoQ](https://github.com/moq-dev/moq) needs to take
all its cryptography from rind, on every target MoQ releases, and publishes it.

## Required

- [rind covers MoQ](/quest/m1/moq/README.md) - the primitives, CPU check, armv7 backend, and `rind-*` adapters MoQ needs, verified and released
- [Benchmark report on real hardware](/quest/m1/benchmarks/README.md) - BENCHMARKS.md compares rind with the usual libraries on real machines, with build cost and ✓ for verified code, linked from a README that sells rind
- [A prompt migrates a repo to rind](/quest/m1/migration-prompt.md) - a copy-paste prompt has an agent move a repo to rind and report build time, size, and benchmarks before and after
- [The README shows how to use rind and links the details](/quest/m1/readme-restructure.md) - usage, the migration prompt, and an invitation to AI contributors, with the details in linked docs
