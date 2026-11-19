# [S] BINSEC's portable ML-KEM-768 check finishes within its timeout

## Goal

`ct_binsec_mlkem768` in `binsec (portable)` (`.github/workflows/ctgrind.yml`, `admin/ct-binsec --timeout 480`) reports `secure` again instead of `unknown`, without raising the timeout or skipping the test. Since 2026-11-18 it runs out of time with one path pending on every PR that runs `binsec`, whatever the PR changes, so that check fails on all of them.

## Plan

- Seen on [kixel-ai/rind#885](https://github.com/kixel-ai/rind/pull/885) (job 135189441063), and on unrelated heads `efe32252` and `374202449`: `checkct` exits at 480 s with `timeout has left (at least) 1 pending paths`, with all 421k control-flow and 316k memory checks passing so far. ML-KEM-512 and -1024 still finish.
- Find the PR that slowed it. The first failing run, 44377928646 (2026-11-18 19:11 UTC, `quest/m4/verified/mlkem-construction`), predates [kixel-ai/rind#870](https://github.com/kixel-ai/rind/pull/870) landing on main, so check that branch's base and [kixel-ai/rind#858](https://github.com/kixel-ai/rind/pull/858), the other recent change to `rind/src/low/generic/mlkem.rs` and `rind/src/mid/mlkem`. [kixel-ai/rind#841](https://github.com/kixel-ai/rind/pull/841) last made these checks finish on every run, so start from what it did.
- Fix the cause in the code or in the check's region, so the exploration completes. If it is genuinely slower, find what BINSEC unrolls that the other sizes don't before touching the timeout.
