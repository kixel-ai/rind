# [S] P-256 key generation as fast as BoringSSL

## Goal

Generating a P-256 key with rind is at least as fast as BoringSSL and aws-lc-rs on every CPU the report measures, so Bun can move P-256 to rind with its other curves.

## Plan

The Bun prototype ([moq-dev/rind#368](https://github.com/moq-dev/rind/pull/368)) measured rind's P-256 key generation at 0.6x BoringSSL's speed on several CPUs, so it left P-256 on BoringSSL. Profile it first. Candidates include the base-point multiplication, the scalar draw and its rejection loop, and the public key's affine conversion. Compare against BoringSSL's and aws-lc's on the same CPU. aarch64 runs s2n-bignum's proven `p256_scalarmulbase`: keep it proven unless another source is more than 10% faster.
