# [XS] s2n-bignum's SHA-256 spec has merged

## Goal

[awslabs/s2n-bignum#450](https://github.com/awslabs/s2n-bignum/pull/450), which adds a FIPS 180-4 SHA-256 spec and a proven x86_64 SHA-NI routine, has merged upstream. Check the PR's state. This quest only waits; delete it once that holds.

## Plan

Planned with the maintainer on 2026-11-03 from [moq-dev/rind#328](https://github.com/moq-dev/rind/pull/328): the x86_64 SHA-256 proof route and the aarch64 revisit both start from #450's spec. Don't post upstream about it unless the maintainer asks.
