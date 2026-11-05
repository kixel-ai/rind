# [M] Lemmy's federation signs and verifies with rind

## Goal

A PR to [activitypub-federation-rust](https://github.com/LemmyNet/activitypub-federation-rust),
the crate under Lemmy and other Rust ActivityPub servers, moves its HTTP
signatures from the `rsa` crate to rind, with numbers: every federated
request is signed once per destination and verified on arrival, and every
new user or community generates an RSA-2048 key.

## Plan

Decided with the maintainer on 2026-11-04, in a planning interview.

- Lemmy left OpenSSL for the `rsa` crate for portability
  ([LemmyNet/lemmy#4900](https://github.com/LemmyNet/lemmy/issues/4900));
  rind keeps the portability, and drops RUSTSEC-2023-0071 with it.
- [BENCHMARKS.md](/BENCHMARKS.md)'s `nixos2` (an i7-8700) has rind verifying
  RSA-2048 about 4.7x and signing about 2x faster than `rsa` 0.10; measure against the 0.9 they use. RSA signing
  gains more once [RSA-2048 speed](/quest/m2/speed/x86-rsa2048-sign.md) lands, but
  need not wait for it.
- Keys are stored as PEM (PKCS#8 and SPKI); existing keys must load
  unchanged.
- Posting is the maintainer's call; prepare the branch and text, then ask.
