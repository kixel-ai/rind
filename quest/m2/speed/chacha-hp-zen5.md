# [S] ChaCha20 header protection on Zen 5 as fast as aws-lc-rs

## Goal

ChaCha20 QUIC header protection on x86_64 Zen 5 matches aws-lc-rs, or the gap is recorded in README with its cause.

## Plan

Planned with the maintainer on 2026-11-03 from [moq-dev/rind#285](https://github.com/moq-dev/rind/pull/285). Natively on Zen 5 (EPYC 9V45), header protection took 140 ns against aws-lc-rs's 79 (1.89) in [run 41585945720](https://github.com/moq-dev/rind/actions/runs/41585945720), and 1.77 in [run 41550703300](https://github.com/moq-dev/rind/actions/runs/41550703300). Other paths on the same CPU read 0.93, and README's x86_64 column drew Zen 3, so the table hides it.

- Suspect: the same Zen 5 latency #285 found for HChaCha20, where simple vector-integer operations take 2 cycles, applied to a single-block ChaCha20 run as one dependent SSE/AVX chain. Compare rind's path with aws-lc's by callgrind and code inspection.
- Prefer a verified or scalar single-block path (such as HACL*'s, as #285 did) when it is close, and confirm with branch and base bench runs on the runners (not on `main`, whose concurrency group cancels other runs), noting which CPU each job drew.
