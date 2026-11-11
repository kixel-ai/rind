# [S] AES-KW and AES-CBC lose no fixed cost per call to aws-lc

## Goal

AES-KW/KWP wrapping and AES-CBC on x86_64 and aarch64 run within 1.10× of aws-lc-rs's time at every nightly size, and `benchmarks/gaps.toml` drops the entries that point here.

## Plan

Decided with the maintainer on 2026-11-10, while settling [moq-dev/rind#560](https://github.com/moq-dev/rind/pull/560): ✅ one speed quest for the fixed per-call cost of KW and CBC on x86_64 and aarch64 (rejected: leave the gaps "not yet decided", a speed quest per gap).

The nightly of [run 42734638175](https://github.com/moq-dev/rind/actions/runs/42734638175) shows three gaps, each 1.1 to 1.2×:

- AES-CBC encryption on aarch64, from 1200 B up, against aws-lc's `aes_v8` assembly. CBC encryption is serial in both, so the gap is per block or per call, not interleaving.
- AES-KW/KWP wrapping of 16 or 32 bytes on x86_64, without AVX2, and without AES-NI: a few nanoseconds per call over six serial rounds per block.
- AES-CBC decryption of 32 bytes on GitHub's EPYC 9V45 runner only: 21 to 27 ns against aws-lc's 18 to 20 ns. The EPYC 7763 of [run 42526977036](https://github.com/moq-dev/rind/actions/runs/42526977036) measured it within 10%.

Guidance:

- Profile first: key schedule per call, a copy, a bounds check per block, or a missing inline across the mode loop. Measure each fix against aws-lc-rs on the same host.
- aws-lc's KW and CBC are C over its block cipher (`crypto/fipsmodule/aes/key_wrap.c`, `cbc.c`) on x86_64 and `aes_v8` on aarch64; take its structure where it is the faster source.
- Keyed state stays wiped through `low::zeroise`; a changed secret path gets its ctgrind test.
