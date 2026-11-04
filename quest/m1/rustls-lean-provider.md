# [S] rind-rustls lets a caller build a lean provider

## Goal

A rustls user can build a provider from only the rind algorithms it needs (cipher suites, key-exchange groups, signature verification, and signing key types), so a client that needs one TLS 1.3 suite, X25519, and ECDSA P-256 links only those, about 1.8 MB stripped against 1.94 MB on ring's full provider.

## Plan

Planned with the maintainer on 2026-11-03 from [moq-dev/rind#315](https://github.com/moq-dev/rind/pull/315). After it, rustls on rind-rustls is 2.86 MB because the default provider offers every scheme, and `load_private_key` accepts any key type, so every signing curve links. A trimmed provider measured 1.77 MB.

- Export rind-rustls's signature-verification algorithms and offer a key provider per algorithm (or per family), alongside the full default provider. This is a public API addition; put the shape (names, granularity, how it mirrors rustls's and aws-lc-rs's provider modules) to the maintainer as decision prompts in the PR.
- Add a build-cost fixture for the lean provider, so the report shows it.
