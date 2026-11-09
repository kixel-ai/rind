# [XS] HKDF-SHA256 expand is back to its earlier speed on x86_64

## Goal

`hkdf-sha256/expand/rind` is back to its speed at `f95b91da` on x86_64, or interleaved runs on a GitHub x86_64 bench runner show the change was noise and this quest records that. HKDF expand runs on every QUIC key derivation. The fix keeps the nightly ctgrind run green.

## Plan

[moq-dev/rind#484](https://github.com/moq-dev/rind/pull/484)'s `desktop` (Arrow Lake) run measured `hkdf-sha256/expand/rind` at 66 ns at `9e7f6a5a`, against 47 ns in the previous `desktop` run at `f95b91da`. rind is still the fastest library on that row, so it is no gap in `benchmarks/gaps.toml`, and `kixtop` did not move.

- Decided with the maintainer on 2026-11-07: confirm before fixing. Time `f95b91da` and `9e7f6a5a` interleaved on a GitHub x86_64 bench runner, dispatched from a scratch branch. If the slowdown reproduces, bisect the rind commits between them; if not, record the noise in the PR and delete this quest.
- The first suspect, [moq-dev/rind#406](https://github.com/moq-dev/rind/pull/406), put HMAC's `tag` out of line (`#[inline(never)]` in `rind/src/high/hmac.rs`) so memcheck stops flagging PBKDF2's unswitched loop. Only PBKDF2 calls `tag`, though, so it should not touch HKDF. Likelier suspects among the 23 commits are [moq-dev/rind#416](https://github.com/moq-dev/rind/pull/416) (digest contexts start from a constant) and [moq-dev/rind#412](https://github.com/moq-dev/rind/pull/412) (MD5 joins the digest algorithms).
- Name the commit that caused it under `## Caused by` in the fix PR. If the fix needs code out of line for ctgrind, keep it out of line only under the `__ctgrind` feature.

- Confirmed on 2026-11-08: six alternating historical pairs reproduce a 7–10% regression on AMD EPYC 7763, bisected to `4a010b68880afd9a2855f4055b3123459d6d7ab8` ([moq-dev/rind#394](https://github.com/moq-dev/rind/pull/394)). That change replaced HKDF's dropping HMAC Context with non-dropping Streaming state. Do not restore in-call wipes.
- The update inline hint in [moq-dev/rind#505](https://github.com/moq-dev/rind/pull/505) failed its interleaved validation and is removed. An explicit finish inline hint leaves the local expand routine unchanged. Further investigation must identify the historical code-generation difference and demonstrate recovery with interleaved measurements against aws-lc-rs before declaring this complete.
