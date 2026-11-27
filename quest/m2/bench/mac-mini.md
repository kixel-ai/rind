# [S] The Mac mini joins the benchmark report

## Goal

The maintainer's Mac mini is a host in BENCHMARKS.md, measured by `admin/bench-report collect` like the others, so the report has a desktop Apple-silicon host beside `kixtop`'s M4 laptop.

## Plan

Planned with the maintainer on 2026-11-10. The Mac mini (Apple M5 Pro, 5 Super and 10 Performance cores, `ssh mini`, admin account `kixelated`, Nix installed, `sudo` needs a password) also runs the merge queue's two aarch64 runners as tart VMs (`admin/mac-mini-runners`, landed in [kixel-ai/rind#1022](https://github.com/kixel-ai/rind/pull/1022)), benchmarks, Apple-silicon nightlies, and agents.

- ✅ Accept the noise: the machine also runs the merge queue and agents, so it benchmarks under plain `quest gate` like every other host, and its section says so (rejected: a nightly window that pauses the runner and agents; a benchmark-only machine).
- Add it as `kixtop` was added in [kixel-ai/rind#435](https://github.com/kixel-ai/rind/pull/435), and include its first run in the next report refresh.

[kixel-ai/rind#1114](https://github.com/kixel-ai/rind/pull/1114) added `mini` to `admin/bench-report`'s hosts, and found on 2026-11-27 that accepting the noise gives unusable data:

- Under the standard busy check, 7 tries over 45 minutes found 3.9 to 8.6 of its 15 CPUs busy, never under the limit of 1.5. Its idle floor is about 4 CPUs, which [its own quest](/quest/m2/bench/mini-idle-floor.md) brings down.
- One run that skipped the busy check, at `9ed42b03`, measured beside 8.4 other busy CPUs and the merge queue's builds. Against `kixtop`'s M4 on the 101 rows both time, rind's median time was 1.9× `kixtop`'s, on a newer and faster chip, and 33 rows showed rind over 10% behind the fastest library where `kixtop` shows 5, among them SHA-256 at 64 B at 4.8×, RSA-2048 signing at 4.2×, and Ed25519 at 2.2 to 2.4×. Rows run one after another, so a load swing between two libraries' rows reads as a gap. `admin/build-cost` refused the host as busy (12.2 of 15 CPUs).
- [desktop's quiet-run quest](/quest/m2/bench/desktop-quiet-run.md) meets the same problem on Linux. Its PR, [kixel-ai/rind#1103](https://github.com/kixel-ai/rind/pull/1103), holds the host by confining every other cgroup slice to the last core or two, which needs systemd and passwordless sudo, so macOS cannot reuse it.

Once a quiet window exists, run `admin/bench-report collect --host mini` and `render --from`, triage its gaps into speed quests or reasons in `benchmarks/gaps.toml`, and compare its rows with `kixtop`'s.

## Waiting

- Maintainer: The Mac mini cannot get a quiet benchmark run: its runner VMs and agents keep 4 to 9 of its 15 CPUs busy, and a run beside them came out 1.9× slower than the M4 laptop with 33 false gaps where the laptop shows 5. How should it get a quiet window?
  - Demote other work during the run (Recommended) - `admin/bench-report` marks every other process of the `kixelated` account, the runner VMs and agent sessions included, as background with `taskpolicy -b` for the run's 45 minutes and restores them after, the macOS counterpart of desktop's cgroup hold; nothing stops and no sudo is needed, but it is unmeasured whether background QoS frees the Super cores enough, so the first run checks that
  - Pause the runner VMs and agent sessions for the run - reverses the 2026-11-10 rejection of a window that pauses them; certain to be quiet, but holds the merge queue's aarch64 jobs and every agent for 45 minutes
  - Keep retrying under the busy check - free, but the floor alone is above the limit until the idle-floor quest lands, and desktop found no window in 21 hours
  - Drop the Mac mini from the report - `kixtop` stays the only Apple-silicon host

## Related

- [The Mac mini idles near zero CPU](/quest/m2/bench/mini-idle-floor.md) - lowers the floor any option starts from
