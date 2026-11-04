# [S] armv7 ChaCha20-Poly1305 and SHA-512 run proven code where it is fast enough

## Goal

On armv7, ChaCha20-Poly1305 and SHA-512 switch to libcrux's proven implementations where they are faster or within about 10% of today's, earning ✓ there.

## Plan

Planned with the maintainer on 2026-11-03 from the audit. Re-measure on the GitHub arm64 runner in 32-bit mode first; earlier comparisons paired runs from different dates.
