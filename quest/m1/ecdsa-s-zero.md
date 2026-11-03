# [XS] ECDSA signing retries when s is zero

## Goal

ECDSA signing draws a new nonce when s = 0 as well as when r = 0, as FIPS 186-5 requires and aws-lc does, so rind never emits a signature its own verifier rejects.

## Plan

Planned with the maintainer on 2026-11-03 from an external audit. `high/ecdsa.rs`'s signing loop retries only on r = 0. The chance of s = 0 is negligible, but the fix is one check on public output, inside the same retry loop.
