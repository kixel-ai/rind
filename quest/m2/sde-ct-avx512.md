# [S] SDE constant-time checks cover every AVX-512 path

## Goal

The SDE trace-comparison harness from [moq-dev/rind#263](https://github.com/moq-dev/rind/pull/263) also covers AES-GCM's and ML-KEM's AVX-512 paths, which valgrind (and so ctgrind) cannot run.

## Plan

Planned with the maintainer on 2026-11-02. Start once #263 lands with the harness; if #263 changes shape, adapt to what it ships.

- Run each path under SDE with two or more different secrets and fail on any trace difference; keep it in the nightly, not the gate.
- Prove each new case catches a planted secret-dependent branch.
