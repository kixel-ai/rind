# m3: deferred

## Goal

Work deferred by priority or waiting on an outside party, an upstream release,
or a consumer that does not exist yet.

## Plan

A quest gated on the outside world has a condition quest beside it, as the
[quest guide](https://github.com/kixelated/quest) describes: the condition
quest names how to check it and is deleted once it holds.

## Required

- [armv7 debug ctgrind, end of m2](/quest/m3/armv7-debug-ct.md) - recurring check that armv7 stays constant-time in debug builds
- [cargo-llvm-cov builds with its tests again](/quest/m3/cargo-llvm-cov-check.md) - waiting on a nixpkgs rustc fix, then drop the doCheck override
- [dimpl checks signatures for every provider](/quest/m3/dimpl-crypto-common.md) - waiting on a dimpl release, then rind-dimpl drops dimpl's internal feature
- [armv7 raw ciphers from libcrux](/quest/m3/libcrux-ciphers.md) - drop rind's copy once libcrux exports its AES
- [libcrux exports its raw ciphers](/quest/m3/libcrux-ciphers-exported.md) - waiting on a libcrux release that exports them
- [ring and aws-lc-rs parity](/quest/m3/parity/README.md) - switch from ring or aws-lc-rs to rind: algorithms, `rind-ring`, and rustls parity
- [The cold tiers are fast](/quest/m3/cold-speed/README.md) - 64-bit limbs and in-place AES-GCM on the portable backend, and the fastest SHA on armv7 without crypto
- [Benchmark report refresh, end of m2](/quest/m3/bench-report-refresh.md) - recurring rerun of the report on every host
- [Every computation rind runs is formally verified](/quest/m3/verified/README.md) - the settled proof rules, and the proofs still planned here
- [Every primitive is tested as thoroughly as the best libraries test theirs](/quest/m3/confidence/README.md) - the four quests claimed before the epic moved to m2, finishing from here
- [s2n-bignum's SHA-256 spec has merged](/quest/m3/s2n-bignum-sha2-spec.md) - waiting on awslabs/s2n-bignum#450
