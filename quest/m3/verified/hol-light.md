# [M] rind's own HOL Light proofs live in proofs/hol-light

## Goal

The HOL Light proofs rind writes for routines s2n-bignum lacks (aws-lc's, OpenSSL's, and BoringSSL's assembly, generalizations of s2n-bignum's own theorems, and additions to its instruction models) live in `proofs/hol-light/` in rind. `admin/prove` checks them beside the Lean proofs, against the object code rind imports, so `proofs/`'s axioms cite them as they cite s2n-bignum's.

## Plan

Moved from m4 into m3 with the maintainer on 2026-11-07: [the hash-glue quest](/quest/m3/verified/hash-glue.md)'s constant-time compares are its first consumer, so the tree starts there.

Decided with the maintainer on 2026-11-07 on [moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448): an in-repo tree run by `admin/prove`, not a `moq-dev/s2n-bignum` fork.

- s2n-bignum's model, tactics, and specs come in pinned, as a Nix input or submodule at a recorded commit, or vendored if pinning cannot build. Either way the pin is one recorded revision that the proofs and `benchmarks/verified.toml` name.
- `admin/prove` runs HOL Light on `proofs/hol-light/` in the `prove` workflow's nightly run, and on pull requests that change those files or the assembly they cover. A theorem's object code is the routine's bytes as rind's build emits them, where that can be extracted, so these proofs need no transliteration step. Keep this consistent with [asm-bytes](/quest/m3/verified/asm-bytes.md)'s check.
- The composition rule's "published theorem at its pinned revision" is, for these proofs, the file in `proofs/hol-light/` at rind's commit. Each axiom's docstring links it.
- Unmerged upstream work rind builds on is pinned by its PR's commit, and moved to the merged version when it lands; the ✓ that rests on it notes the pin (decided the same day). This covers [awslabs/s2n-bignum#415](https://github.com/awslabs/s2n-bignum/pull/415)'s FIPS 180-4 SHA-256 spec, [#420](https://github.com/awslabs/s2n-bignum/pull/420)'s SHA-512 spec, and [#450](https://github.com/awslabs/s2n-bignum/pull/450)'s SHA-NI model.
- Offering a proof upstream is optional, and there is no standing approval: stop and ask the maintainer before posting to awslabs/s2n-bignum or anywhere outside the moq-dev and kixelated orgs.
- Deliver the tree with one small proof that exercises it end to end, such as a routine rind already imports from s2n-bignum re-checked from the pin.
