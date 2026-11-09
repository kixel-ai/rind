# [S] Mutation testing of DIT

## Goal

The code that detects and sets data-independent timing (DIT) runs under `admin/mutants` on cores that have it: `rind::cpu::Dit`, aarch64's `enter_cpu_state` and `leave_cpu_state`, and `dit::maybe_enable`, which compile only for Apple's platforms. Each mutant there that no test catches is killed by a test or recorded with its reason, and the `exclude_re` entries in `.cargo/mutants.toml` that point here are gone.

## Plan

- rind sets DIT only on Apple's platforms. GitHub's macOS arm64 runners are Apple M-series, which have it. `admin/mutants` knows only Linux target triples, so teach it Darwin's.
- Mutate only the code above there. Combine the results with the Linux runs through `admin/mutants --survivors`.
