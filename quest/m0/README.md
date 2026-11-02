# m0: immediate priorities

## Goal

The work that cannot wait: security advisories against rind or its
dependencies, a failing `main`, and anything that breaks MoQ on a published
rind release, and hosted CI that blocks every PR. Otherwise empty while
nothing is urgent.

## Required

- [x86_64 RSA signing never faults on a valid key](/quest/m0/rsa-sign-fault.md) - an intermittent wrong CRT signature caught by the self-check
