# [M] rind's public API is audited before 0.2.0

## Goal

Every public item in `rind` and its `rind-*` adapters meets AGENTS.md's API rules before 0.2.0 is released: misuse fails to compile where it can, names follow their role, there is one way to do each job, and it is documented in one line. Each finding is either fixed or kept by a recorded maintainer decision.

## Plan

Decided with the maintainer on 2026-11-05: take 0.2.0, but release it only after a full audit ✅. The audit waited only for in-flight work that may change existing APIs (stored agreement keys, [moq-dev/rind#372](https://github.com/moq-dev/rind/pull/372); Ed25519 loading needed no API change, per [moq-dev/rind#373](https://github.com/moq-dev/rind/pull/373)). APIs that only add items ship afterwards in patch releases, built to the audit's standards.

The audit of `main` at f0b79317 is done ([moq-dev/rind#383](https://github.com/moq-dev/rind/pull/383)): its inventory covers every published crate, MIGRATING.md maps every `rind` item, and rind-ring matches ring 0.17 name for name. What remains:

- The maintainer picks each of the PR's `## Decisions needed`, batched by module, each with options and a recommendation.
- The picked fixes land in that PR before the release. Mark each breaking one with `!` and give its migration.
