# [S] Imported code is checked to regenerate exactly

## Goal

CI re-runs every importer and generator at its pinned source revision and fails if the result differs from the committed code, and no generator can leave a tracked file truncated when a tool is missing.

## Plan

Planned with the maintainer on 2026-11-03 from an external audit.

- Cover `admin/import-aws-lc`, `admin/import-boringssl`, `admin/import-openssl`, and the `admin/parse-asm` drivers (s2n-bignum and the precomputed tables), each at the revision it pins. Agents have regenerated these by hand to byte-identical output; this makes that a check.
- Generators write to a temporary file and rename it into place, so a failure partway (the `parse-asm` drivers open their outputs for writing before running their tools) leaves the tracked file intact.
- Run it nightly or when `admin/` or the pinned revisions change, not in the `just ci` gate.
