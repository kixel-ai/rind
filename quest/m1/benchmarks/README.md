# Benchmark report on real hardware

## Goal

A `BENCHMARKS.md` linked from the README shows how rind compares with the usual crypto libraries on four real machines, in speed, cold build time, binary size, and build dependencies, with a ✓ on every formally verified implementation, so a reader can judge rind without running anything. Every gap where a library beats rind gets a decision.

## Plan

Planned with the maintainer on 2026-11-03. Settled; don't ask again (✅ is the chosen option):

- Hosts: `nixos` (Ryzen 9 5900XT, Zen 3), `desktop` (Core Ultra 7 270K Plus, Arrow Lake), `nixos2` (i7-8700, Coffee Lake), and `kixtop` (Apple Silicon Mac, aarch64 macOS; accept its ssh host key once). Each runs its native path.
- Libraries: rind, aws-lc-rs, ring, RustCrypto with dalek, graviola, libcrux, and OpenSSL ✅, each wherever it offers the operation.
- Format: BENCHMARKS.md with generated, committed SVGs ✅ / a GitHub Pages site.
- Layout: an overview heatmap with operations as rows and libraries as columns, where each cell holds four small squares, one per host, colored by time relative to the fastest on that host. Below it, each host's numeric heatmap in a collapsed `<details>` ✅ / per-host tables only / a rind-centric summary / the overview only. Mockups were reviewed in this planning session.
- ✓ marks a cell when the code that library runs for that operation on that host is covered by a published formal proof. The report links the proof source for each ✓.
- Operations are sorted by importance, most common first: the TLS 1.3 handshake, then AEADs, key agreement, signatures, hashes and KDFs, then RSA, ML-KEM, and P-384/P-521.
- Build cost: a cold `cargo build --release` of a minimal crate per library and of a rustls client per provider, the stripped binary size, and the build dependencies each needs (C compiler, cmake, nasm, perl) ✅, all four selected.
- CPU tiers: a further heatmap, generated from the latest nightly bench on GitHub's runners (no AVX2, no AES-NI, SSE2, aarch64 without crypto, armv7), replaces the README Algorithms table's ratios as the [speed epic](/quest/m2/speed/README.md)'s scoreboard ✅ / keep the tier ratios in README.
- Refresh: `admin/bench-report` runs everything over ssh and regenerates the report, and a recurring quest reruns it at the end of each milestone ✅ / script only.
- Gaps (maintainer: "you decide"): once the first report lands, this epic triages every operation where a library beats rind by more than about 10% on a host's native path. A gap gets a speed-epic quest when the operation is common or the gap is large, or else a recorded reason in the report. The ~10% verified-code rule applies: verified code that is close stays.

The epic's own remaining work, once its children merge: that triage.

## Required

- [BENCHMARKS.md is published](/quest/m1/benchmarks/report.md) - the heatmaps, ✓ marks, build cost, and CPU tiers, rendered from real results on all four hosts
- [The README sells rind and links the report](/quest/m1/benchmarks/readme.md) - a short pitch and headline numbers, with the numbers' single home in the report
