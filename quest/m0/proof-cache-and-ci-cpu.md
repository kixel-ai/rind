# [M] Share Lean/Aeneas proof cache over Tailscale and cut rind-ci CPU

## Goal

Cut formal-verification CPU (~29 CPU-h/day across `fedora`, `desktop`, and `mini` for Lean/Aeneas/HOL Light) by serving a shared content-addressed Lean `.olean` / Aeneas `.llbc` proof cache from `fedora` over Tailscale, and cut `nixos` `rind-ci` CPU (~163 CPU-h/day) by scoping and deduplicating redundant cross-target and Intel SDE test work.

Non-goals: dropping any proof obligation, weakening constant-time checks, or reducing ISA test coverage on `main`.

## Plan

Decided 2026-11-26 (maintainer, `/quest-plan` after 24h multi-host CPU audit):
- ✅ Place in `m0`, since formal verification and `rind-ci` are directly starving the shared agent hosts (`rind/quest/README.md`: "m0 holds ... work that starves the agent hosts").
- ✅ Serve the shared Lean/Aeneas proof artifact cache from `fedora` over Tailscale, mirroring `mbx-cache` and `nix-cache` (rejected: storing the proof cache in Backblaze B2 for GitHub-hosted runners).

Baseline (2026-11-26, 24h `below` telemetry):
- **`nixos` `container@rind-ci`:** **163.0 CPU-h in 24h** (63% of the entire 32-core `nixos` host), plus 43.4 CPU-h in `quest-land-fixer@`. Inside `rind-ci`, Intel SDE runs (`x86-cpu` / `crosschecks_pq` / `wycheproof`) and repeated `rind` + third-party crate compiles (`679 CPU-min` for `rind` alone) dominated.
- **Proofs across agent hosts:** `lean`, `aeneas`, and `ocaml-hol` burned ~11.5 CPU-h on `fedora`, ~10.1 CPU-h on `desktop`, and multiple concurrent cores on `mini` (~29 CPU-h/day total), rebuilding identical `.olean` and `.llbc` files in every fresh worktree.

Approach:
1. **Shared Lean/Aeneas proof cache on `fedora`:**
   - Extend `admin/prove` (building on its existing Lake artifact cache workaround documented in `UPSTREAM.md`) to read/write compiled `.olean` and Aeneas `.llbc` artifacts keyed by input hashes against a Tailscale cache endpoint on `fedora` (coordinating the server unit in `kixel-ai/dotfiles` if needed, or using Lake's HTTP cache / `mbx`-style content-addressed store).
   - Measure before/after `admin/prove lean` wall and CPU time in a fresh worktree on `fedora`, `desktop`, and `mini`.
2. **Audit and trim `nixos` `rind-ci` CPU:**
   - Profile a representative day of `nixos-rind-ci` jobs (merge-queue runs vs scheduled runs) to attribute the 163 CPU-h/day across `check:rs`, `check:cross`, `check:msrv`, `check:vartime`, and SDE/queue jobs.
   - Coalesce redundant `nix develop` invocations (`check:msrv` currently runs up to 4 separate `nix develop .#msrv` calls), verify `rind`'s `nixos` runner shares warm `mbx` caches cleanly, and scope or deduplicate any overlapping SDE/cross compilations without losing coverage on `main`.
   - Report before/after per-job CPU-seconds on `nixos-rind-ci`.
