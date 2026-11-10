# Every primitive is tested as thoroughly as the best libraries test theirs

## Goal

Every primitive, on every backend and CPU tier, has published test vectors, a differential fuzz target, a differential test, and a constant-time check that also catches variable-time instructions. Mutation testing shows the tests catch changes to rind's Rust. Mechanical checks guard what those cannot see: the assembly boundary, wiping, the portable backend, and the adapters' promises.

## Plan

Decided with the maintainer on 2026-11-07, in m3. Moved to m2 with the maintainer on 2026-11-09, after an audit of the whole tree: ✅ m2 (rejected: redefine m3 to hold assurance, move only the security check). This is active work, not deferred, and m3 is for waits and work deferred by priority.

Four children claimed before the move finish from [the m3 directory](/quest/m3/confidence/README.md), since a claimed quest cannot move. Delete that README once the last of them has merged.

rind already has these:
- differential fuzz targets against aws-lc-rs, run nightly;
- Wycheproof and cross-checks against aws-lc-rs;
- Intel SDE CPU models for every x86_64 dispatch path;
- ctgrind, `admin/ct-sde`, and `admin/ct-qemu` for secret-dependent branches and addresses;
- `admin/ct-vartime`, in `just ci`, for variable-time instructions, which those three can't see.

[OSS-Fuzz](/quest/m4/oss-fuzz.md) is planned in m4 and isn't repeated here.

The 2026-11-09 audit found no exploitable bug and no panic reachable from public input, and planned the eleven children from the hostile-input fuzz target down: each is a hole it confirmed in the code that no test, fuzzer, or proof sees today.

- Fix what a check finds in its own quest's PR when it's small; otherwise plan a follow-up.
- Slow suites run in their own workflows, not in `just ci`, as `AGENTS.md` asks.

## Required

- [rind passes NIST's ACVP vectors](/quest/m2/confidence/acvp.md) - every algorithm ACVP covers
- [BINSEC checks RSA's private operation, ChaCha20's AVX2 kernel, and aarch64](/quest/m2/confidence/binsec.md) - the secret paths the nightly BINSEC job leaves out
- [Adapter crates' surviving mutants](/quest/m2/confidence/mutants-adapters.md) - tests for the 103 adapter mutants no test catches
- [Surviving mutants that need crafted inputs](/quest/m2/confidence/mutants-edge-cases.md) - the AVX2 Ed25519 field arithmetic, points at infinity, and other edges random inputs miss
- [Mutation testing on AVX-512](/quest/m2/confidence/mutants-avx512.md) - the AVX-512 paths no campaign host runs, under Intel SDE
- [Mutation testing of DIT](/quest/m2/confidence/mutants-dit.md) - DIT detection and setting, on cores that have it
- [Hostile peer bytes never panic an adapter](/quest/m2/confidence/adapters-hostile-input.md) - a nightly fuzz target feeding arbitrary peer bytes to rind-rustls, rind-dimpl, and rind-str0m
- [Safe wrappers around assembly enforce their preconditions in release builds](/quest/m2/confidence/release-preconditions.md) - length, alignment, and table-size checks on safe `low` wrappers that hold in release, with RSA benches within noise
- [Guard pages catch assembly that reads or writes past a buffer](/quest/m2/confidence/guard-pages.md) - every buffer-taking kernel against a PROT_NONE page, at every length and alignment
- [An ABI harness checks every assembly routine](/quest/m2/confidence/asm-abi.md) - callee-saved registers, stack pointer, and flags after each routine
- [The zeroing test checks every byte of every secret type on every backend](/quest/m2/confidence/zeroing-every-byte.md) - no 16-byte skip, no unlisted type, every tier and Windows
- [Heap scratch from a private key is wiped before it is freed](/quest/m2/confidence/wipe-heap-scratch.md) - a test allocator that fails on key-derived bytes in a freed block
- [The portable backend is fuzzed and mutation tested](/quest/m2/confidence/portable-fuzz-mutants.md) - nightly fuzzing and a mutation campaign for the backend every new target ships on
- [Each adapter's API is diffed against its upstream's](/quest/m2/confidence/adapter-api-diff.md) - the exact-API rule machine-checked per feature set
- [A PR that would redden a nightly learns before it merges](/quest/m2/confidence/nightlies-on-prs.md) - nightlies run on PRs that touch their inputs
