# [XS] The build nightly passes on main

## Goal

Every row of `build.yml`'s nightly passes on `main`. After [moq-dev/rind#513](https://github.com/moq-dev/rind/pull/513) fixed the armv7 zeroing and Dart cross-target failures, three causes remain ([run 42918059953](https://github.com/moq-dev/rind/actions/runs/42918059953)).

## Plan

Planned with the maintainer on 2026-11-10 after triaging main's nightlies: ✅ m0, since m0 owns a failing `main`; ✅ one quest per workflow (rejected: one quest for every nightly).

- **Dart on the Intel Mac.** `dart (macos-15-intel)` fails `hook_test.dart`'s "builds from source for the host" with `TimeoutException after 0:00:30`: it runs a cargo build inside the default test timeout. Recommended: give that test an explicit, generous timeout; building first is the alternative. It was hidden behind the cross-target failure #513 fixed.
- **Android emulation.** Both `android` rows fail with `Package 'qemu-user-static' has no installation candidate`, since `ubuntu-latest` moved to 26.04. Install `qemu-user-binfmt` instead, at `.github/workflows/build.yml` and the same line in `python.yml`.
- **Heap-scratch leak test on qemu targets.** The `qemu` rows (powerpc64, powerpc64le, riscv64, s390x, loongarch64) fail `heap_scratch::detects_a_leak_in_key_generation` (`test did not panic as expected`, `rind/tests/heap_scratch.rs:67`); the optimizer likely removes the unused `drop(vec![1u8; 32])`. Recommended: `drop(black_box(vec![1u8; 32]))`, then confirm the cause on one qemu row. Caused by [moq-dev/rind#581](https://github.com/moq-dev/rind/pull/581).
