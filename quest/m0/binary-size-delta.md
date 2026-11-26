# [M] A PR's check reports its binary-size change instead of matching a checked-in record

## Goal

No checked-in file records rind's exact size in a binary, so PRs that change rind's code stop conflicting with each other over it. The PR check measures what rind and rind-rustls add to each `admin/build-cost-fixtures` program on the PR's head and on its base, and shows both, with the delta, in its job summary. It passes whatever the delta is. main's absolute sizes go into BENCHMARKS.md's weekly report, beside the stripped binary sizes `admin/build-cost` already gives there. No size budget or threshold is in scope.

## Plan

Planned with the maintainer on 2026-11-26, after the 2026-11-26 quest-run: `admin/binary-size.txt`, which [kixel-ai/rind#1008](https://github.com/kixel-ai/rind/pull/1008) added, holds one exact byte count per fixture, and nearly every change to rind's code moves it. So parallel PRs conflict on the same line, and the merge queue ejects them: [kixel-ai/rind#1049](https://github.com/kixel-ai/rind/pull/1049) needed five main merges, and [#1032](https://github.com/kixel-ai/rind/pull/1032), [#1035](https://github.com/kixel-ai/rind/pull/1035), [#1054](https://github.com/kixel-ai/rind/pull/1054), and [#1073](https://github.com/kixel-ai/rind/pull/1073) hit it. Two PRs that each record their own size also leave main's record matching neither. [kixel-ai/rind#1038](https://github.com/kixel-ai/rind/pull/1038) and [kixel-ai/rind#1041](https://github.com/kixel-ai/rind/pull/1041) removed the same race from AUDIT.md's and the ledger's generated counts.

- ✅ No checked-in file records exact sizes; the PR check reports the PR's change against its base (rejected: drop the quest and keep re-recording on each merge).
- ✅ Report only: the job summary shows the change, a reviewer weighs it, and the check passes on any delta (rejected: fail on any growth, which blocks most perf and feature PRs; a growth threshold, which would be an arbitrary acceptance criterion).
- ✅ main's absolute sizes, rind's bytes per fixture, go into BENCHMARKS.md through the weekly bench report, beside `admin/build-cost`'s stripped size (rejected: only in the nightly job summary, which keeps no history; dropping them, which loses rind's own byte count).
- Recommended: measure the base in the same job, building it into the same `target/binary-size` so only rind and rind-rustls rebuild. Keep the fixtures' lockfiles (`admin/binary-size-*.lock`), since they pin what else the programs link, and both builds use them. Keep `admin/binary-size`'s rustc wrapper, which makes the sizes independent of where the checkout is. Say in the PR how much time the base build adds to the PR check.
- Delete `admin/binary-size.txt` and its `--write`/`fix:fixtures` path, and update what cites the record: `sh/dispatch.sh`'s `fixtures` module, `CONTRIBUTING.md`, `pr-check.yml`'s header, and [vg-smaller-ifma-routines](/quest/m2/speed/vg-smaller-ifma-routines.md), which reads a gain from the record's diff.

## Related

- [vg-smaller-ifma-routines](/quest/m2/speed/vg-smaller-ifma-routines.md) - measures its gain through this record today
