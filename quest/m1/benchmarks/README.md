# Benchmark report on real hardware

## Goal

A `BENCHMARKS.md` linked from the README shows how rind compares with the usual crypto libraries on real machines, in speed, cold build time, binary size, and build dependencies, with a ✓ on every formally verified implementation, so a reader can judge rind without running anything. Every gap where a library beats rind gets a decision.

## Plan

Planned with the maintainer on 2026-11-03. Settled; don't ask again (✅ is the chosen option):

- Hosts: `nixos` (Ryzen 9 5900XT, Zen 3), `desktop` (Core Ultra 7 270K Plus, Arrow Lake), `nixos2` (i7-8700, Coffee Lake), and `kixtop` (Apple Silicon Mac, aarch64 macOS; accept its ssh host key once). Each runs its native path.
- First publication (maintainer, 2026-11-04): publish with the hosts that are quiet and reachable, plus the nightly CPU tiers, rather than wait for all four. It shipped with `nixos`, `desktop`, and `nixos2`, whose fresh run stayed blocked by other work so its result is from an earlier commit; `kixtop`'s ssh timed out. The [recurring refresh](/quest/m3/bench-report-refresh.md) adds `kixtop`; the report names the hosts not measured yet.
- Libraries: rind, aws-lc-rs, ring, RustCrypto with dalek, graviola, libcrux, and OpenSSL ✅, each wherever it offers the operation.
- Format: BENCHMARKS.md with generated, committed SVGs ✅ / a GitHub Pages site.
- Layout: an overview heatmap with operations as rows and libraries as columns, where each cell holds four small squares, one per host, colored by time relative to the fastest on that host. Below it, each host's numeric heatmap in a collapsed `<details>` ✅ / per-host tables only / a rind-centric summary / the overview only. Mockups were reviewed in this planning session.
- ✓ marks a cell only when a published formal proof covers the whole computation that library runs for that operation on that host, padding included ✅ / two marks for full and partial coverage / a verified component such as the block function earns it. The report links the proof source for each ✓.
- Operations are sorted by importance, most common first: the TLS 1.3 handshake, then AEADs, key agreement, signatures, hashes and KDFs, then RSA, ML-KEM, and P-384/P-521.
- Build cost: a cold `cargo build --release` of a minimal crate per library and of a rustls client per provider, the stripped binary size, and the build dependencies each needs (C compiler, cmake, nasm, perl) ✅, all four selected.
- CPU tiers: a further heatmap, generated from the latest nightly bench on GitHub's runners (no AVX2, no AES-NI, SSE2, aarch64 without crypto, armv7), replaces the README Algorithms table's ratios as the [speed epic](/quest/m2/speed/README.md)'s scoreboard ✅ / keep the tier ratios in README.
- Refresh: `admin/bench-report` runs everything over ssh and regenerates the report, and a recurring quest reruns it at the end of each milestone ✅ / script only.
- Gaps (maintainer: "you decide"): every operation where a library beats rind by more than about 10% on a host's native path gets a speed-epic quest when the operation is common or the gap is large, or else a recorded reason in the report. The ~10% verified-code rule applies: verified code that is close stays. Triaged on 2026-11-04 from the first report: x86_64 RSA-2048 signing, short SHA-256, and SHA-2 bulk became [speed](/quest/m2/speed/README.md) quests, and the rest have reasons. `benchmarks/gaps.toml` holds each decision, BENCHMARKS.md's Known gaps shows them, and `admin/bench-report render` refuses a gap without one, so a refresh triages its new gaps.

The epic has no work of its own left.

## Required

- [The README sells rind and links the report](/quest/m1/benchmarks/readme.md) - a short pitch and headline numbers, with the numbers' single home in the report
