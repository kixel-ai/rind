# [XS] Settle 1.0's exit criteria and the security backport window

## Goal

The maintainer has decided what 1.0 requires beyond what README.md already says, and which release lines get security backports, so [STABILITY.md](/STABILITY.md) and [SECURITY.md](/SECURITY.md) state commitments instead of today's facts.

## Plan

Planned with the maintainer on 2026-11-21 (`/quest-plan`). The semver gate (`sh/semver.sh`), the changelog scoping (`rind/README.md` as a copy), STABILITY.md's factual list of what is checked and what is open, and SECURITY.md's statement that only the latest release gets a fix and rind keeps no release branch are done. What remains is each commitment the repository cannot derive; each is a `Waiting` item with a recommendation. Once the maintainer answers, write the answer into STABILITY.md or SECURITY.md and delete this quest.

## Waiting

- Maintainer: do older minors get security backports? Options: (a) only the latest release, as SECURITY.md says today; (b) also the previous minor for a fixed window. Recommendation: (a) below 1.0, since a minor batches every breaking change and an adapter pins one rind minor, so a second line would double every release PR; from 1.0, back-port to the last minor of the previous major for 6 months, on a `release/<major>.<minor>` branch release-plz can open a release PR from. Answer by editing SECURITY.md's Supported versions.
- Maintainer: does 1.0 require an outside audit of the Phase 1 scope in [the audit scope quest](/quest/m2/trust/third-party-audit-scope.md)? Recommendation: yes, report published, since README.md's "no one outside the project has audited it" would otherwise ship in a 1.0 release; FIPS 140-3 validation is not a requirement.
- Maintainer: how long must the API sit without a breaking change before 1.0? README.md says only that none is planned. Recommendation: one full minor release (0.4 to 0.5 with no `!` change in `rind`, which `sh/semver.sh` enforces), so 1.0 is the 0.5 line re-tagged.

## Related

- [Scope phased third-party security audit and prepare grant funding packet](/quest/m2/trust/third-party-audit-scope.md)
- [rind 0.4 ships once](/quest/m2/api/release-0.4.md)
