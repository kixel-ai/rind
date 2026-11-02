# [XS] build.yml installs only what it uses

## Goal

`build.yml`'s Linux jobs stop installing valgrind if no step there needs it, as [moq-dev/rind#236](https://github.com/moq-dev/rind/pull/236) found for coverage.

## Plan

Planned with the maintainer on 2026-11-02.

- `ctgrind.rs` tests build crabgrind without its default features outside the ctgrind shell, so their calls are no-ops; confirm nothing else in `build.yml` runs valgrind, then drop the install.
