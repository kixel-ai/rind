# [S] rind-rustls supports rustls 0.24

## Goal

A published rind-rustls release supports rustls 0.24 soon after it ships, so
users choosing a provider for the first time can pick rind-rustls.

## Plan

Follow the provider API's changes from 0.23, and keep rind-rustls's
`aws_lc_rs_parity` test against `rustls-aws-lc-rs`, which 0.24 splits out.
Whether to also keep 0.23 support is the maintainer's call at the time;
ask with the cost of each. The port ships as rind-rustls 0.24.x, since
adapter versions match their upstream
([CONTRIBUTING.md](/CONTRIBUTING.md#releases)), so keeping 0.23
means a 0.23.x maintenance line.

rustls-graviola, which rind-rustls began as, has a port to rustls
0.24.0-dev.3 on ctz/graviola's `jbp-0.24-send-prototype` branch
(`349fa152` to `a3f8fa33`, 2026-11-13 to 11-16) that also seals AES-GCM
out of place, avoiding a copy and a memset; read it first.

## Required

- [rustls 0.24 is released](/quest/m2/adoption/rustls-0.24-release.md) - the release this ports to
