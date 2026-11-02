# [XS] Imported routines start at aws-lc's alignment

## Goal

Top-level routines imported from aws-lc start at aws-lc's 16-64-byte alignment instead of rustc's 4-byte naked-function default, if that measures faster; otherwise the quest closes with the numbers.

## Plan

Planned with the maintainer on 2026-11-02 from [moq-dev/rind#262](https://github.com/moq-dev/rind/pull/262), which restored the alignment of carried routines only.

- Options: a leading `.p2align` in each naked body (no padding on ELF, where each function has its own section, but executed padding on Mach-O), or `#[align]` once it is stable.
- Measure on the GitHub runners; don't chase noise.
