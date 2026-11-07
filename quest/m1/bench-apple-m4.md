# [S] The bench report measures Apple M4 and a quiet Arrow Lake

## Goal

`BENCHMARKS.md` has a `kixtop` (Apple M4, macOS) column, collected natively, and a fresh, quiet `desktop` (Arrow Lake) run, before the launch post. Every gap either opens a speed quest or gets a recorded reason in `benchmarks/gaps.toml`.

## Plan

Decided with the maintainer on 2026-11-07: plan in m1 the optimizations only the maintainer's hardware can measure. GitHub's runners cover Zen 3/4/5, Intel server cores, Neoverse N2, and a virtual M1, but not real Apple silicon or Arrow Lake. The maintainer opened `desktop`, `nixos`, and `kixtop` to agents. This moves "add `kixtop`" out of the [end-of-m2 refresh](/quest/m3/bench-report-refresh.md), whose other settled choices (libraries, hosts, the ✓ rule, the triage rule) apply here unchanged.

- `kixtop` is the maintainer's own MacBook (Apple M4, FEAT_DIT, SHA3, SHA512), so expect background load. Hold it with `quest gate --host kixtop` as `admin/bench-report` does, prefer a quiet window, and rerun noisy rows rather than recording noise.
- First macOS collection: fix what `admin/bench-report`'s macOS path (#399) hits there (rustup, Homebrew OpenSSL, `top`, `admin/build-cost`), and accept its ssh host key first.
- Re-collect `desktop` quietly. The `rustls-bulk/aes128-gcm` and `xchacha20poly1305/1350B` gaps there are recorded as noise awaiting a recheck, so drop or triage them.
- Recheck `benchmarks/verified.toml` against `kixtop`'s CPU features: a ✓ that lands on no square, or a dispatch the table didn't foresee, is a bug in the table.
- A gap becomes a speed quest when the operation is common or the gap is large, and otherwise gets a recorded reason. Plan new quests with `/quest-plan` as follow-ups in the PR.
