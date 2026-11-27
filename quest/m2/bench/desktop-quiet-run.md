# [S] The report has a dependable way to benchmark hosts that CI runners and agent sessions share

## Goal

`admin/bench-report collect` gets usable data from `nixos`, `desktop`, and `fedora`, which also run CI runners and agent sessions, without waiting for a quiet window that does not come and without starving the other work, and the bench epic's README records how.

## Plan

Decided 2026-11-24 (maintainer): ✅ refresh with the quiet hosts and re-measure nixos, desktop, and fedora in a follow-up quest (rejected: hold 0.4 until every host runs quiet; pause the runners and sessions now).

Decided 2026-11-26 (maintainer, during [kixel-ai/rind#1103](https://github.com/kixel-ai/rind/pull/1103)): ✅ shared hosts run at about twice their CPU count because their work is bursty, so a benchmark cannot expect a quiet shared host (rejected: holding the host for the run).

- The 0.4 refresh ([kixel-ai/rind#991](https://github.com/kixel-ai/rind/pull/991)) tried `desktop` 91 times over 21 hours without a window under `admin/bench-report`'s busy limit (10% of the CPUs).
- [kixel-ai/rind#1103](https://github.com/kixel-ai/rind/pull/1103) tried a hold: for the run, `collect` confined every other top-level cgroup slice to the host's last whole core (`AllowedCPUs`) and measured in a slice of its own. It gave quiet runs at once (`desktop` 2.01 other CPUs busy against 2.4, `nixos` 0.44 against 3.2, `fedora` 2.03 against 3.2), and #1103 keeps `desktop`'s and `nixos`'s. It was rejected: mbx sized its pool from the confined cpuset at one CPU, so each permit cost all of its memory budget and every agent's gated work stalled for the run.
- The hold also found two measurement traps for any design that confines other work: a benchmark thread the scheduler places on the confined core runs about a third slower (`fedora`'s P-384 ECDH measured 1.30× its last run, every other row level), and the every-logical-CPU rows wait on whichever thread shares that core, which slowed every library's by 25 to 30%. Pinning the benchmarks to the CPUs left free fixes both.
- On systemd 262 (`nixos`), `systemctl set-property --runtime <slice> AllowedCPUs=` did not restore the slice's cpuset; setting the whole range explicitly did.

## Waiting

- Maintainer: how should the report get data from hosts that CI runners and agent sessions keep at about twice their CPU count?
  - Reserve two cores (Recommended) - collect pins the benchmarks to the host's last two whole cores and keeps other work off only those, so it keeps every other core for the run and mbx sizes its pool from them; the every-logical-CPU rows leave those hosts. First trial it on one host against its last quiet run, since a loaded neighbour still shares the L3 cache and the power budget, and keep it only if the ratios agree within the 10% bar.
  - Dedicated hosts only - the report keeps `kixtop`, the OVH VPSes, and `mac-mini` once [its quest](/quest/m2/bench/mac-mini.md) lands, and drops `nixos`, `desktop`, and `fedora`, so the only AVX-512 and Arrow Lake tables go, leaving the weekly CPU tier table to cover AVX-512.
  - Load-annotated rows - collect runs under `quest gate` as before, drops the busy refusal, and the report marks each shared host's rows with the load they ran under, as the proposal in [kixel-ai/rind#938](https://github.com/kixel-ai/rind/pull/938) measures; its 2026-11-19 A/B runs drifted 0.87 to 1.22 at such loads, against the 10% bar.

## Related

- [Mac mini](/quest/m2/bench/mac-mini.md) - a dedicated host
