# [M] A failing nightly coverage gate names the PRs that lost coverage

## Goal

When main's nightly `coverage` gate fails, it names the merged PRs whose changes lost the coverage, files a quest listing them under `## Caused by`, and comments on each PR. Nobody has to bisect a red nightly by hand, and pull requests and the merge queue pay nothing for it.

## Plan

Decided 2026-11-28 (maintainer, /quest-run, on [kixel-ai/rind#1168](https://github.com/kixel-ai/rind/pull/1168)): attribute lost coverage after the merge, in the nightly (rejected: advisory per-push coverage in `pr-check.yml`; nightly-only triage by hand). #1168 bisected the 2026-11-26 failure by hand, and found seven PRs behind it.

- Add `admin/coverage-gate blame`. Given the failing run's tier files and the last green nightly's commit, it maps each region, branch side, or copy over the baseline to the commits since that run:
  - a region or branch by `git blame` on its source span, limited to commits since the last green run;
  - a copy by the commit that added its instantiating caller, such as `git log -S` on the type in the copy's name, since the copy's own file often never changed (`rind-aws-lc-rs/src/buffer.rs` in #1168);
  - an unrun function by `git blame` on its first line;
  - a stale `admin/coverage.allow` entry by the commit, since the last green run, that first made the function run.

  Each commit maps to its PR through the squash commit's `(#N)` subject. A gap that maps to no commit since the last green run is drift, such as a runner's CPU: name it as such, never guess a PR.
- Recommended: run it in `coverage.yml`'s `gate` job, only when the check fails on a scheduled run on main. The last green commit comes from the Actions API (the newest successful scheduled `coverage` run on main).
- Recommended: file the quest as a PR adding `quest/m0/coverage-<date>.md`, from a job with `contents: write` and `pull-requests: write` on the scheduled run only. No pull request runs this job, so the repository's rule that PR workflows stay read-only holds. Comment once on each named PR, linking the quest PR, with the gaps that mapped to it.
- Test `blame` on #1168's case: the tier artifacts of [run 46092106690](https://github.com/kixel-ai/rind/actions/runs/46092106690), if they are still kept, otherwise a fixture cut from them. It should name #1053, #1047, #1102, #1054, #1139, #1142, and #1032.

## Related

- [Landing a PR costs one short build](/quest/m0/ci-speed/merge-gate-batching.md) - its rule that a post-merge failure files a quest; this is that path for coverage
