# [XL] rind as an OpenSSL 3 provider

## Goal

A `rind-openssl` crate builds a shared library that OpenSSL 3 loads as a
provider through `openssl.cnf`, offering the algorithms where rind is faster
than OpenSSL's default provider (on an i7-8700: Ed25519 and X25519 about 3-4x,
P-384 about 4x, and P-521), so a Node, Python, Ruby, or nginx deployment
gets them with no code change.

## Plan

Planned by the maintainer on 2026-11-04 in m4.

- OpenSSL's property queries pick the provider per algorithm at fetch time,
  set by configuration: that is a choice made at setup, not a runtime
  fallback, so the default provider keeps every algorithm rind does not
  register.
- Register only what measures faster, on `openssl speed` and on a Node and a
  Python workload, and keys must round-trip through OpenSSL's encoders and
  decoders so mixed use works.
- Pass OpenSSL's own test suite for each registered algorithm with the
  provider loaded, and keep the C ABI layer thin and fuzzed: it is rind's
  first C-facing surface.
