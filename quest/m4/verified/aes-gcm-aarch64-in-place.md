# [M] aarch64's AES-GCM kernels are proven in place

## Goal

s2n-bignum's aarch64 AES-GCM kernels, which rind runs with the same input and output buffer, are proven for that use, so rind's in-place AES-GCM rests on a theorem instead of `admin/parse-asm/inplace.py`'s check of every length up to 64 blocks.

## Plan

- Runs: `aes{128,256}_gcm_{enc,dec}` by 4, and their `_alt` forms by 8 on cores with the SHA3 instructions, transliterated into `low/aarch64/aes{128,256}_gcm_{enc,dec}{,_alt}.rs`.
- Already proven: each kernel, CORRECT and SAFE, against SP 800-38D's GCM (`common/gcm.ml`), for whole blocks, by [awslabs/s2n-bignum#470](https://github.com/awslabs/s2n-bignum/pull/470), [#445](https://github.com/awslabs/s2n-bignum/pull/445), [#440](https://github.com/awslabs/s2n-bignum/pull/440), [#482](https://github.com/awslabs/s2n-bignum/pull/482), and [#485](https://github.com/awslabs/s2n-bignum/pull/485). Every theorem requires `nonoverlapping` input and output, and no upstream PR or issue addresses aliasing.
- Route: generalize each theorem to `in_p = out_p` in HOL Light, since each block is loaded before its output is stored. An out-of-place call is no route unless its copy measures free.
- Retire `inplace.py` once the theorems cover in-place use.
- Upstream: offering this work to awslabs/s2n-bignum is optional, and there is no standing approval: stop and ask the maintainer before posting there or anywhere outside the moq-dev and kixelated orgs (decided with the maintainer on 2026-11-07 on [moq-dev/rind#448](https://github.com/moq-dev/rind/pull/448)).

## Required

- [rind's own HOL Light proofs live in proofs/hol-light](/quest/m3/verified/hol-light.md) - where the HOL Light proofs live and CI checks them
