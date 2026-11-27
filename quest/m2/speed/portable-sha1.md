# [S] The portable backend's SHA-1 is as fast as aws-lc's integer code

## Goal

On the weekly bench's portable row, SHA-1 and HMAC-SHA-1 take no more than aws-lc's time from 1200 B up, closing the 1.11 to 1.24× gap that `benchmarks/gaps.toml`'s portable SHA-1 entry records, without slowing armv7 without NEON, which already runs aws-lc's integer `sha1_block_data_order_nohw`.

## Plan

Planned 2026-11-27 (owner: close the top five benchmark gaps, overriding the entry's reason that SHA-1 is too rare on targets without assembly to speed up).

- Take aws-lc's integer `sha1_block_data_order_nohw` for the portable backend, as armv7 without NEON already does, or match its schedule (message expansion interleaved with the rounds, 16-word circular buffer) in rind's Rust, whichever measures faster on the portable row and on riscv64 under QEMU.
- SHA-1 processes public data in HMAC's case too, so no new constant-time risk: keep the existing known-answer, NIST and Wycheproof tests passing, and add a differential test against the current code over random lengths.
- The finishing PR removes the gap's entry with the numbers.
