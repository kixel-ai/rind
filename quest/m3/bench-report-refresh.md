# [S] Benchmark report refresh, end of m2

## Goal

`BENCHMARKS.md`, and with it the README's headline, is regenerated on all four hosts at the end of m2, and every new gap is triaged as the Plan sets out.

## Plan

Decided with the maintainer on 2026-11-03: rerun the report at the end of each milestone.

- Recurring. This run lives in m3 and requires m2, so it is ready once m2's work is done. The PR that finishes it deletes this file and creates the next run at `/quest/m4/bench-report-refresh.md` (creating m4 if needed). That run's `Required` links `/quest/m3/README.md`, m4's `Required` links it, and this Plan carries forward.
- Run `admin/bench-report`, review the diff for regressions, and triage gaps above about 10% into speed quests or recorded reasons in `benchmarks/gaps.toml`, which `render` requires.
- Settled with the maintainer when the report was planned (2026-11-03), so don't reopen them: the hosts `nixos`, `desktop`, `nixos2`, and `kixtop`, each on its native path; the libraries rind, aws-lc-rs, ring, RustCrypto with dalek, graviola, libcrux, and OpenSSL; a ✓ only where a published proof covers the whole computation that library runs on that host, padding included. A gap becomes a [speed](/quest/m2/speed/README.md) quest when the operation is common or the gap is large, and otherwise gets a recorded reason; verified code within about 10% stays.
- Recheck the README's opening against the new results: its claims, such as which operations trail aws-lc-rs and ring, must still hold.
- The first report's `nixos2` gaps in Ed25519 verify (1.13 against RustCrypto) and ML-KEM-768 encapsulation (1.23 against graviola) come from its older run. Recheck them with a fresh `nixos2` run, and plan a speed quest for either that still holds.
- `kixtop` (Apple M4) joins the report before this run, in [its own m1 quest](/quest/m1/bench-apple-m4.md) (maintainer, 2026-11-07); this run measures it like the other hosts.

## Required

- [m2: later work](/quest/m2/README.md) - the milestone this run closes
