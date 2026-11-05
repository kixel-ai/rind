# [S] Benchmark report refresh, end of m2

## Goal

`BENCHMARKS.md` is regenerated on all four hosts at the end of m2, and every new gap is triaged as the [benchmarks epic](/quest/m1/benchmarks/README.md) set out.

## Plan

Decided with the maintainer on 2026-11-03: rerun the report at the end of each milestone.

- Recurring. This run lives in m3 and requires m2, so it is ready once m2's work is done. The PR that finishes it deletes this file and creates the next run at `/quest/m4/bench-report-refresh.md` (creating m4 if needed). That run's `Required` links `/quest/m3/README.md`, m4's `Required` links it, and this Plan carries forward.
- Run `admin/bench-report`, review the diff for regressions, and triage gaps above about 10% into speed quests or recorded reasons in `benchmarks/gaps.toml`, which `render` requires.
- The first report's `nixos2` gaps in Ed25519 verify (1.13 against RustCrypto) and ML-KEM-768 encapsulation (1.23 against graviola) come from its older run. Recheck them with a fresh `nixos2` run, and plan a speed quest for either that still holds.
- The first report (maintainer, 2026-11-04) measured `nixos`, `desktop`, and `nixos2`, the last at an older commit. Add `kixtop` once it is reachable: accept its ssh host key first, and fix what the first run of its macOS path (rustup, Homebrew OpenSSL, `top`, and `admin/build-cost` there) finds. Then recheck `benchmarks/verified.toml` against its recorded CPU features: a ✓ that lands on no square, or a dispatch the table didn't foresee, is a bug in the table.

## Required

- [m2: later work](/quest/m2/README.md) - the milestone this run closes
- [Benchmark report on real hardware](/quest/m1/benchmarks/README.md) - the script and report this reruns
