# [S] rind's tests run on wasm32

## Goal

CI runs rind's vector tests on wasm32-wasip2 under wasmtime, on the portable backend, so the code only wasm compiles is executed by a test. [PLATFORMS.md](/PLATFORMS.md) says constant-time behavior is unchecked under a JIT.

## Plan

Decided with the maintainer on 2026-11-09, in the quest audit, reconciling two answers given the same day: ✅ both, the compile gate now and tests after it (rejected: compile-only, as the compile gate's quest first recorded, with runtime tests a non-goal). The compile gate in `just check`'s `cross` module keeps a wasm build from breaking; this one runs what it builds.

- Why test: code behind `cfg(target_family = "wasm")`, such as MD5's optimizer barrier (`rind/src/low/generic/md5.rs`, from [moq-dev/rind#543](https://github.com/moq-dev/rind/pull/543)), is executed by no test on any other target. The rest of the backend is the Rust that x86 and the qemu targets already run.
- Long-term (maintainer, 2026-11-09): ✅ pure Rust now, with WebCrypto an open question to revisit if a browser consumer appears (rejected: record WebCrypto as a permanent non-goal; go back to build-only). Why not WebCrypto now: its API is async and rind's is sync. It exists only in JavaScript hosts, so it would be a second backend chosen at run time. It has no incremental hashing, QUIC header protection, or MD5. Each call costs more than a small input's work.
- Speed is not this quest's: wasm rides [the portable speed quests](/quest/m3/cold-speed/README.md) (wide arithmetic for bignums, SIMD128).

Guidance:

- Run the tests on wasm32-wasip2 under wasmtime, in a nightly `build.yml` job with a `just` recipe, as armv7 and the qemu targets have. The vector files reach the tests through a preopened directory.
- aws-lc-rs, the tests' oracle, is C and does not build for wasm, so the differential tests cannot run there. The Miri run already leaves it out with a `cfg(not(miri))` dev-dependency table in `rind/Cargo.toml` and the same cfg on each test that calls it; extend that cfg to wasm. The vectors do: Wycheproof, CAVP, CCTV, and the RFCs'. `just portable` runs the same Rust differentially on x86_64. Say so in [TESTING.md](/TESTING.md)'s tier table.
- Constant time: ctgrind, the trace comparisons, and `admin/ct-vartime` check native code. A wasm engine compiles rind again, and may turn a select into a branch. PLATFORMS.md says that plainly.
- wasm32-unknown-unknown stays compile-only: its tests need a JavaScript host, which waits for a browser consumer, as WebCrypto does.
- `quest/m0/adapters/ring.md` keeps ring's `wasm32_unknown_unknown_js` feature a no-op because rind did not build for wasm32. Now that it does, that feature must select getrandom's JavaScript backend as ring's does; its PR, [moq-dev/rind#516](https://github.com/moq-dev/rind/pull/516), must revisit it.

## Related

- [64-bit portable targets use 64-bit limbs](/quest/m3/cold-speed/portable-limbs.md) - picks wasm32's limb width
