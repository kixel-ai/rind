# [S] dart-ios finishes instead of hitting its 30-minute timeout

## Goal

`build.yml`'s `dart-ios` job passes or fails on its own, never cancelled at
its `timeout-minutes: 30`, so a PR touching rind-dart gets a verdict on iOS.

## Plan

Found by [kixel-ai/rind#609](https://github.com/kixel-ai/rind/pull/609) on
2026-11-15: on `main`, 3 of the last 6 `build.yml` runs cancelled `dart-ios`
at 30 minutes (runs 43645517003, 43124199406, 42733808737), and #609's runs
did the same. In #609's run (job 132748197630) the Xcode build finished in
about 6 minutes, then `Run tests` printed nothing for 15 minutes until the
timeout, and the cleanup killed an orphaned `simctl`. Passing runs take 4 to 16 minutes.

- Reproduce on a macOS host as the job does: boot an iPhone simulator, then
  run `flutter test integration_test -d "$udid"` in `rind-dart/integration`.
  Find where it hangs: simulator boot, the app's launch, or a test that never
  returns.
- Fix the hang at its root cause. A longer timeout or a retry hides it.

## Hosts

- macos - the job runs on the iOS simulator
