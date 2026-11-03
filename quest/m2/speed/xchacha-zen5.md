# [S] XChaCha20-Poly1305 small messages on Zen 5 as fast as aws-lc-rs

## Goal

XChaCha20-Poly1305 sealing 32 B on Zen 5 matches aws-lc-rs, or the gap is recorded in README with its cause.

## Plan

Planned with the maintainer on 2026-11-03 from [moq-dev/rind#283](https://github.com/moq-dev/rind/pull/283). In [run 41572396019](https://github.com/moq-dev/rind/actions/runs/41572396019), sealing 32 B without AVX2 on Zen 5 took 676 ns against aws-lc-rs's 598 (1.13), and [run 41550703300](https://github.com/moq-dev/rind/actions/runs/41550703300) showed 1.15 without AVX2 and 1.11 natively on the same CPU. rind leads or is level on Zen 3 and Zen 4, and plain ChaCha20-Poly1305 is level on Zen 5, so the cost is outside the AEAD core: HChaCha20, the per-seal key setup, or the nonce handling.

- No local host is Zen 5. Find the cause by instruction counts (callgrind) against aws-lc-rs's XChaCha20 path, then confirm with branch and baseline bench runs on the runners, comparing within each run.
- Fix it at the source if the cause is clear; otherwise record the measurement and cause in README.
