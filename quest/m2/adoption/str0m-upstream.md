# [S] str0m and dimpl take rind-str0m's upstream fixes

## Goal

Draft PRs on str0m and dimpl:
- str0m's README lists rind-str0m among its crypto providers, once rind-str0m is on crates.io.
- dimpl's `DtlsCertificate` wipes its private key on drop.
- str0m's SRTP ECB methods take fixed-size arrays, so a wrong-length key or block can't compile.

Together these retire the two exceptions [moq-dev/rind#467](https://github.com/moq-dev/rind/pull/467) records: the ECB panics on wrong-length slices, and the certificate key dimpl leaves unwiped.

## Plan

Planned with the maintainer on 2026-11-07, a follow-up of [moq-dev/rind#467](https://github.com/moq-dev/rind/pull/467), whose body lists all three.

- Decided with the maintainer on 2026-11-07: outside posts wait for the [launch post](https://moq.dev/blog/rind/), now up, then go up only as draft PRs, from kixelated forks, with the AI use stated and short bodies. Check each repository's contribution and AI policy again before posting.
- The dimpl `Drop` should follow the upstream crate's own conventions (for example `zeroize`, if it already depends on it); don't push rind's opt-in rule onto it.
- Once a fix is released upstream, update rind-str0m to drop the matching exception.
