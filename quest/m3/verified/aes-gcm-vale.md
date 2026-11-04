# [M] x86_64 AES-GCM runs a proven AEAD

## Goal

On x86_64 CPUs with AVX and MOVBE, rind's AES-GCM runs HACL*'s Vale AES-GCM, whose proof covers the whole AEAD, if it is within about 10% of aws-lc's routine rind runs today, earning AES-GCM the report's ✓ there.

## Plan

Planned with the maintainer on 2026-11-03 from the audit, which found aws-lc-verification's `aesni_gcm` proof disabled, AES-256 only, and older than rind's copy. Measure first on the GitHub runners; if Vale is clearly slower, record the gap instead. Check Vale's in-place and buffer contracts against rind's AEAD API.
