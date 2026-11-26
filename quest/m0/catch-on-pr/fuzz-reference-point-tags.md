# [XS] The oprf and frost fuzz targets check only the encodings their RFCs allow

## Goal

`fuzz/fuzzer/oprf.rs` and `fuzz/fuzzer/frost.rs` pass on inputs where rind refuses a point encoding its RFC forbids but the reference crate accepts. For those inputs the harness asserts that rind refuses, as `fuzz/fuzzer/opaque.rs` does for opaque-ke's compact P-256 points ([kixel-ai/rind#1054](https://github.com/kixel-ai/rind/pull/1054)), and it compares the two implementations only on encodings the RFCs allow. rind's own parsing doesn't change.

## Plan

Found by the release PR's `fuzz` run of 2026-11-25 ([run 45588798339](https://github.com/kixel-ai/rind/actions/runs/45588798339)): `Fuzz oprf` fails at `fuzz/fuzzer/oprf.rs:91` (rind `KeyRejected(NotOnCurve)`, reference accepts), and `Fuzz frost` and its portable and aarch64 replays fail at `fuzz/fuzzer/frost.rs:65` (rind `BadSignature`, reference accepts). The release session traced both to the references accepting compressed-point tags other than `0x02` and `0x03`. Before changing anything, decode the failing inputs from the run's artifacts to confirm that cause, and add them to each target's seeds.

- Decided 2026-11-25 (maintainer, /quest-plan): ✅ fix the harness, m0 (rejected: dropping the targets, leaving the rows red).
- If an input shows rind refusing an encoding its RFC allows, that is a rind bug: fix rind instead, and say so in the PR.
- The `dimpl` row in the same run was the dimpl key-share quest's, which this fork finished (`fix(dimpl): accept the NIST key shares aws-lc-rs accepts`, 28235a606) and removed.

## Related

- `fix(dimpl): accept the NIST key shares aws-lc-rs accepts` (28235a606) - the fix for the same run's third failing target, rind-dimpl's NIST-curve key shares
