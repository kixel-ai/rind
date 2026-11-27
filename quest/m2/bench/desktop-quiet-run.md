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

Decided 2026-11-27 (maintainer, during [kixel-ai/rind#1103](https://github.com/kixel-ai/rind/pull/1103)): ✅ reserve two cores: `collect` pins the benchmarks to the host's last two whole cores and keeps other work off only those, so the other work keeps every other core and mbx sizes its pool from them, and the every-logical-CPU rows leave shared hosts; trial it on one host against that host's last quiet run, and keep it only if the ratios agree within the 10% bar (rejected: dedicated hosts only; load-annotated rows, as [kixel-ai/rind#938](https://github.com/kixel-ai/rind/pull/938) proposes).

- On a hybrid Intel CPU (`desktop`), the last two whole cores are the last two performance cores, `/sys/devices/cpu_core/cpus`, since the other hosts' tables time performance cores and Linux numbers the efficiency cores last.

## Related

- [Mac mini](/quest/m2/bench/mac-mini.md) - a dedicated host
