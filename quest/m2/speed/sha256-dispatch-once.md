# [XS] x86_64 SHA-256 picks its path once

## Goal

On x86_64 without SHA-NI, SHA-256 chooses its block function once per process instead of testing up to three CPU features on every compression.

## Plan

Planned with the maintainer on 2026-11-02 from [moq-dev/rind#230](https://github.com/moq-dev/rind/pull/230).

- Resolve the AVX2/AVX/SSSE3 choice at first use, the way other x86_64 dispatch is cached, and measure one-block and small-update rows on the forced no-SHA tiers of the bench workflow.
