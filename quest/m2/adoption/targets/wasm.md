# [S] rind on wasm32

## Goal

rind builds for wasm32-wasip2 on the [portable backend](/ARCHITECTURE.md), and CI runs its vector tests there under wasmtime. `just ci` fails when a change stops the wasm build. [PLATFORMS.md](/PLATFORMS.md) lists wasm32 and says its constant-time behavior is unchecked under a JIT, and no document still says wasm does not build.

## Plan

Decided with the maintainer on 2026-11-09, after the tooling audit found wasm neither refused nor tested: `rind/build.rs:24-26` gives every architecture but three the portable backend, while this epic called wasm a non-goal and the docs said it does not build.

- wasm: ✅ support and test it (rejected: build only, as [moq-dev/rind#543](https://github.com/moq-dev/rind/pull/543) proposes; refuse it with a compile error).
- Long-term: ✅ pure Rust now, with WebCrypto an open question to revisit if a browser consumer appears (rejected: record WebCrypto as a permanent non-goal; go back to build-only).
- Why not WebCrypto now: its API is async and rind's is sync. It exists only in JavaScript hosts, so it would be a second backend chosen at run time. It has no incremental hashing, QUIC header protection, or MD5. Each call costs more than a small input's work.
- Speed is not this quest's: wasm rides the portable speed quests in m3's cold-speed epic (wide arithmetic for bignums, SIMD128).

#543 is an outside contributor's PR, not this quest's. It restores the build, which MD5's `asm!` optimizer barrier broke (`rind/src/low/generic/md5.rs:22`), and adds nightly build jobs for wasm32-wasip2 and wasm32-unknown-unknown, with and without `wipe`. Build on it once it lands, or carry the same fix.

Guidance:

- Run the tests on wasm32-wasip2 under wasmtime, in a nightly `build.yml` job with a `just` recipe, as armv7 and the portable job have. The vector files reach the tests through a preopened directory.
- aws-lc-rs, the tests' oracle, is C and does not build for wasm, so the differential tests cannot run there. The vectors do: Wycheproof, CAVP, CCTV, and the RFCs'. `just portable` runs the same Rust differentially on x86_64. Say so in [TESTING.md](/TESTING.md)'s tier table.
- Add wasm32-wasip2 to the gate's cross lint (`sh/dispatch.sh:228`), so a break like MD5's fails `just ci` rather than a nightly.
- Constant time: ctgrind, the trace comparisons, and `admin/ct-vartime` check native code. A wasm engine compiles rind again, and may turn a select into a branch. PLATFORMS.md says that plainly.
- wasm32-unknown-unknown stays build-only: its tests need a JavaScript host, which waits for a browser consumer, as WebCrypto does. Its entropy comes from getrandom's `wasm_js` feature, which the final binary must enable.
- rind-rustls: build it for wasm32-wasip2 if rustls builds there, and record the result either way.
- Remove or correct every statement that wasm does not build, `MIGRATE.md:56` among them.
- `quest/m0/adapters/ring.md` keeps ring's `wasm32_unknown_unknown_js` feature a no-op because rind does not build for wasm32. Once it does, that feature must select getrandom's JavaScript backend as ring's does; its PR, [moq-dev/rind#516](https://github.com/moq-dev/rind/pull/516), must revisit it.

## Related

- [rind on 32-bit x86](/quest/m2/adoption/targets/x86.md) - the other 32-bit portable target, tested under qemu
- [64-bit portable targets use 64-bit limbs](/quest/m3/cold-speed/portable-limbs.md) - picks wasm32's limb width
- [Miri runs the portable backend's tests](/quest/m2/confidence/miri-portable.md) - the other run of this backend that cannot link aws-lc-rs
- [rind-ring is ring 0.17's API](/quest/m0/adapters/ring.md) - its `wasm32_unknown_unknown_js` no-op relies on wasm not building
