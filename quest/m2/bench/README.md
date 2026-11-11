# Speed regressions are caught the night they land

## Goal

The nightly bench fails on any gap nobody decided, on every tier and at every size people run: it ranks every benchmark it times, and it times the tiers and AEAD sizes no host or row covers today.

## Plan

Decided with the maintainer on 2026-11-09, after an audit of the whole tree: ✅ plan speed measurement and portable speed (rejected: correctness tooling only, or measurement without portable speed work). Measurement joins m2 with the other tooling; the cold tiers' speed work is [m3's](/quest/m3/cold-speed/README.md).

The audit found rind level or ahead in every ranked cell on mainline x86_64, aarch64, and armv7 with the crypto extension. What it could not vouch for is what nothing measures: the nightly prints a summary and never fails, about a third of its benchmark IDs are unranked, and no host or forced tier times aarch64 with the crypto extension but without SHA-3, which is Graviton 2, the Raspberry Pi 5, and most phones.

[The benchmark report refresh](/quest/m2/bench/report-refresh.md) keeps the report on the dedicated hosts. This epic makes the nightly catch what lands between refreshes.
