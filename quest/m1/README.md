# m1: MoQ coverage

## Goal

rind carries everything [MoQ](https://github.com/moq-dev/moq) needs to take
all its cryptography from rind, on every target MoQ releases, and publishes it.

## Required

- [x86_64 redc_8n reduces a result equal to the modulus](/quest/m1/redc-8n-equal.md) - a latent off-by-one in the Montgomery reduction's final subtraction
- [rind covers MoQ](/quest/m1/moq/README.md) - the primitives, CPU check, armv7 backend, and `rind-*` adapters MoQ needs, verified and released
