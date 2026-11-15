# [S] rind-dart's iOS simulator job never hangs

## Goal

`build.yml`'s `dart-ios` job finishes, passing or failing, well inside its
30 minute limit on every run. Today it sometimes builds, then sits silent
until GitHub cancels it.

## Plan

- Found 2026-11-15 on
  [kixel-ai/rind#606](https://github.com/kixel-ai/rind/pull/606): its run
  [43684431110](https://github.com/kixel-ai/rind/actions/runs/43684431110)
  finished the Xcode build in 382 s, then printed nothing for 15 minutes
  until the cancel. `main`'s `build` runs 42733808737 (2026-11-10),
  43124199406 (2026-11-12), and 43645517003 (2026-11-14) ended the same
  job at about 30.5 minutes, while passing runs take about 4.
- First find where it waits: after `Xcode build done.`, `flutter test`
  installs the app and attaches to it on the simulator `xcrun simctl boot`
  started. Run it with `--verbose`, and on a hang dump
  `xcrun simctl spawn "$udid" log show --last 5m` and the simulator's
  process list, so a cancelled run shows whether the install, the launch, or
  the attach stalled.
- Suspects: the simulator still finishing first-boot work after
  `bootstatus` returns, and `flutter test` waiting on a VM service URL the
  app never prints. Fix the cause, such as waiting for the device to settle
  or pinning a runtime that boots clean; a longer timeout or a retry is not a
  fix.
