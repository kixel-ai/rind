# [S] ML-DSA signing without AVX2 is re-measured against verified-garbage's

## Goal

rind's ML-DSA signing on x86_64 without AVX2 runs whichever of rind's own code and pyca/verified-garbage's `vg_mldsa{44,65,87}_sign` holds at every parameter set on the weekly tier and an idle host, by the 2026-11-18 rule, measured after rind restored FIPS 204's rejection-check order.

## Plan

Found by the 2026-11-28 [upstream-updates](/quest/m2/upstream-updates.md) run. The maintainer closed [kixel-ai/rind#849](https://github.com/kixel-ai/rind/pull/849) on 2026-11-19 ([quest/m2/verified-garbage/README.md](/quest/m2/verified-garbage/README.md)) because, after [kixel-ai/rind#863](https://github.com/kixel-ai/rind/pull/863) checked the likeliest rejection first, VG no longer held at every size, and asked for new numbers before the switch is proposed again. That run's PR reverts #863's order, as mldsa-native's `61d3fc1e` did (revealing the low-bits check for an attempt whose z is rejected is outside the zero-knowledge argument), which made rind's signing 6 to 7% slower on an Arrow Lake (AVX2) host. On #849's numbers VG was already 0.96 to 0.97 of rind's time at ML-DSA-44 on Zen 3.

- Re-run #849's measurement on `main` with AVX2 denied for both: the `mldsa` bench's sign groups on the weekly tier and on an idle, core-pinned host, three runs each.
- If VG holds at every set, reopen #849's switch as a new PR with the numbers and its proof quest; otherwise record them in the VG epic's README and delete this quest.
