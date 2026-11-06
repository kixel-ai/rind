# m0: immediate priorities

## Goal

The work that cannot wait: security advisories against rind or its
dependencies, a failing `main`, and anything that breaks MoQ on a published
rind release, and hosted CI that blocks every PR. Otherwise empty while
nothing is urgent.

## Required

- [Confine release credentials to publishing](/quest/m0/confine-release-credentials.md) -
  keep release credentials behind the protected publish path and replace the
  long-lived crates.io token
- [ctgrind passes on main again](/quest/m0/ctgrind-main.md) - the nightly constant-time gate, failing since 2026-11-04
