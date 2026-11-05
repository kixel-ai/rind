# [S] rind-rustls supports rustls 0.24

## Goal

A published rind-rustls release supports rustls 0.24 soon after it ships, so
users choosing a provider for the first time can pick rind-rustls.

## Plan

Follow the provider API's changes from 0.23, and keep rind-rustls's
`aws_lc_rs_parity` test against `rustls-aws-lc-rs`, which 0.24 splits out.
Whether to also keep 0.23 support is the maintainer's call at the time;
ask with the cost of each.

## Required

- [rustls 0.24 is released](/quest/m2/adoption/rustls-0.24-release.md) - the release this ports to
