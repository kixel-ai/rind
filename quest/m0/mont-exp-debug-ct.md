# [XS] x86_64 RSA exponentiation is constant time in debug builds

## Goal

ctgrind's x86_64 debug job passes again: `rind/src/low/x86_64/mont_exp.rs`
no longer branches on the secret window index in debug builds, and release
builds are confirmed not to branch on it either.

## Plan

Planned with the maintainer on 2026-11-02 as m0, from
[moq-dev/rind#261](https://github.com/moq-dev/rind/pull/261)'s checks: since
#224, the debug ctgrind job (`build (ubuntu-latest)`) fails on every branch at
`mont_exp.rs:140`, where `i < 32` on the secret window index becomes a branch
(for example run 41520891829).

- Remove the check or make it constant time; if it is an index bounds check,
  confirm release code has no branch either (ctgrind release passes today).
- Prove the fix with debug and release ctgrind on the RSA tests, with and
  without ADX.
