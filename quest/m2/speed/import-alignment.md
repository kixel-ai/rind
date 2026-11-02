# [XS] Imported aws-lc routines keep their alignment

## Goal

`admin/import-aws-lc` keeps the `.align` aws-lc puts before routines it carries alongside another (such as `mul4x_internal`, aligned to 32), or the PR shows it doesn't matter.

## Plan

Planned with the maintainer on 2026-11-02 from [moq-dev/rind#224](https://github.com/moq-dev/rind/pull/224).

- Measure one carried routine with and without the alignment on the GitHub runners; restore it in the importer only if it measures faster. Regenerated files must otherwise stay byte-identical.
