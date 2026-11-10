# m2: later work

## Goal

Work that follows the release MoQ switches to: the API audit's fixes,
adoption by projects beyond MoQ, and the checks, measurements, and proof
groundwork that keep rind correct and fast.

## Plan

Assurance joined m2 with the maintainer on 2026-11-09, after an audit of the
whole tree: ✅ active assurance work lives here (rejected: redefine m3 to hold
it, move only the security check). m3 had held it as "deferred" while its
quests were the most active in the tree.

## Required

- [The API steers callers away from misuse](/quest/m2/api/README.md) - the 2026-11-08 API audit's fixes
- [Adoption beyond MoQ](/quest/m2/adoption/README.md) - popular projects and other languages can choose rind, with what they need from it
- [Every primitive is tested as thoroughly as the best libraries test theirs](/quest/m2/confidence/README.md) - vectors, fuzzing, constant-time and mutation checks, and guards on the assembly boundary, wiping, and the adapters
- [The proofs every later proof builds on](/quest/m2/verified/README.md) - byte-identical assembly, the first HOL Light proofs, and a calibration of what one costs
- [Speed regressions are caught the night they land](/quest/m2/bench/README.md) - a nightly gate on every benchmark, and rows for the tiers and sizes nothing times
