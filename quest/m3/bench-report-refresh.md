# [S] Benchmark report refresh, end of m2

## Goal

`BENCHMARKS.md`, and with it the README's heatmap, is regenerated on all four hosts at the end of m2, and every new gap is triaged as the Plan sets out.

## Plan

Decided with the maintainer on 2026-11-03: rerun the report at the end of each milestone.

- Recurring. This run lives in m3 and requires m2, so it is ready once m2's work is done. The PR that finishes it deletes this file and creates the next run at `/quest/m4/bench-report-refresh.md` (creating m4 if needed). That run's `Required` links `/quest/m3/README.md`, m4's `Required` links it, and this Plan carries forward.
- Run `admin/bench-report`, review the diff for regressions, and triage gaps above about 10% into speed quests or recorded reasons in `benchmarks/gaps.toml`, which `render` requires.
- Settled with the maintainer when the report was planned (2026-11-03), so don't reopen them: the hosts `nixos`, `desktop`, `nixos2`, and `kixtop`, each on its native path; the libraries rind, aws-lc-rs, ring, RustCrypto with dalek, graviola, libcrux, and OpenSSL; a ✓ only where a published proof covers the whole computation that library runs on that host, padding included. A gap needs a quest that closes it when the operation is common or the gap is large, and otherwise gets a recorded reason; verified code within about 10% stays.
- The bar, settled for the m2 speed epic (maintainer, 2026-11-01): the fastest permissively licensed source usable from Rust (aws-lc-rs, ring, RustCrypto, libcrux, graviola, BoringSSL, s2n-bignum, ...), on every x86_64, aarch64, and armv7 tier the nightly bench forces, at symmetric sizes 32 B, 1200 B, 1350 B, and 16 KB (plus 64 B and 8 KB for hashes). Copyleft sources don't count.
- Triage, settled when the m2 speed epic closed (maintainer, 2026-11-09): this PR records each gap that needs a quest as a suggested follow-up in its body, which `/quest-merge` plans into the milestone the maintainer picks; the `gaps.toml` entry names that quest once it exists, and gives a reason until then.
- Recheck the README's opening against the new results: its claims, such as which operations trail aws-lc-rs and ring, must still hold.
- The first report's `nixos2` gaps in Ed25519 verify (1.13 against RustCrypto) and ML-KEM-768 encapsulation (1.23 against graviola) come from its older run. Recheck them with a fresh `nixos2` run, and plan a speed quest for either that still holds.
- Every report so far timed rind's Ed25519 verify with a key parse, about 4 µs, that RustCrypto's and aws-lc-rs's rows skip. [moq-dev/rind#464](https://github.com/moq-dev/rind/pull/464) parses it once, so this run's Ed25519 verify rows for rind, graviola, OpenSSL, aws-lc-rs, and RustCrypto are the first that time the same work: drop any `gaps.toml` entry they close. ring's and libcrux's APIs take raw key bytes, so their rows still include the parse: rind beating them does not show its verify alone is faster, and a `gaps.toml` reason that rests on those rows says so.
- `kixtop` (Apple M4) joined the report in [moq-dev/rind#435](https://github.com/moq-dev/rind/pull/435) (maintainer, 2026-11-07); this run measures it like the other hosts.

## Required

- [m2: later work](/quest/m2/README.md) - the milestone this run closes
