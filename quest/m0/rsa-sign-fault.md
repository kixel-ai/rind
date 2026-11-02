# [S] x86_64 RSA signing never faults on a valid key

## Goal

RSA signing on x86_64 returns a correct signature for every valid key and
salt. Today `high::rsa::tests::loads_q_above_p` intermittently fails: about 1
run in 300 on an i7-8700, `sign_pss_sha512` returns `Fault` at
`rind/src/high/rsa.rs:656`, so the CRT self-check catches a wrong signature.

## Plan

Planned with the maintainer on 2026-11-02 as top priority, from the
[moq-dev/rind#231](https://github.com/moq-dev/rind/pull/231) checks.

- Reproduce, then make it deterministic: the failure seems to depend on the
  random PSS salt with a key where q > p, so drive signing with a fixed salt
  or RNG until a failing input is found.
- Bisect main; recent changes in this area include #204 (prime distance),
  #216 and #221 (wipes), and the x86_64 Montgomery routines.
- Fix the root cause at its source, keep the code constant time, and add a
  regression test with the failing input. Check whether aarch64 and armv7
  share the faulty path.
- If a released version is affected, say which in the PR so a release can
  follow.
