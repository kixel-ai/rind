# [M] BENCHMARKS.md is generated

## Goal

`admin/bench-report` turns the collected results into `BENCHMARKS.md` and its SVGs: the overview heatmap, each host's numeric heatmap, the build-cost tables, and the CPU-tier heatmap from the latest nightly, with a ✓ on every verified cell.

## Plan

See the [epic](/quest/m1/benchmarks/README.md) for the settled decisions and the layout.

- GitHub doesn't render colored table cells, so the overview is an SVG with a `<title>` per square for its number. The per-host heatmaps are SVGs too, each followed by a plain table of the numbers inside `<details>`.
- Keep the ✓ data in one checked-in table (library, operation, platform, proof source), so a ✓ is reviewed like code.
- The CPU-tier heatmap reads the nightly bench run's results. Once it exists, the README Algorithms table drops its ratios and the speed epic points to the report as its scoreboard.
- Each section says when and on which commit it was measured.
- `admin/bench-report` runs `admin/build-cost` on each host after the speed benchmarks, not alongside them, since both skew each other's times, and renders its JSON. The openssl build links the system's OpenSSL, so its binary size excludes the library; openssl-vendored is the static figure.

## Required

- [Benchmarks run on every host for every library](/quest/m1/benchmarks/hosts.md) - the results this renders
