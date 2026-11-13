# [M] A page per library says how to move from it to rind

## Goal

For each library rind stands in for, the site has a page at its own address, such as `/from/ring`, that gives the exact change: the `Cargo.toml` lines, the names that differ, and what rind cannot back. A picker on the landing page takes a visitor to theirs. Each is a page a search for "replace ring" or an agent choosing a dependency can land on directly.

## Plan

Decided 2026-11-12 (maintainer, /quest-plan): ✅ one of the three showpieces, and ✅ real pages, not a widget, because nothing on the site may exist only inside one.

- The pages, on 2026-11-12: ring and aws-lc-rs, each by its adapter or by the `[patch.crates-io]` route through rind-patch; rustls; and the crates with an adapter of their own (rcgen, jsonwebtoken, dimpl, str0m, object_store, openmls). MIGRATING.md's "Crates with their own crypto backend" survey gets one page listing each crate and what it needs.
- MIGRATING.md and each adapter's README are the source. Render their sections; do not write the steps a second time. Where a page needs text they lack, add it to them. If their headings are too loose to build from, give them the anchors or structure the build needs in this PR.
- Every version number on a page comes from that crate's `Cargo.toml` at build time. A `[dependencies]` line typed into a template is wrong by the next release.
- Each page states what its adapter cannot back, from the list its README keeps, before the reader finds out by compiling.
- The agent prompt for `MIGRATE.md` is on every page, since for ring and aws-lc-rs it is the shortest route.
- `sh/patch.sh` and `patch/fixture` already test the patch route. If a page shows a snippet no test builds, say which in the PR.
- [The API's shape](/quest/m2/api/shape.md) may rename and move types before rind 0.4. These pages are rendered from MIGRATING.md, so they follow it without a second edit.

## Required

- [The landing page builds from the repository](/quest/m2/site/landing.md) - the `site/` project and the picker's place on it
