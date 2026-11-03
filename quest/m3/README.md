# m3: deferred

## Goal

Work that waits on something besides priority: an outside party, an upstream
release, or a consumer that does not exist yet.

## Plan

A quest gated on the outside world has a condition quest beside it, as the
[quest guide](https://github.com/kixelated/quest) describes: the condition
quest names how to check it and is deleted once it holds.

## Required

- [armv7 debug ctgrind, end of m2](/quest/m3/armv7-debug-ct.md) - recurring check that armv7 stays constant-time in debug builds
- [cargo-llvm-cov builds with its tests again](/quest/m3/cargo-llvm-cov-check.md) - waiting on a nixpkgs rustc fix, then drop the doCheck override
- [instant-acme 0.9 is released](/quest/m3/instant-acme-release.md) - waiting on the release with a pluggable `CryptoProvider`
- [Publish rind-instant-acme](/quest/m3/instant-acme-publish.md) - switch to the 0.9 release and publish
- [dimpl checks signatures for every provider](/quest/m3/dimpl-crypto-common.md) - waiting on a dimpl release, then rind-dimpl drops dimpl's internal feature
- [armv7 raw ciphers from libcrux](/quest/m3/libcrux-ciphers.md) - drop rind's copy once libcrux exports its AES
- [libcrux exports its raw ciphers](/quest/m3/libcrux-ciphers-exported.md) - waiting on a libcrux release that exports them
- [ring and aws-lc-rs parity](/quest/m3/parity/README.md) - switch from ring or aws-lc-rs to rind: algorithms, `rind-ring`, and rustls parity
