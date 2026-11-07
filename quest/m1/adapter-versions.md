# [S] Each adapter's version matches the upstream it adapts

## Goal

Each published `rind-<consumer>` adapter's version begins with the semver-breaking part of the upstream version it adapts, and CI fails when the two drift: rind-ring 0.17.x for ring 0.17, rind-rustls 0.23.x, rind-rcgen 0.14.x, rind-object-store 0.14.x, rind-dimpl 0.9.x, rind-jsonwebtoken 11.x.

## Plan

Decided with the maintainer on 2026-11-07, before the launch post, while the adapters' 0.2.0 releases are hours old:

- Match only upstream's breaking prefix: major.minor below 1.0, major from 1.0 on. Patch numbers stay the adapter's own.
- An adapter's own breaking change waits for upstream's next breaking bump. Since [moq-dev/rind#420](https://github.com/moq-dev/rind/pull/420), no adapter re-exports rind types, so a rind major doesn't force one.
- A test in `just ci` compares each published adapter's version prefix with its upstream dependency's requirement, so a release PR that drifts fails CI. Configure release-plz in `.release-plz.toml` to avoid proposing such a bump where it can, and record what it can't prevent.
- Set the new versions by hand in one PR, then let release-plz publish them. Update each README's install line; rind-ring's still says `version = "0.1"`.
- rind-instant-acme is unpublished and follows the same rule when it ships.
- Note the rule in CONTRIBUTING.md and in the AGENTS.md line on adapters (the maintainer asked for this plan).

## Related

- [rind-rustls supports rustls 0.24](/quest/m2/adoption/rind-rustls-0.24.md): under this rule, keeping rustls 0.23 support means a 0.23.x maintenance line.
