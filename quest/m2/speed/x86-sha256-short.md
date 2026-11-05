# [S] x86_64 SHA-256 of short messages as fast as RustCrypto

## Goal

SHA-256 of a 64 B message on x86_64 with the SHA extensions is level with RustCrypto and graviola, without slowing longer messages.

## Plan

Planned on 2026-11-04 from the first [BENCHMARKS.md](/BENCHMARKS.md) (the maintainer delegated the gap triage).

- [moq-dev/rind#352](https://github.com/moq-dev/rind/pull/352) finishes SHA-256 on the SHA extensions in registers, padding and digest encoding included. rind's 32 B hash is now faster than graviola's, and its HMAC-SHA256 and HKDF-SHA256 are ahead of RustCrypto's. 64 B through `digest::Context` is still behind: 76 ns on `nixos` (Zen 3) against RustCrypto's 59 and graviola's 67.
- What remains is the context, not the hash: `digest::digest` of 64 B is faster than RustCrypto's. `Context::finish(self)` moves the 224-byte context through libc's `memcpy`, whose 32-byte loads cannot forward from the narrower stores `new` and `update` just made. Each hash then waits for the previous one's SHA chain to retire. rustc keeps that copy while `Context` has drop glue (its wipe) or its address reaches the hashes' code through `Ops`' function pointers.
- Closing it changes the digest API's design, which is the maintainer's call: [moq-dev/rind#352](https://github.com/moq-dev/rind/pull/352) lists the options, with the cycles each would save.
- Keep the glue translatable by Aeneas and `admin/prove` passing on x86_64 and aarch64.
- Measure on the GitHub runners and the report's hosts, and remove this gap's entry from `benchmarks/gaps.toml` when the report's refresh shows it closed.
