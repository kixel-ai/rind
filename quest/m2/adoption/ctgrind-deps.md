# [XS] rind's test-only features add no packages to dependents' lockfiles

## Goal

Depending on rind adds none of the packages behind its `__ctgrind` feature to a dependent's `Cargo.lock`.

## Plan

Found by the migration prompt's trial ([moq-dev/rind#357](https://github.com/moq-dev/rind/pull/357)): `__ctgrind = ["dep:crabgrind"]` puts about 20 optional packages into every dependent's lockfile, which reads as bloat in a migration diff. Move the ctgrind harness to a dev-dependency or a separate unpublished crate, keeping `admin/ctgrind` and CI's ctgrind runs working.
