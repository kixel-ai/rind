# [M] rind-str0m

## Goal

A published `rind-str0m` crate implements
[str0m](https://github.com/algesten/str0m)'s `CryptoProvider` trait on rind,
so a str0m WebRTC user drops aws-lc-rs (its default) for a pure-Rust build,
without the slow RustCrypto path.

## Plan

- Decided with the maintainer on 2026-11-04: this reverses the 2026-10-31
  call that rind has no str0m adapter. That call held because MoQ vendors
  str0m and carries its own provider; str0m (2.9M downloads) is still the
  strongest Rust lead with a hook rind can fill without upstream changes.
- Build it on rind-dimpl for DTLS, with SRTP's AES-GCM and AES-CM on rind.
  MoQ's vendored provider is prior art; reuse what fits rather than diverging.
- Test against str0m's own test suite and an interop run against another
  provider, and benchmark SRTP against str0m's aws-lc-rs provider.
