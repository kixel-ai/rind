# [S] BINSEC's portable ML-KEM-768 check finishes within its timeout

## Goal

`ct_binsec_mlkem768` in `binsec (portable)` (`.github/workflows/ctgrind.yml`, `admin/ct-binsec --timeout 480`) reports `secure` again instead of `unknown`, without raising the timeout or skipping the test. Since run 44377928646 (2026-11-18 19:11 UTC) it runs out of time with one path pending, whatever the PR changes; earlier runs that day, such as 44346754156 at 16:23 UTC, passed.

## Plan

- Seen on [kixel-ai/rind#885](https://github.com/kixel-ai/rind/pull/885) (job 135189441063), and on unrelated heads `efe32252` and `374202449`: `checkct` exits at 480 s with `timeout has left (at least) 1 pending paths`, with all 421k control-flow and 316k memory checks passing so far. ML-KEM-512 and -1024 still finish.
- [kixel-ai/rind#894](https://github.com/kixel-ai/rind/pull/894) bisects the cause to [kixel-ai/rind#870](https://github.com/kixel-ai/rind/pull/870), whose counted loops changed the code BINSEC explores, and pins another message as [kixel-ai/rind#841](https://github.com/kixel-ai/rind/pull/841) did. If it lands first, delete this quest.
- Fix the cause in the code or in the check's region, so the exploration completes. If it is genuinely slower, find what BINSEC unrolls that the other sizes don't before touching the timeout.
