# [M] A binary links only the algorithms it uses

## Goal

A binary that uses a few of rind's algorithms links only those, and its size is close to ring's. Today a minimal binary using AES-GCM, SHA-256, ECDSA P-256, and X25519 is 3.9 MB stripped, against 0.74 MB for ring and 0.91 MB for graviola, and a rustls client on rind-rustls is 5.4 MB against 1.9 MB on ring.

## Plan

Planned with the maintainer on 2026-11-03 from [moq-dev/rind#308](https://github.com/moq-dev/rind/pull/308)'s build-cost numbers, measured on `nixos`.

- `nm` shows P-384, P-521, and Ed25519 code in a binary that never uses them. Find what keeps them alive, such as an algorithm enum or dispatch table matched at runtime, a `dyn` vtable, or the rustls provider listing every scheme, and restructure so unused algorithms drop out, without breaking the API's misuse-proof shape.
- Some single functions inline to hundreds of KB, such as P-521's `from_x962_uncompressed` at about 750 KB. Stop the giant inlining (an `#[inline(never)]` boundary at the right layer, or a smaller table construction), and measure speed before and after, since inlining may be what makes some paths fast.
- The rustls provider can't drop schemes it offers. Report its size with and without the unused ones, and note what a smaller provider would need.
- `admin/build-cost` measures the result. The [benchmark report](/quest/m1/benchmarks/README.md) shows binary size, so this lands before it is published.
