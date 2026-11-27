# [S] QUIC header protection with AES on aarch64 calls the cipher directly

## Goal

On Apple M4, rind-rustls's AES-128 and AES-256 QUIC header protection mask takes no more than aws-lc-rs's time (2.89 and 3.13 ns on `kixtop`), closing the 1.19 to 1.30× gap that `benchmarks/gaps.toml`'s `quic-header-protection` entry records.

## Plan

Planned 2026-11-27 (owner: close the top five benchmark gaps).

- Today the mask reaches the key's block cipher through an indirect call, as ALGORITHMS.md notes, costing about 0.86 ns a mask on `kixtop`. Store the key's resolved backend in the header protection key, as an enum matched at the call or a monomorphised key type, so one AES block is a direct, inlinable call to the AES-instruction routine. Keep the indirect path only where the CPU tier is unknown at key setup.
- The change is in shared code, so check x86_64 doesn't get slower (`quic-header-protection/*` on an x86_64 host), and run the QUIC header protection RFC 9001 vectors and rustls's QUIC tests on both arches.
- Re-measure on `kixtop` (or any Apple M-series host); the finishing PR removes the gap's entry with the numbers.
