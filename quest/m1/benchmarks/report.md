# [S] BENCHMARKS.md is published

## Goal

`BENCHMARKS.md` and its SVGs, rendered by `admin/bench-report` from a full collection on all four hosts and the latest nightly CPU tiers, are committed. The README's Algorithms table drops its ratios, and the [speed epic](/quest/m2/speed/README.md) points to the report's CPU tiers as its scoreboard.

## Plan

See the [epic](/quest/m1/benchmarks/README.md) for the settled decisions and the layout. The renderer, the verified-code table (`benchmarks/verified.toml`), the nightly's saved results, and CI's `cargo check` of the build-cost fixtures landed in [moq-dev/rind#316](https://github.com/moq-dev/rind/pull/316). What remains needs real results:

- Wait until a nightly `bench` run on main has uploaded its `bench-*` artifacts, then run `admin/bench-report nightly`.
- Run `admin/bench-report collect` while the hosts are quiet; it runs `admin/build-cost` on each host after the benchmarks. Accept `kixtop`'s ssh host key first. Its macOS path (rustup, Homebrew OpenSSL, `top`, and `admin/build-cost` there) has never run, so fix what the first run finds.
- `admin/bench-report render --from .tmp/bench-report/<commit>`, then look at every SVG on GitHub in light and dark mode before committing `BENCHMARKS.md` and `benchmarks/`.
- Recheck `benchmarks/verified.toml` against each host's recorded CPU features: a ✓ that lands on no square, or a host whose dispatch the table didn't foresee, is a bug in the table.
