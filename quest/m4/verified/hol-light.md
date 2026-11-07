# [M] rind's own HOL Light proofs have a home that CI checks

## Goal

The HOL Light proofs this epic writes for routines s2n-bignum lacks (aws-lc's, OpenSSL's, and BoringSSL's assembly, and generalizations of s2n-bignum's own theorems) live in one place, pinned by commit, where CI checks them against the object code rind imports, so `proofs/`'s axioms can cite them as they cite s2n-bignum's while upstream review runs.

## Plan

- Open question for the maintainer: a `moq-dev/s2n-bignum` fork, one branch per proof, each offered upstream as a PR from the fork (recommended: upstream PRs come from it directly, and s2n-bignum's own build and proof scripts check it unchanged), or a `proofs/hol-light/` tree in rind run by `admin/prove`.
- The composition rule then reads "the published theorem at its pinned revision" as that home's commit until upstream merges it, and the axiom's docstring links both.
- Instruction-model additions (VAES, EVEX, IFMA, SHA-NI's x86 forms) are proofs too, and live there the same way.
- Unmerged upstream work rind builds on, such as [awslabs/s2n-bignum#415](https://github.com/awslabs/s2n-bignum/pull/415)'s FIPS 180-4 SHA-256 spec, [#420](https://github.com/awslabs/s2n-bignum/pull/420)'s SHA-512 spec, and [#450](https://github.com/awslabs/s2n-bignum/pull/450)'s SHA-NI model, is pinned there by commit, and followed when it merges.
