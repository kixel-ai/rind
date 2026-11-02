# [XS] AES-128-GCM 16 KB bench measures the cipher

## Goal

The `aes_gcm` bench's AES-128 16 KB rows reflect AES-128's real cost on every
runner CPU, instead of taking about 3x as long as AES-256 at 16 KB in all
three libraries.

## Plan

Planned with the maintainer on 2026-11-02 from
[moq-dev/rind#256](https://github.com/moq-dev/rind/pull/256): on the EPYC 7763,
seal and open at AES-128 16 KB took 7.5-8.2 µs against 2.6 µs for AES-256 in
rind, aws-lc-rs, and ring alike (runs 41514228885 and 41472308771), and once on
the no-AVX tier. rind's ratio stays 1.00, so this is the bench, not rind.

- Suspect buffer placement (4K aliasing between input and output, or page
  boundaries); check alignment and offsets of the bench buffers.
- Fix it in the bench so all three libraries benefit, and confirm on a runner.
