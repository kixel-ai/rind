# [S] prove's spec-tests finishes inside its job's limit

## Goal

`prove.yml`'s `spec-tests` job finishes inside its 90-minute limit on every scheduled run, with room for the suite to grow, so a red nightly `prove` names a failing spec test, not a time limit.

## Plan

Found by [kixel-ai/rind#1028](https://github.com/kixel-ai/rind/pull/1028): `spec-tests` hit the limit on the scheduled runs of 2026-11-22 ([run 45081759538](https://github.com/kixel-ai/rind/actions/runs/45081759538)) and 2026-11-25 ([run 45528903742](https://github.com/kixel-ai/rind/actions/runs/45528903742)), and its passing runs that week took 77 to 79 minutes.

- Profile where the job's time goes (the Lean build, Mathlib's cache, or the tests themselves) and cut the cause, such as a cache it misses or a test that can run in parallel; raise the limit only with a measurement saying the work itself needs it.
