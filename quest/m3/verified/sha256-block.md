# [L] aarch64 SHA-256 block functions are proven

## Goal

aarch64 with the SHA-2 instructions runs a proven SHA-256 block function, through a HOL Light proof of aws-lc's `sha256_block_data_order_hw` in s2n-bignum's style or a switch to a proven alternative within about 10% of it. Together with the hash glue, SHA-256, HMAC-SHA256, and HKDF then earn ✓ on aarch64, as x86_64 with SHA-NI can since it runs Vale's proven routine.

## Plan

Planned with the maintainer on 2026-11-03 from the audit, which found no SHA-256 block function rind runs is proven on any path. x86_64 SHA-NI moved to HACL*'s Vale `sha256_update` in [moq-dev/rind#328](https://github.com/moq-dev/rind/pull/328). A new HOL Light proof is research-level work, so check for upstream efforts before starting one.

Findings (2026-11-03):
- Nothing proven exists at full speed. s2n-bignum has no SHA-2 routine, but its [`arm/proofs/sha256.ml`](https://github.com/awslabs/s2n-bignum/blob/362689c4a347f5cc063db06983821819e6cdd2ce/arm/proofs/sha256.ml) models `sha256h`, `sha256h2`, `sha256su0`, and `sha256su1`, which its decoder and simulator already take. aws-lc-verification's SHA-256 proof is unwired, LNSym proves only SHA-512 and AES-GCM, and Vale has no aarch64 target.
- [awslabs/s2n-bignum#450](https://github.com/awslabs/s2n-bignum/pull/450) (draft, 2026-09-08) proves an x86_64 SHA-NI SHA-256 and adds a FIPS 180-4 spec, `sha256_spec.ml`, built on the Arm instruction model. [#415](https://github.com/awslabs/s2n-bignum/pull/415) does scalar x86_64 SHA-256. An aarch64 proof would reuse that spec.
- [pyca/verified-garbage#346](https://github.com/pyca/verified-garbage/pull/346) has a Lean-proven SHA-256 on the SHA-2 instructions, which its author reports 1.9x slower than OpenSSL's. That fails the 10% rule.
- aws-lc's routine is 123 instructions, 56 of them SHA-2 instructions, in a block loop: about 40% of #450's x86_64 routine. Its proof needs four-rounds-per-`sha256h`/`sha256h2`-pair and message-schedule lemmas, a load and byte-swap bridge, one loop invariant, and a constant-time proof: an estimated 3-5 person-weeks for someone fluent in s2n-bignum, 8-12 otherwise, about the size of the AES-XTS proofs.

Options, for the maintainer:
- Ask s2n-bignum whether an aarch64 counterpart to #450 is planned (days, then waiting on them). Recommended first.
- Write the proof against #450's spec and upstream it to s2n-bignum (3-5 person-weeks), if upstream won't take it on.
- Accept the gap and document it.

aarch64 without the crypto extension (aws-lc's `_nohw`) has the same gap and stays accepted unless the maintainer takes libcrux there (3-15% slower per the audit).
