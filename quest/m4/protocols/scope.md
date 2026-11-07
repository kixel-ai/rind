# [S] Scope the protocol building blocks

## Goal

A report gives the maintainer, for each building block in the [epic](/quest/m4/protocols/README.md), the Rust crates and protocols that would use it (rustls's ECH, openmls, ohttp, privacypass, frost, and the Matter SDKs), the reference implementations to test against, and a proposed rind API. It plans a leaf quest for each, in order of reach.

## Plan

- HPKE first unless the report finds otherwise. rustls's ECH takes an HPKE implementation from the provider, so rind-rustls's parity with aws-lc-rs's provider depends on it. HPKE also composes with the [post-quantum epic](/quest/m4/pq/README.md)'s hybrid KEMs.
- Note which blocks need primitives rind lacks, such as ristretto255 or P-256 hash-to-curve (RFC 9380), and plan those as their own quests.
