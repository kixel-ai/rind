# [S] The fuzz corpus replays under SDE without timing out

## Goal

`fuzz.yml`'s `replay-x86_64-sde` job passes for every target: no input that replays natively inside libFuzzer's per-input `-timeout` times out only because Intel SDE emulates it.

## Plan

Found by [kixel-ai/rind#924](https://github.com/kixel-ai/rind/pull/924)'s dispatched [`fuzz` run](https://github.com/kixel-ai/rind/actions/runs/44767988374): `Replay keys under SDE` failed on an SLH-DSA-SHA2-128s private key (`fuzz-crash-keys-x86_64-sde`), which `keys` signs with. It took 44 s under `sde -dmr`, past the replay's `-timeout=30`. Natively, with AddressSanitizer and coverage, it takes about 1 s on both that PR's head and its base, so the SDE slowdown on SLH-DSA signing, not that PR, runs it out. main's last scheduled run, [43525080590](https://github.com/kixel-ai/rind/actions/runs/43525080590), cancelled that replay before it finished.

- Recommended: give the SDE replay its own per-input timeout sized to SDE's slowdown, such as `-timeout=300` in `replay-x86_64-sde`'s step, and check that `keys`'s replay still ends inside the job's `timeout-minutes: 60`. The other replays keep `-timeout=30`, which still catches a real hang natively.
- Rejected: skipping SLH-DSA signing under SDE. Its SHA-2 paths are among those SDE's models select, which the job exists to check.
- Validate with one dispatched `fuzz` run, or the next weekly one, whose `Replay keys under SDE` passes.
