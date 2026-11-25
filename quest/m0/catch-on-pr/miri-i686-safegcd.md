# [XS] Miri's i686 row passes the 32-bit safegcd inverse test

## Goal

`miri.yml`'s `miri (i686-unknown-linux-gnu)` job passes, and `low::generic::limb32::safegcd::tests::inverse` still runs under Miri on i686 over inputs small enough to fit 32-bit address space. rind's code doesn't change.

## Plan

Found by the release PR's `miri` run of 2026-11-25 ([run 45588809497](https://github.com/kixel-ai/rind/actions/runs/45588809497)): the proptest at `rind/src/low/generic/safegcd.rs:328` failed after 5,567 s, out of 32-bit address space, since [kixel-ai/rind#974](https://github.com/kixel-ai/rind/pull/974) added the i686 row. It is the only failure in that job.

- Decided 2026-11-25 (maintainer, /quest-plan): ✅ make the row pass, m0 (rejected: dropping the i686 Miri row).
- Recommended: under `cfg(miri)` on 32-bit targets, cap the proptest's limb-count range and case count, so Miri still checks the 32-bit code path for undefined behavior. Skip the test there, with the reason in a comment, only if no bounded run fits. Its native runs keep the full range.
- Also check the job's total time: a single test running 93 minutes is near the job's limit on its own.
