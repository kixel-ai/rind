# [S] ChaCha20 header protection is proven

## Goal

QUIC ChaCha20 header protection earns the report's ✓ on x86_64, where it runs HACL*'s verified rounds inside a 45-line wrapper, and on aarch64 and armv7 if HACL*'s rounds are within about 10% of today's code there.

## Plan

Planned with the maintainer on 2026-11-03 from the audit. Prove the single-block wrappers with the chosen tool; measure HACL*'s rounds for header protection on aarch64 and armv7 on the GitHub runners before switching.
