# [M] An Android bench app that times rind on a phone, and the decisions to ship it

## Goal

A contributor with an Android phone or tablet installs one APK, taps through a consent switch, and gets rind timed against the other libraries on that device, so phones reach the benchmark results the same way desktops do. The app never sends anything without that consent, and a normal build never lets another app start a run or pick where results go.

## Plan

- Base: the fork's `rind-devbench` Android app, `rind-bench` v14.5, at [steelhead99x/rind `rind-bench-v14.5`](https://github.com/steelhead99x/rind/tree/rind-bench-v14.5) (`8adad323`). It is a Java UI (no Gradle, no AndroidX) over `rind-devbench`, a `cdylib` built with the NDK that runs the criterion benches of rind, aws-lc-rs, ring, RustCrypto + dalek, graviola, libcrux, OpenSSL and pyca/verified-garbage in process. `android/build-apk.sh` builds and signs the APK with only the SDK's build tools (aapt2, d8, zipalign, apksigner).
- Upstream has no `rind-devbench`. The fork's branch sits on fork history 172 commits off `main`, so it cannot be a PR as it stands. The implementation PR adds `rind-devbench/` (the crate, `android/`, and the collector tools) on top of `main`, with only the fork changes it needs, after the Waiting items are answered.
- Consent: Start stays disabled until "I agree to share timings" is on, and "What's shared" lists what is sent (timings plus model, chip, system version and CPU features; never name, account, serial number or location). Results always save on the device too.
- Intent extras: the launcher activity is exported. A normal build ignores `autostart`, `host` and `port`; only a `DEVICE_RUNNER=1` build honours them, for unattended device runners. `libraries`, `sections` and `preset` only preselect the picker (`974cc1d6`, a port of [steelhead99x/rind#289](https://github.com/steelhead99x/rind/pull/289)).
- Layout: on every screen the consent switch and Start stay visible, labelled and at least 44dp tall, in portrait and landscape, with the full test list (8 libraries, 16 groups plus the 24 off-by-default groups). In landscape the collector card moves over the status column so a phone's run controls get the whole left column (`30571fe2`), and the results teaser drops lines so View results keeps its full height (`8adad323`).
- Checked so far, on Android 15 emulators only (Pixel 7, 411x914dp, and Pixel Tablet, 800x1280dp), portrait and landscape, cold start in landscape, and rotation: the consent switch and Start were visible and labelled in every state, Start was disabled with consent off and enabled with it on, `autostart` was ignored by a normal build, and a Quick run (rind, AEADs, 18 tests) ended Done with its results shown.
- Still to do before the implementation PR: one Full run on a real Pixel phone and a real tablet, each with its model and result in the PR body, and the same consent and layout checks on that hardware.

## Waiting

Each item opens with who acts. Options are lettered, the recommendation first.

- Maintainer: where the app lives. (a) `rind-devbench/` in this repository, built by hand and never published to a store. (b) A separate repository under kixel-ai. (c) It stays in the fork, and only its results come upstream. Recommended: (a), so the benches it runs move with rind.
- Maintainer: where results go. Same question as [the bench app quest](https://github.com/kixel-ai/rind/pull/946): (a) a PR to `rind-results` with the saved JSON. (b) The built-in collector over `adb reverse` or the LAN, then a PR. Recommended: (a), with (b) as the device-runner path.
- Maintainer: dependencies. `rind-devbench` pulls every compared library, OpenSSL through `openssl-sys` and aws-lc-rs's C build for Android. Confirm that a crate outside the workspace with `publish = false` may carry them, and what `deny` should say about it.
- Maintainer: signing and release. (a) Contributors build and sign their own debug APK. (b) A maintainer signs one release APK per rind release. Recommended: (a) until (b) has an owner.
- Maintainer: review (draft, `REVIEW_REQUIRED`).
- Not an owner call: the real-device runs above have not happened; every check so far was on emulators.
