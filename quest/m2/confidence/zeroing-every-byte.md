# [S] The zeroing test checks every byte of every secret type on every backend

## Goal

Under `wipe`, `rind/tests/zeroing.rs` checks every byte of every type that owns a secret, on every backend and CPU tier and on Windows. A secret-owning type with no zeroing test fails `just ci`.

## Plan

Planned from the 2026-11-09 tooling audit. The test has four holes:

- It skips the first 16 bytes of every value: the loop at `rind/tests/zeroing.rs:262` starts at `HEAP_FREELIST_ZONE.0`, which is 16 (`:289`). A value of 16 bytes or fewer passes with nothing checked. The comment at `:285` blames the allocator's freelist, but the read at `:256` comes before `dealloc` at `:259`, so the allocator has written nothing yet. Drop the skip, or show which bytes need it.
- Its 12 tests (`:53-221`) are a hand-kept list. `admin/testing` checks every other column of [TESTING.md](/TESTING.md) but knows nothing of `wipe`.
- `#![cfg(...)]` at `:44` compiles it to nothing off Linux and macOS, so `build.yml`'s two Windows rows pass an empty binary.
- It runs only on the host's tier in `just ci` (`sh/dispatch.sh:203`), in a debug build on each native runner (`build.yml:55`), and on two armv7 tiers (`sh/armv7.sh:44-45`). No denied tier, SDE model, or forced portable run sets `wipe`.

The tiers matter because each picks key and table types with their own `Drop`: the AES-NI, vpaes, and bitsliced AES keys, and the GHASH tables beside them (`.cargo/mutants.toml:203-216` lists them). [moq-dev/rind#458](https://github.com/moq-dev/rind/pull/458) left the ARM AES key enum's inactive bytes unwiped, which only armv7's run could see; [moq-dev/rind#513](https://github.com/moq-dev/rind/pull/513) fixes it.

- Completeness: give TESTING.md's primitives table the zeroing test of each secret-owning export, and have `admin/testing` fail on one without, as it does for the other columns. That runs in `just ci`.
- Tiers: run the test in `build.yml`'s denied tiers, each `x86-cpu.yml` SDE model, and `just portable`, all nightly. The binary is small, so each adds seconds.
- Windows: the test reads the value before it is freed, so nothing in it depends on the allocator; build it there unless a run shows otherwise.
- `rind-aws-lc-rs/tests/zeroing.rs` scans freed blocks instead and has no skip; leave it.

## Related

- [Heap scratch from a private key is wiped before it is freed](/quest/m2/confidence/wipe-heap-scratch.md) - the heap blocks this test's `size_of` bytes never reach
