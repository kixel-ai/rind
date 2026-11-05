# [XS] Confirm x86_64 RSA-2048 signing level in the report

## Goal

A refresh of [BENCHMARKS.md](/BENCHMARKS.md) at or after [moq-dev/rind#351](https://github.com/moq-dev/rind/pull/351) shows RSA-2048 PKCS#1 and PSS signing, and the full handshake under an RSA-2048 certificate, within 10% of the fastest library on `nixos`, `desktop`, and `nixos2`, and this gap's entry leaves `benchmarks/gaps.toml`.

## Plan

- #351 gathers each window entry by AVX2 rather than s2n-bignum's scalar `bignum_copy_row_from_table`, which spent a fifth of each 16-word exponentiation. Interleaved on `nixos`, signing fell from 494-520 µs to 417-431 µs, ahead of graviola (431-457 µs) and ring (431-483 µs).
- #351 could not refresh the report: `admin/bench-report collect` skips a busy host, and all three were busy. Run it when they are idle, then `render`, and drop the entry.
- If a host still shows the gap, time the CRT and fault-check glue next, as this quest planned before #351.
