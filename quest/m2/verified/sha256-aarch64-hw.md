# [L] aarch64 SHA-256 on the SHA-2 instructions is proven

## Goal

SHA-256, and HMAC, HKDF, and PBKDF2 over it, earn the ✓ on aarch64 with the crypto extension, the hash under every TLS 1.3 handshake's transcript and key schedule there. Its PR also reports what the proof cost and how an SMT-backed route compares on the same routine, the measurement every later proof of unproven assembly is sized from.

## Plan

Staging (maintainer, 2026-11-09): ✅ calibrate first, and move the cold tiers to m5 (rejected: calibrate only, leave the 2026-11-07 plan). This is the calibration: the first HOL Light proof rind writes for assembly nobody has proven, picked because it is the smallest such routine on a hot path. Every other quest that writes one requires it.

- Runs: aws-lc's `sha256_block_data_order_hw` (`low/aarch64/aws_lc/sha256_block_data_order_hw.*.s`, 123 instructions), under the padding, HMAC, HKDF, and PBKDF2 glue `proofs/` proves. It keeps a register copy off each round's dependency chain, where LLVM's code for rind's intrinsics puts one on it, so it is faster than those intrinsics. pyca's Lean-proven routine is 1.9x slower.
- Already proven: nothing. s2n-bignum models `sha256h`, `sha256h2`, `sha256su0`, and `sha256su1` but has no SHA-256 routine.
- Route: a HOL Light proof of the routine in s2n-bignum's aarch64 model against [awslabs/s2n-bignum#415](https://github.com/awslabs/s2n-bignum/pull/415)'s FIPS 180-4 SHA-256 spec, which [#450](https://github.com/awslabs/s2n-bignum/pull/450)'s x86_64 proof also uses, estimated at 3-5 person-weeks for someone fluent in s2n-bignum. It then enters `proofs/Rind/Aarch64/ShaBlocks.lean` as an axiom, retiring that hypothesis's SHA-256 half on this tier.
- Spec pin: build on [awslabs/s2n-bignum#415](https://github.com/awslabs/s2n-bignum/pull/415)'s spec at a pinned commit while it is unmerged, and move to the merged version when it lands; `benchmarks/verified.toml`'s ✓ notes the pin (decided with the maintainer on 2026-11-07 on [moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448)). Both PRs keep the spec in `x86/proofs/utils/sha256_spec.ml`, so an aarch64 proof loads it from the x86 tree. On 2026-11-09 both were drafts, #415 untouched since 2026-06-23 and #450 since 2026-09-08.
- How the pin comes in: consider vendoring s2n-bignum (maintainer, 2026-11-09). It is a submodule at one upstream commit today (`thirdparty/s2n-bignum`). A draft PR's commit can vanish on a force-push, and one submodule commit cannot hold #415, #420, and #450 at once without a fork, which the 2026-11-07 decision rejected. Recommended: keep the submodule for merged upstream, and vendor only the unmerged spec and proof files into `proofs/hol-light/`, each with its source PR and commit recorded; vendor the whole tree only if that cannot build. This quest is the first to build on a pin, so it settles the question for [the x86_64 SHA-256 proof](/quest/m3/verified/sha256-block.md) and the rest.
- Upstream: offering this work to awslabs/s2n-bignum is optional, and there is no standing approval: stop and ask the maintainer before posting there or anywhere outside the moq-dev and kixelated orgs (decided with the maintainer on 2026-11-07 on [moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448)).

The measurement, in the PR's body:

- The cost of the HOL Light proof: its lines, split into the proof, its lemmas, and any addition to the instruction model; the agent sessions and wall time it took; the time `admin/prove` takes to check it, against the `prove` workflow's 60 minutes (`.github/workflows/prove.yml:30`); and each place it stalled, with what moved it on.
- The same figures for the Lean side: restating the theorem as an axiom, and bridging s2n-bignum's SHA-256 spec to `Rind/HashSpec.lean`'s.
- For scale, upstream's own proofs, neither merged: #450 proves its SHA-NI routine, a 299-line source file, in 13,570 lines of HOL Light, and #415 its scalar one, 1,429 lines, in 12,830.
- A second route on the same routine: prove it by symbolic execution with an SMT solver or a bit-vector decision procedure, such as SAW, which aws-lc-verification's SHA-512 proof that `proofs/Rind/X86_64/AwsLc.lean` restates used, or Lean's `bv_decide` over a small model of the instructions the routine runs. Report its cost in the same figures, what it trusts that the HOL Light proof does not (the solver, its instruction model, how its theorem would enter under the composition rule), and where it stopped if it did not finish.
- From both, a proposed size for each quest that requires this one, given its routine's instruction count and whether it loops, branches, or needs instructions the model lacks. Which route those quests take stays HOL Light in `proofs/hol-light/` unless the maintainer picks otherwise from this report; the ✓ here rests on the HOL Light proof.

## Required

- [rind's own HOL Light proofs live in proofs/hol-light](/quest/m3/verified/hol-light.md) - where the HOL Light proofs live and CI checks them
