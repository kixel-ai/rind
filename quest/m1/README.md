# m1: MoQ coverage

## Goal

rind carries everything [MoQ](https://github.com/moq-dev/moq) needs to take
all its cryptography from rind, on every target MoQ releases, and publishes it.

## Required

- [rind covers MoQ](/quest/m1/moq/README.md) - the primitives, CPU check, armv7 backend, and `rind-*` adapters MoQ needs, verified and released
- [Ed25519 refuses small-order public keys](/quest/m1/ed25519-small-order.md) - an enrolled attacker key can't verify every message
- [Every public entry point runs inside the entry guard](/quest/m1/entry-guard.md) - HMAC, HKDF, PBKDF2, digest, and constant-time compare get DIT and the CPU check
- [The x86_64 prefetch helper is sound for any stride](/quest/m1/prefetch-bounds.md) - no out-of-allocation pointer from a safe function
- [CI actions are pinned and Pullfrog is constrained](/quest/m1/ci-pin-actions.md) - a moved tag can't change what CI runs
