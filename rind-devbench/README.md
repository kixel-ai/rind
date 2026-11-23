# rind-devbench — RindBench "All" for iPad/iPhone and Android

A standalone crate (own `[workspace]`), not a member of rind's workspace.

rind-bench's own bench files (`../rind-bench/benches/*.rs`) compiled unchanged
as modules of one library, with `criterion` replaced by a tiny shim
(`criterion-shim/`) that either lists each row's criterion ID or times it. So
the app times **every library × every operation bench-report has**, under the
same IDs (`ed25519-verify/aws-lc-rs`, `aes128-gcm/rind/16KB`, …), and gains any
row rind-bench adds with no app change. The op list (`src/ops.rs`) is
generated from `admin/bench-report` by `tools/gen-ops.py` (`--check` reports drift; not wired into CI yet).

Data-driven: the app asks the core for its catalog (rows → op, section,
library), shows libraries and sections as chips, and passes the picks back
as JSON. Report operations are on by default; rind-bench's other rows
(SLH-DSA, PBKDF2, AES-KW/KWP, AES-CBC/CTR, JWT, RSA 3072–8192 loads, extra
sizes, …) are its "More: <file>" groups, which share one "+ N more groups"
chip, off by default.

One screen, no scrolling, on both platforms: a header (device, rind commit,
where results go), the picker and run controls, and a run panel with a
progress bar, "rind fastest on X of Y" and the operations where another
library is faster, worst first, as many as fit. Wide screens put the picker
and the run panel side by side. On an Android phone too short for every chip,
the picker's chips scroll inside its card, so none is out of reach; the rest
of the screen stays put. Every row's full timings still go to the
collector and to the device's files.

## Output
JSON lines (`start`, `row` per row per round with all samples, `error`,
`round`, `done`/`stopped`, `report`) to an optional TCP collector (plain
`ncat -l -k`, see `tools/listen-devbench.sh`) and to `<app docs>/<run_id>.jsonl`.
The `report` line / `<run_id>.json` is a bench-report host result (schema 1:
host, commit, cpu, os, libraries, results[{operation, library, id, ns, ns_low,
ns_high, throughput}]) plus `device` (model, chip, OS, P/E cores, CPU
features) and `timing`. `ns` = median of per-round medians; `ns_low/high` =
min/max per-round median (not criterion's CI). `tools/import-device.py
CAPTURE --out DIR` splits a collector capture into one JSON per run.

## Build
- iOS (Mac, Xcode, rustup 1.98.1 + aarch64-apple-ios): `ios/build-ipa.sh PORT [HOST]`
  (e.g. 9101 for one iPad, 9102 for another; HOST is the collector's LAN address, left out = results stay on the iPad)
  → `ios/out/RindBenchAll-v15.0-<port>.ipa`, **unsigned**.
  Bundle id `io.github.steelhead99x.rindbench.all` (installs next to v13, not over it).
  OpenSSL is vendored (built from source) by default; `CARGO_FEATURES= ios/build-ipa.sh` leaves it out.
- Android (Linux, SDK build-tools 35 + platform 35 + NDK, JDK 17+, rustup aarch64-linux-android):
  `JAVA_HOME=… CARGO_FEATURES="--features __bench_openssl" [COLLECTOR_HOST=<LAN address>] android/build-apk.sh` →
  `android/out/RindBench-android.apk` (no Gradle; debug-key signed). arm64-v8a only.
- Host smoke: `cargo run --release --example devbench-cli -- catalog|run '<json>'`.

## Run
- iPad: sign + install with your own Apple developer account (e.g. plumesign), start `tools/listen-devbench.sh`
  on the collector computer, open "RindBench All", agree, Start.
- Android: `adb install -r RindBench-android.apk`;
  the collector fills itself in (127.0.0.1:9103 via `adb reverse`, else the LAN address given to build-apk.sh as `COLLECTOR_HOST`); headless:
  `adb shell am start -n io.github.steelhead99x.rindbench/.MainActivity --es preset quick --es libraries rind,ring --es sections AEADs --ez autostart true`;
  results also in `/sdcard/Android/data/io.github.steelhead99x.rindbench/files/`.
- iPad/iPhone headless (the same choices as Android's extras, as launch arguments):
  `xcrun devicectl device process launch --console --device UDID io.github.steelhead99x.rindbench.all -preset quick -libraries rind,ring -sections AEADs -autostart YES [-host H -port P]`.
  `-host`/`-port` override the collector baked in at build time.

## Device runners
Both apps support an unattended run with no one looking at the screen:
- `autostart` waits 3 s after the list of tests loads, so a runner can capture the picker before the run starts.
- At each screen state (`ready`, `run`, `done`), the app logs one line:
  `RINDBENCH_LAYOUT {"phase":"ready","w":390,"h":844,"wide":false,"folded":false,"fits":true,"clipped":[]}`.
  On Android it goes to logcat with tag `RindBench`. On iOS it goes to stderr (seen with `devicectl … --console`) and the device log.
  `w` and `h` are in points (iOS) or dp (Android).
- `fits` is false when the run controls are cut off or off screen, or when the run panel can't show its status or score. `"picker"` in `clipped` means some chips are cut off, which a short screen allows.
- The run itself ends with a `done` or `stopped` line at the collector.

