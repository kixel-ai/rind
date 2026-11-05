# [M] rind builds and passes its tests on iOS and Android

## Goal

rind builds and passes its tests in CI on the mobile targets the Dart package
ships: iOS on aarch64, and Android on aarch64, armv7, and x86_64.

## Plan

- CI tests Linux glibc and musl, macOS, and Windows on x86_64 and aarch64,
  and armv7 Linux, and builds armv7 Android. `cargo build -p rind --lib`
  succeeds for `aarch64-apple-ios`, `aarch64-apple-ios-sim`,
  `aarch64-linux-android`, and `x86_64-linux-android` (checked on
  2026-11-05), but none has run its tests.
- Run the tests natively where GitHub has a runner (macOS for iOS's
  simulator) and under emulation otherwise; a target only built is noted as
  such.
- The tests' aws-lc-rs dev-dependency builds C for the target, so Android
  needs the NDK's compilers, as iOS needs Xcode's.
- Fix what fails at the source; a target that cannot work fails to compile,
  as `AGENTS.md` requires, and is named in the README.
