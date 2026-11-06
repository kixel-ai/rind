# [S] One-pass AES-GCM for short messages on aarch64

## Goal

On aarch64 with the crypto extension, AES-GCM on a message of a few blocks runs in one pass, so ACK-sized QUIC sends match or beat aws-lc-rs on Neoverse N2, where they trail today.

## Plan

Approved by the maintainer on 2026-11-05, from [moq-dev/rind#387](https://github.com/moq-dev/rind/pull/387). On Neoverse N2 (Azure Cobalt 100), a 32 B send (3 B payload) through rustls is 0.91x aws-lc-rs and a 64 B send 0.89x, and still 0.93x and 0.91x with DIT denied, while a raw 32 B seal with 20 B AAD is 1.03x. `low/aarch64/aes_gcm.rs` hashes the AAD, the sub-block tail, and the lengths block in separate GHASH calls, and encrypts the tail and the tag block one at a time.

- Compute the counter blocks and E(Y0) together, and fold the AAD, data, and lengths into one GHASH reduction, for messages up to the length where the existing kernels win. Measure that length.
- DIT stays set and cleared on every call (maintainer, 2026-11-05): constant time is a Required rule, and dropping the toggle would save only about 1.6 ns a call on N2. An API that processes a batch toggles once per call, never per block. Measure with DIT on, as it ships.
- Benchmark 32 B and 64 B seals and opens with a 13 B AAD, AES-128 and AES-256, against aws-lc-rs on N2.
