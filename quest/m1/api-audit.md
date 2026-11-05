# [M] rind's public API is audited before 0.2.0

## Goal

Every public item in `rind` and its `rind-*` adapters meets AGENTS.md's API rules before 0.2.0 is released: misuse fails to compile where it can, names follow their role, there is one way to do each job, and it is documented in one line. Each finding is either fixed or kept by a recorded maintainer decision.

## Plan

Decided with the maintainer on 2026-11-05: take 0.2.0, but release it only after a full audit ✅. The audit waited only for in-flight work that may change existing APIs (stored agreement keys, [moq-dev/rind#372](https://github.com/moq-dev/rind/pull/372); Ed25519 loading needed no API change, per [moq-dev/rind#373](https://github.com/moq-dev/rind/pull/373)). APIs that only add items ship afterwards in patch releases, built to the audit's standards.

- Walk `cargo doc`'s public surface of each published crate. Compare names and shapes with aws-lc-rs's, and check MIGRATING.md maps each one.
- Each finding goes to the maintainer as a decision with options and a recommendation, through `## Decisions needed`. Batch them by module.
- Breaking fixes land before the release. Mark each with `!` and give its migration.
