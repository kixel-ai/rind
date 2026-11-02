# [XS] COMPATIBILITY.md matches the CPU scans

## Goal

`COMPATIBILITY.md` is regenerated with `admin/x86-cpu markdown-table` from the current `admin/x86-cpus` scans, which gained fields (SSE4.1, VBMI, MOVBE, the Intel vendor) since it was last made.

## Plan

Planned with the maintainer on 2026-11-02 from [moq-dev/rind#240](https://github.com/moq-dev/rind/pull/240).

- Regenerate, check the diff is only the new columns and corrected rows, and consider a check that fails when the table and scans drift.
