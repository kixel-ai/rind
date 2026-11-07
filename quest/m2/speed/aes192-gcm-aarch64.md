# [M] AES-192-GCM on aarch64 is level with aws-lc-rs for large messages

## Goal

On aarch64, AES-192-GCM seals and opens at 1200 B and up are at least as fast as aws-lc-rs on Neoverse-N2 and Apple Silicon.

## Plan

Decided with the maintainer on 2026-11-07: plan it in m2 speed, after the Apple Silicon AES-GCM quest. [moq-dev/rind#414](https://github.com/moq-dev/rind/pull/414) added AES-192 everywhere. s2n-bignum's stitched GCM kernels take only 128- and 256-bit keys, so on aarch64 AES-192-GCM runs rind's one-pass Rust for short messages and separate CTR and GHASH passes past that. At 1200 B and up, that takes 1.04-1.09x aws-lc-rs's time on N2, 1.35-1.68x on M2, and 0.97-1.55x on M1. Sending every length through the one-pass Rust was slower on N2 (1.14-1.32x).

For bulk encryption the fastest source wins outright. Import aws-lc's aarch64 GCM routines, which handle every key size, for AES-192, through `admin/import-aws-lc`, toggling DIT once per call as the other aarch64 kernels do. Measure on GitHub's N2 and macOS runners, comparing only matching `CPU:` lines and on macOS both with and without `rind::cpu::hold_dit()` held, since the per-call DIT toggle costs about 55 ns on M1, and keep 128 and 256 on s2n-bignum unless aws-lc wins there too. Run ctgrind on the new path and the Wycheproof and aws-lc-rs tests at 192 bits.
