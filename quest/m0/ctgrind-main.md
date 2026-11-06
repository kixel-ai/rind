# [M] ctgrind passes on main again

## Goal

The scheduled `ctgrind.yml` run on main passes on every job, so constant-time regressions surface the night they land, and the PBKDF2 secret-branch report it raised is either fixed or shown to be a false positive.

## Plan

Found during [moq-dev/rind#393](https://github.com/moq-dev/rind/pull/393); decided with the maintainer on 2026-11-06 to plan it in m0, since a broken constant-time gate hides new regressions. The nightly has failed since 2026-11-04 ([run 42126975491](https://github.com/moq-dev/rind/actions/runs/42126975491)): the arm64 `build` job, `aarch64-portable`, `armv7 (adapters)`, and four `x86_64-portable` jobs (no-adx, no-aes, no-avx, no-ssse3).

- arm64: Valgrind can't decode the instruction that reads DIT (`mrs` of the DIT register), so every arm64 test that enters rind dies. #393 checked its code with DIT turned off in a throwaway job. Teach the ctgrind build to run without that read, or patch Valgrind, without changing what rind ships: DIT stays toggled once per call.
- Behind it, the arm64 release job reports PBKDF2's block loop branching on a secret. Triage it: a real secret-dependent branch is a constant-time bug to fix, and a false positive gets the narrowest suppression in `admin/ctgrind.supp` with its reason.
- Find why the x86_64-portable and armv7 adapter jobs fail, and fix each at its cause.
- Check whether an open PR already fixes any of these before starting.
