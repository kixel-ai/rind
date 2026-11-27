# [S] The Mac mini idles near zero CPU

## Goal

With no job or agent running, the Mac mini's host keeps under 1.5 of its 15 CPUs busy (`admin/bench-report`'s busy limit there), so its benchmark runs have a chance at a quiet window and the merge queue's aarch64 jobs and agent sessions get back the CPU it wastes.

## Plan

Found by [the Mac mini's first report run](/quest/m2/bench/mac-mini.md) ([kixel-ai/rind#1114](https://github.com/kixel-ai/rind/pull/1114)), whose 7 busy checks over 45 minutes on 2026-11-27 found 3.9 to 8.6 CPUs busy, never under 1.5. Its floor was about 4 CPUs, from two sources:

- The idle macOS runner VM (`rind-queue-macos`, started by `admin/mac-mini-runners`) costs the host about 1.7 CPUs. Inside the guest, `audiomxd` has run at 70 to 80% of a CPU since the guest booted, 1 day 15 hours earlier, and `configd` at about 40%. The VM runs `tart run --no-graphics` without `--no-audio`, so first try `--no-audio` (or `--suspendable`, which also drops the entropy device) on one VM, read the guest's `top` idle, and keep whichever flag brings `audiomxd` to zero. The Linux VM idles near zero and needs nothing.
- Spotlight on the host (`mds_stores`) runs at up to 1.7 CPUs, indexing the 471 GB of agent worktrees under `~/worktrees` that builds rewrite all day. See the `Waiting` item.

Then measure the host's idle floor with `admin/bench-report`'s `busy_cpus()` while nothing runs, and record it here or in the PR.

## Waiting

- Maintainer (PC): stop Spotlight indexing the agent worktrees on the Mac mini. Turning indexing off needs `sudo mdutil -i off` or System Settings > Spotlight > Search Privacy, and an agent has neither the password nor the GUI. Add `~/worktrees` and `~/work` to Search Privacy, or run `sudo mdutil -i off /System/Volumes/Data` if nothing on the machine needs Spotlight search. Check with `ps -Ao pcpu,comm -r | grep mds_stores` during a build: it should stay near zero.
