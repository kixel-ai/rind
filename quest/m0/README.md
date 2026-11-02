# m0: immediate priorities

## Goal

The work that cannot wait: security advisories against rind or its
dependencies, a failing `main`, and anything that breaks MoQ on a published
rind release, and hosted CI that blocks every PR. Otherwise empty while
nothing is urgent.

## Required

- [x86_64 RSA exponentiation is constant time in debug builds](/quest/m0/mont-exp-debug-ct.md) - debug ctgrind is red on main since #224
