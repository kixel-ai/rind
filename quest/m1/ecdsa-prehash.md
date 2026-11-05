# [M] ECDSA over a precomputed digest

## Goal

rind signs and verifies ECDSA over a digest the caller already computed, for P-256, P-384, and P-521, so Bun's node `createSign`/`createVerify` and other hash pairings can move to rind.

## Plan

Found by the Bun prototype ([moq-dev/rind#368](https://github.com/moq-dev/rind/pull/368)), and decided with the maintainer on 2026-11-05 that the first Bun PR waits for it. It adds API without changing any, so it can ship in a patch release.

A prehashed API is easy to misuse: signing raw data as if it were a digest, or a digest of the wrong length or hash. Make that hard through the types, for example a digest type that names its hash and comes only from rind's hashers or from a checked constructor. Put the shape to the maintainer as a decision. Follow aws-lc-rs where it is as clear. Test against Wycheproof and aws-lc-rs, and add ctgrind tests for the signing path.
