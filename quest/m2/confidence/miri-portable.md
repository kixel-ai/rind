# [M] Miri runs the portable backend's tests

## Goal

A nightly job runs the portable backend's tests under Miri with `wipe` on, forced on x86_64 and again as big-endian `s390x-unknown-linux-gnu`, and fails on undefined behavior: an invalid value, a misaligned or out-of-bounds pointer, a data race, or a byte-order assumption.

## Plan

Planned from the 2026-11-09 tooling audit. rind runs no interpreter over its unsafe Rust: the flake's only `miri` is the sysroot Charon links against (`flake.nix:179`). Miri cannot run `asm!`, so the assembly backends are out; the portable backend is Rust all the way down, with one exception below.

What it would check that nothing does:

- `Zeroable` is a safe marker trait that licenses writing zeroes over any `T` through a raw pointer (`rind/src/low/generic/zeroise.rs:13-27`). A wrong `impl` leaves an invalid value for the drop glue that follows. [moq-dev/rind#513](https://github.com/moq-dev/rind/pull/513) had to give every AES key enum an explicit tag for exactly this.
- `ReuseCache` is a hand-written once-cell with an `unsafe impl Sync` (`rind/src/low/generic/reuse_cache.rs:26,54,78,87`), and its three tests are single-threaded (`:116-142`). Miri's race detector needs a test that crosses threads.
- The volatile loops behind `zero_bytes` and the constant-time compare (`rind/src/low/portable/cpu.rs:25,43`).
- The unsafe inside libcrux, fiat-crypto, and curve25519-dalek, on the paths rind calls.
- Byte order. Every big-endian target runs this backend, and until a qemu job lands nothing executes it big-endian.

Constraints:

- MD5's optimizer barrier is `asm!` on every target (`rind/src/low/generic/md5.rs:22`). Under `cfg(miri)` it needs `core::hint::black_box`, as [moq-dev/rind#543](https://github.com/moq-dev/rind/pull/543) does for wasm.
- aws-lc-rs, a dev-dependency, is C: Miri cannot call it, and its build script would need an s390x C toolchain. Keep it out of the Miri build, so the differential tests do not run here. The vectors do.
- `rind/tests/zeroing.rs` reads a dropped value on purpose, which Miri rejects. Exclude it; the drops in every other test are what `wipe` exposes here.
- Miri is slow. Pick a subset per primitive that reaches every unsafe block, and leave RSA key generation and the large vector sets to the native runs. Say in [TESTING.md](/TESTING.md) what the subset is.
- It needs a nightly toolchain and minutes to hours, so it is its own nightly workflow, watched by `alert.yml`, not part of `just ci`.

## Related

- [rind builds on every target ring or aws-lc-rs supports](/quest/m2/adoption/targets/README.md) - its s390x job (`just qemu`) runs the whole suite big-endian under qemu, compiled; this finds the undefined behavior qemu executes without complaint
