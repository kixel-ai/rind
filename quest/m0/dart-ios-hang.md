# [S] `dart-ios` finishes its simulator tests instead of hanging to its timeout

## Goal

`build.yml`'s `dart-ios` job passes or fails on rind-dart's integration tests on the iOS simulator, and never hangs until GitHub cancels it at `timeout-minutes: 30`.

## Plan

Seen 2026-11-15: of the last six `main` runs of `build.yml` that ran `dart-ios`, three were cancelled in its `Run tests` step at 30 minutes ([43645517003](https://github.com/kixel-ai/rind/actions/runs/43645517003/job/132616862848), [43124199406](https://github.com/kixel-ai/rind/actions/runs/43124199406/job/130880662504), [42733808737](https://github.com/kixel-ai/rind/actions/runs/42733808737/job/129558046237)), and so was [kixel-ai/rind#786](https://github.com/kixel-ai/rind/pull/786)'s docs-only head ([43714883035](https://github.com/kixel-ai/rind/actions/runs/43714883035/job/132814454353)). In that log the simulator booted, `Xcode build done` came at 12:55 after 304 s, and nothing more printed until the cancel at 13:11: `flutter test integration_test` hung after the build, while installing, launching, or connecting to the app.

- Reproduce on a `macos-latest` runner or a Mac with the same Xcode and Flutter, with `flutter test -v` to see which phase stalls, and fix that cause. A longer timeout or a rerun is no fix.
- The step boots the first available iPhone simulator and does not wait for its springboard beyond `simctl bootstatus`; check whether the hang follows a particular device or runtime, or a first launch on a fresh simulator.
- Give the step its own `timeout-minutes` below the job's, so a hang reports as this step and leaves room for the logs.
