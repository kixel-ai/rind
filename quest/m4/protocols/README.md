# rind offers the building blocks modern protocols need

## Goal

rind offers the primitives that protocols above TLS build on, so their Rust implementations can run entirely on rind:

- HPKE (RFC 9180), for ECH, MLS, and Oblivious HTTP, including through rind-rustls's ECH support;
- RSA blind signatures (RFC 9474) and VOPRF/OPRF (RFC 9497), for Privacy Pass;
- FROST threshold Schnorr signatures (RFC 9591);
- ECVRF (RFC 9381);
- the PAKEs SPAKE2+ (RFC 9383, used by Matter) and OPAQUE (RFC 9807).

## Plan

Decided with the maintainer on 2026-11-07, planning m4's long-term work with no token budget. Start with the scope below, which recommends one leaf quest per building block from what it finds. Each follows `AGENTS.md`'s rules: types that make misuse fail to compile, the RFCs' test vectors and Wycheproof where present, differential tests against an established implementation, and ctgrind for secret paths.

## Required

- [Scope the protocol building blocks](/quest/m4/protocols/scope.md) - which consumers want each, the API, and an order
