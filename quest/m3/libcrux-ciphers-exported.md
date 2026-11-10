# [XS] libcrux exports its raw ciphers

## Goal

A published libcrux release exports the AES block cipher and AES-CTR from
libcrux-aes, which 0.0.10 keeps `pub(crate)`. Check the crate's latest `src/lib.rs` on crates.io. This
quest only waits; delete it once that holds.

## Plan

Asking libcrux (cryspen/libcrux) for the exports is outward-facing: ask the
maintainer before filing an issue or PR there.

## Waiting

- cryspen/libcrux: publishes a libcrux-aes release that exports the AES block cipher and AES-CTR. On 2026-11-09 the newest on crates.io was still 0.0.10 (2026-10-07), the release this quest names. Check the newest release's `src/lib.rs` on crates.io for `pub` items in place of `pub(crate)`.
