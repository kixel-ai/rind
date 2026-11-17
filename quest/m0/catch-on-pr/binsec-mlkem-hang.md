# [S] BINSEC's ML-KEM checks finish every run

## Goal

`admin/ct-binsec`'s ML-KEM checks finish within seconds on every backend and every run, as they do in almost every run today. The cause of their occasional hang is found and fixed, not hidden by a longer timeout or a retry. ML-KEM's own code changes only as far as the check needs.

## Plan

Planned with the maintainer on 2026-11-17, from the `/quest-run` of 2026-11-16 and 2026-11-17: ✅ find and fix the cause (rejected: not planning it, since rerunning a two-in-seventy advisory failure is cheap; raising the timeout, which hides the hang).

- What failed: ctgrind's `binsec (portable)` job, `admin/ct-binsec --timeout 480`, twice in about 70 runs, both on pull requests whose diff doesn't reach the portable ML-KEM code:
  - `ct_binsec_mlkem1024`, [run 43884518954](https://github.com/kixel-ai/rind/actions/runs/43884518954) on kixel-ai/rind#812.
  - `ct_binsec_mlkem512`, [run 43941913029](https://github.com/kixel-ai/rind/actions/runs/43941913029) on kixel-ai/rind#811.
- Each timed out at 480 s with "0 visited path" and "timeout has left (at least) 1 pending paths", and every check it reached passed. The same tests pass in 6 to 8 s in other runs, so the cause is something that varies by run, not slowness. Candidates: a path whose length depends on input the harness doesn't pin, such as SampleNTT's rejection loop or the harness's random seed, and nondeterminism in BINSEC's solver.
- Reproduce it first, for example by looping the one test locally or in a dispatched run, then fix the cause in the harness or the test's setup.

## Related

- [Failures show up on the PR that causes them](/quest/m0/catch-on-pr/README.md) - this flake turns PR checks red for changes that didn't cause it.
