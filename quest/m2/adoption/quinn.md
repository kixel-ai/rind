# [M] quinn's rustls support works with any provider

## Goal

quinn-proto's `rustls` feature works with any rustls `CryptoProvider`,
including rind-rustls, without pulling ring or aws-lc-rs, in a merged upstream
PR closing [quinn-rs/quinn#2341](https://github.com/quinn-rs/quinn/issues/2341).

## Plan

- quinn-proto has 407M downloads and sits under reqwest's HTTP/3, hickory's
  QUIC, and libp2p's QUIC, so this reaches more rind users than any adapter.
- quinn's maintainers declined to name young providers
  ([quinn-rs/quinn#2253](https://github.com/quinn-rs/quinn/issues/2253)), so
  the PR is provider-neutral and never mentions rind as its reason: today the
  feature forces one provider, and quinn calls ring directly for HMAC and HKDF
  (token and reset keys). Those should come from the configured provider or
  trait objects the user supplies.
- ctz has a work-in-progress branch for #2341; build on it or coordinate with
  its author before starting a competing one.
