# [XS] rustls lists rind-rustls

## Goal

rustls's [PROVIDERS.md](https://github.com/rustls/rustls/blob/main/PROVIDERS.md)
lists rind-rustls among its third-party providers, in a merged upstream PR.

## Plan

From rustls 0.24, every rustls user picks a provider explicitly
([rustls/rustls#2395](https://github.com/rustls/rustls/issues/2395)), so the
list is where they look. Describe it the way the list describes others: pure
Rust, its targets, and its algorithm coverage against aws-lc-rs's provider.
