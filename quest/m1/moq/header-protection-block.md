# [XS] Header protection calls the hardware AES block directly

## Goal

An AES QUIC header-protection mask reaches the CPU's AES block without going through `AesKey::encrypt_block`, so AES-128 header protection is no slower than aws-lc-rs's on AMD, where it trails today.

## Plan

Approved by the maintainer on 2026-11-05, from [moq-dev/rind#387](https://github.com/moq-dev/rind/pull/387). rind's AES-128 mask is 0.83x aws-lc-rs on Zen 3, 0.89x on Zen 4, and 0.90x on Zen 5, about 4.6 ns slower per mask on an EPYC 7763; on Arrow Lake it is 2.5x faster. perf shows `AesKey::encrypt_block` reserving a 3.8 KB stack frame, because the no-AES-NI variant's key schedule inlines into it, then decoding a 128-bit niche discriminant and making two more non-inlined calls before `aes128_block`.

- Pick the block function once, when `aead::quic`'s `Masker` is built, and keep the software variants' code out of line, so the hardware path carries no large frame.
- `by8`'s E(Y0) tag block in `low/x86_64/aes_gcm.rs` takes the same path, so fix it too and measure sub-256 B seals.
- Measure AES-128 and AES-256 masks against aws-lc-rs on Zen 3 to 5 and Arrow Lake, and check aarch64 doesn't regress.
