# [XS] dimpl checks signatures for every provider

## Goal

dimpl runs its RFC 8446 §4.4.3 check (a CertificateVerify's scheme matches
the certificate's curve) for every provider, not only behind its internal
`_crypto-common` feature, and a dimpl release carries it. Reported as
[algesten/dimpl#208](https://github.com/algesten/dimpl/issues/208); check
that issue and dimpl's releases. This quest only waits; delete it once a
release holds the fix.

## Plan

Planned by the maintainer on 2026-10-28.
[kixelated/rind#16](https://github.com/kixelated/rind/pull/16) enabled the
feature in `rind-dimpl` to keep the check. Once released, drop it from
`rind-dimpl/Cargo.toml` in the PR that bumps dimpl, keeping the test that a
mismatched scheme is refused.

## Waiting

- algesten/dimpl: fixes [#208](https://github.com/algesten/dimpl/issues/208) and publishes a release that carries the fix. On 2026-11-09 the issue was open and the newest release was 0.9.0 (2026-10-25). Check with `gh issue view 208 -R algesten/dimpl --json state`, then dimpl's releases on crates.io.
