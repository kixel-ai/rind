# [L] aarch64 SHA-512 on the SHA-512 instructions is proven

## Goal

SHA-384, SHA-512, and SHA-512/256, and with them Ed25519 and HMAC and HKDF over SHA-384, earn the ✓ on aarch64 cores with the SHA-512 instructions (Graviton 3 and later, Apple, Neoverse N2 and V), the tier `benchmarks/verified.toml`'s aarch64 entries now exclude with `!sha3`.

## Plan

- Runs: aws-lc's `sha512_block_data_order_hw` (`low/aarch64/aws_lc/sha512_block_data_order_hw.*.s`), under rind's padding and digest glue, which `proofs/` already proves.
- Already proven: aws-lc-verification's NSym proof of this routine leaves the digest in registers at its loop's exit, before the store to the state, so it states no result (decided strict with the maintainer on 2026-11-04). aws-lc-verification has merged nothing since 2026-03 and has no work on the store.
- Route: a HOL Light proof of the whole routine in s2n-bignum's aarch64 model, which already models `sha512h`, `sha512h2`, `sha512su0`, and `sha512su1`, against [awslabs/s2n-bignum#420](https://github.com/awslabs/s2n-bignum/pull/420)'s FIPS 180-4 SHA-512 spec, then an axiom in `proofs/Rind/Aarch64/AwsLc.lean` beside the `nohw` one. This also drops NSym's ArmSpecGap caveat from this path.
- Spec pin: build on [awslabs/s2n-bignum#420](https://github.com/awslabs/s2n-bignum/pull/420)'s spec at a pinned commit while it is unmerged, and move to the merged version when it lands; `benchmarks/verified.toml`'s ✓ notes the pin (decided with the maintainer on 2026-11-07 on [moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448)).
- Upstream: offering this work to awslabs/s2n-bignum is optional, and there is no standing approval: stop and ask the maintainer before posting there or anywhere outside the moq-dev and kixelated orgs (decided with the maintainer on 2026-11-07 on [moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448)).

## Required

- [rind's own HOL Light proofs live in proofs/hol-light](/quest/m3/verified/hol-light.md) - where the HOL Light proofs live and CI checks them
- [aarch64 SHA-256 on the SHA-2 instructions is proven](/quest/m2/verified/sha256-aarch64-hw.md) - the calibration: what a hand-written HOL Light proof of unproven assembly costs
