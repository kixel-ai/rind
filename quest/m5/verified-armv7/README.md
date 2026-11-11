# armv7 is proven

## Goal

Every operation rind exports earns the ✓ on 32-bit Arm, with and without NEON and the crypto extension, so `benchmarks/verified.toml` and the benchmark report carry armv7 cells.

## Plan

Most armv7 paths run assembly (aws-lc's, OpenSSL's, and BoringSSL's) for which no instruction model exists in any proof tool rind uses, so the model comes first. The rest is Rust that Aeneas translates as it does for the other targets.
