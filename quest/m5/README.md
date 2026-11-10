# m5: cold tiers

## Goal

Work on the tiers few machines run, after m4's: proofs of armv7 and of the legacy and fallback tiers of x86_64 and aarch64.

## Plan

Created with the maintainer on 2026-11-09, staging the proof plan: ✅ cold tiers move here (rejected: every proof stays in m4, where a cold tier ranks level with a hot one).

## Required

- [Every cold tier is proven](/quest/m5/verified/README.md) - armv7, the legacy hashes, and the paths without AES or SHA hardware
- [armv7 is proven](/quest/m5/verified-armv7/README.md) - an AArch32 model, then armv7's assembly, curves, and Rust, promoted out of the cold-tier epic
