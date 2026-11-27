# [M] Share Lean/Aeneas proof cache over Tailscale and cut rind-ci CPU

## Goal

Cut Lean and Aeneas proof rebuild CPU across `fedora`, `desktop`, and `mini` by serving a shared content-addressed Lean `.olean` / Aeneas `.llbc` proof cache from `fedora` over Tailscale, and cut `nixos` `rind-ci` CPU (~163 CPU-h/day) by attributing and trimming redundant self-hosted queue build work.

Non-goals: dropping any proof obligation, weakening constant-time checks, or reducing ISA test coverage on `main`.

## Plan

Decided 2026-11-26 (maintainer, `/quest-plan` after 24h multi-host CPU audit):
- ✅ Place in `m0`, since formal verification and `rind-ci` are directly starving the shared agent hosts (`rind/quest/README.md`: "m0 holds ... work that starves the agent hosts").
- ✅ Serve the shared Lean/Aeneas proof artifact cache from `fedora` over Tailscale, mirroring `mbx-cache` and `nix-cache` (rejected: storing the proof cache in Backblaze B2 for GitHub-hosted runners).

Baseline (2026-11-26, 24h `below` telemetry):
- **`nixos` `container@rind-ci`:** **163.0 CPU-h in 24h** (63% of the entire 32-core `nixos` host), plus 43.4 CPU-h in `quest-land-fixer@`. On `origin/main`, `.github/workflows/queue-build.yml` runs `Queue build / Build` (`CHECK_QUEUE=1 CHECK_FAIL_FAST=1`, host Rust checks and quick lints) on `[self-hosted, rind-queue]`, while `check.yml` and `x86-cpu.yml` run on GitHub-hosted runners.
- **Proofs across agent hosts:** Combined `lean`, `aeneas`, and `ocaml-hol` CPU was ~29 CPU-h/day (~11.5 CPU-h on `fedora`, ~10.1 CPU-h on `desktop`, plus concurrent cores on `mini`). HOL Light (`ocaml-hol`) runs separately from Lean/Aeneas, and Lake already reuses unchanged modules across worktrees for the same user on a single host.

Approach:
1. **Shared Lean/Aeneas proof cache on `fedora`:**
   - First measure Lean and Aeneas CPU time separately from HOL Light, and benchmark cross-host reuse in a fresh worktree with the existing local Lake cache warm.
   - Extend `admin/prove` (building on its existing Lake artifact cache workaround documented in `UPSTREAM.md`) to read/write compiled `.olean` and Aeneas `.llbc` artifacts keyed by input hashes against a Tailscale cache endpoint on `fedora` (coordinating the server unit in `kixel-ai/dotfiles` if needed, or using Lake's HTTP cache / `mbx`-style content-addressed store).
   - Report before/after `admin/prove lean` wall and CPU time in a fresh worktree on `fedora`, `desktop`, and `mini` (cross-host reuse).
2. **Attribute and trim `nixos` `rind-ci` CPU:**
   - Attribute the measured 163 CPU-h/day on `nixos` `container@rind-ci` to specific `rind-ci` GitHub Actions job IDs and commit revisions, separating historical/pre-refactor runs from workloads that still execute on `nixos` (`Queue build / Build` with `CHECK_QUEUE=1`).
   - Profile the workloads still running on `nixos` (including uploaded `cargo-timings` artifacts and `mbx` cache hit/miss/unconsulted breakdown inside `container@rind-ci`), then cut redundant compilation or test work on `nixos` without touching GitHub-hosted workflows or losing coverage on `main`.
   - Report before/after per-job CPU-seconds on `nixos-rind-ci`.
