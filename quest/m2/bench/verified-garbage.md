# [S] The tier heatmap and the build cost compare rind with verified-garbage

## Goal

BENCHMARKS.md's CPU-tier heatmap counts pyca/verified-garbage (VG) as a rival like aws-lc-rs and ring, and `admin/build-cost` times a minimal VG binary beside the other libraries', so every comparison the report makes includes VG once its data is refreshed. The weekly gate stays on aws-lc-rs and ring.

## Plan

The maintainer asked on 2026-11-17 to "add verified garbage to the benchmark comparisons if not already". [kixel-ai/rind#741](https://github.com/kixel-ai/rind/pull/741) already times VG in rind-bench and gives the host tables a VG column; what lacks it is below.

- Heatmap: VG joins the rivals each tier cell ranks rind against, and `benchmarks/gaps.toml` and the weekly `gate` stay on `BASELINES`. A cell VG wins becomes a switch quest through [the VG bench triage](/quest/m2/verified-garbage/bench.md), not an alert.
- The heatmap leaves VG out of the portable column: that column times rind's portable backend against aws-lc's C without assembly, and VG runs its baseline assembly there, which rind's portable backend can never take.
- Rank `chacha20/`, which UNRANKED left out for want of a baseline, on the heatmap's ChaCha20 row now that VG gives it a rival. The gate's "no baseline" note skips a benchmark VG ranks, since the gate never counts it.
- Build cost: a `verified-garbage` fixture covering AES-128-GCM, SHA-256, ECDSA P-256, and X25519, pinned to rind-bench's VG rev. VG has no P-256 key generation, so the fixture imports a random scalar, as rind-bench does; it has no rustls provider, so no rustls build. The build-cost text says both.
- Real numbers come from [the report refresh](/quest/m2/bench/report-refresh.md), which re-measures the hosts and the weekly tiers; this quest runs no host benchmark. Its Plan lists VG among the report's libraries (maintainer, 2026-11-17).

## Related

- [rind-bench times pyca/verified-garbage on every host and tier](/quest/m2/verified-garbage/bench.md) - triages the cells VG wins into switch quests
