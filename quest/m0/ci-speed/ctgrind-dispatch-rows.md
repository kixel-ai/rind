# [S] A dispatched ctgrind runs only the rows its change reaches

## Goal

`ctgrind.yml`'s `workflow_dispatch` takes an input naming the jobs to run, and agents name only the jobs their change reaches. A dispatch without it, a release check's or a person's, still runs the whole scheduled matrix.

## Plan

- ✅ Agents dispatch only the ctgrind rows their change reaches (rejected: keep full dispatches). The maintainer, 2026-11-19.
- Why: 21 dispatched or scheduled ctgrind runs from 2026-11-16 to 2026-11-19 took 425 hosted hours, 231 of them on the armv7 rows, mostly the debug unit rows running to the 6-hour cancel. [kixel-ai/rind#843](https://github.com/kixel-ai/rind/pull/843) has since made those pass in about 1h48m, so re-measure a dispatch's cost on `main` before giving before-and-after figures. The transcripts show agents dispatching the whole workflow to check one tier, such as one `x86_64-sde` test or the aarch64 rows, and to bisect.
- Agents learn to dispatch from CONTRIBUTING.md's "on demand with `gh workflow run <name> --ref <branch>`" and TESTING.md's "Scheduled workflows". AGENTS.md already holds the same rule for `bench` ("A dispatched `bench` run names the bench targets the change touches"). Recommended: widen that AGENTS.md line to cover ctgrind instead of adding a new one, since it is where agents already learned the `bench` form, and point the two docs at the input.
- Recommended input: job IDs separated by spaces, such as `-f jobs='armv7 x86_64-sde'`, empty meaning all; each job's `if:` checks it. Keep `x86_64-sde`'s test list selectable too, since one test's traces take up to an hour.
- `just ci` fails a scheduled workflow that a dispatch would not run whole, and `just release-check` dispatches every scheduled workflow; the empty default keeps both whole. Check that the input does not trip that check.
- The armv7 rows still have no `timeout-minutes`, so a hang holds a runner for GitHub's 6 hours. Give them one near twice their time after #843.
