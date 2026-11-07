# [S] rind for Dart is tested on Android and iOS

## Goal

The `rind` Dart package's tests run on an Android emulator (including a 32-bit armv7 image) and the iOS simulator in CI, through a Flutter integration-test app, so mobile pointer handling and the build hook's mobile paths are executed, not only compiled.

## Plan

Planned with the maintainer on 2026-11-07, a follow-up of [moq-dev/rind#462](https://github.com/moq-dev/rind/pull/462): its nightly job cross-builds and checks every architecture but runs the tests only on desktop hosts, so armv7's 32-bit pointers are never exercised.

- Reuse the iOS-simulator and Android jobs rind's own CI already runs ([moq-dev/rind#432](https://github.com/moq-dev/rind/pull/432)) where they fit.
