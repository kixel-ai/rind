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
