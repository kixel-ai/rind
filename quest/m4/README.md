# m4: long-term

## Goal

Work that takes rind beyond Rust consumers into the C ecosystem and
regulated deployments (an OpenSSL provider and FIPS 140-3), and the long-term
work of a complete, fully verified library: post-quantum and protocol
building blocks, every path proven, and continuous testing (maintainer,
2026-11-07). Planned, but
after m2's adoption work and its own scoping.

## Plan

Created by the maintainer on 2026-11-04, reversing the parity epic's
2026-10-30 call that FIPS validation and anything exposing C were out of
reach: Node, Python, Ruby, and nginx all run on OpenSSL 3, and a provider is
the one route by which rind's faster ECC reaches them unchanged.

## Required

- [rind as an OpenSSL 3 provider](/quest/m4/openssl-provider.md) - OpenSSL loads rind's faster algorithms through `openssl.cnf`
- [Scope FIPS 140-3 validation](/quest/m4/fips-scope.md) - what validating rind would take, for the maintainer to decide
- [rind covers the standardized post-quantum algorithms](/quest/m4/pq/README.md) - SLH-DSA, the hybrid KEMs, and later FN-DSA and HQC
- [rind offers the building blocks modern protocols need](/quest/m4/protocols/README.md) - HPKE, blind RSA, VOPRF, FROST, ECVRF, and PAKEs
- [Every rind path is proven, with the smallest trust base](/quest/m4/verified/README.md) - the gaps m3 accepted, closed on every hot tier
- [rind runs in OSS-Fuzz](/quest/m4/oss-fuzz.md) - the fuzz crate's targets fuzzed continuously
