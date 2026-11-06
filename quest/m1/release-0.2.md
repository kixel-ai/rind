# [XS] rind 0.2.0 is released

## Goal

rind 0.2.0, carrying the audited API, is on crates.io with its adapters, so Bun and MoQ can depend on a published release with the new APIs.

## Plan

Decided with the maintainer on 2026-11-05: follow semver from now on, so main's breaking changes ([#352](https://github.com/moq-dev/rind/pull/352)'s `finish(&mut self)` and [#360](https://github.com/moq-dev/rind/pull/360)'s AES-CTR) make it 0.2.0. Merge release-plz's release PR once the audit lands, after checking its versions and changelog. Later additive APIs ship as 0.2.x patch releases.
