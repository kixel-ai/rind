# [XS] README and the ✓ table claim only what is proven

## Goal

README's Sources and Algorithms tables and `benchmarks/verified.toml` mark ✓ only where a current published proof covers the code rind runs, matching the verification audit.

## Plan

Planned with the maintainer on 2026-11-03 from the audit ([moq-dev/rind#318](https://github.com/moq-dev/rind/pull/318)), which found README's "aws-lc ✓" on x86_64 AES-GCM stale: aws-lc-verification's `aesni_gcm` proof is disabled, covered only AES-256, and predates rind's copy, which also runs AES-128. Apply every correction the audit's report lists.
