# [S] rind-rustls adds little to a binary

## Goal

A program that switches its rustls provider to rind-rustls grows by no more than it would with aws-lc-rs's or ring's provider, and pays for P-384 and P-521 only if it negotiates them.

## Plan

The [migration prompt](https://github.com/moq-dev/rind/pull/357)'s trial grew rustypaste by 3.4 MB on rind 0.1.12, which inlined assembly into its callers; [#315](https://github.com/moq-dev/rind/pull/315) stopped that in 0.1.13. On `main`, rustypaste grows by 0.97 MB over ring's provider (both with TLS 1.2) and stays 1.20 MB under aws-lc-rs's ([#375](https://github.com/moq-dev/rind/pull/375) has the measurements).

What remains is s2n-bignum's unrolled assembly, the price of rind's speed: P-384 and P-521 cost 271 KB each on x86_64 and about 150 KB each on aarch64, and nothing smaller remains to trim without slowing rind or changing what it accepts. P-384 stays: Web PKI chains sign with it. Drop P-521 from `default_provider` only if the maintainer agrees; its statics stay for anyone who builds a provider with them.

## Waiting

- Maintainer: whether `default_provider` keeps aws-lc-rs's algorithm list or drops P-521 verification and key loading as ring's does (-271 KB on x86_64, -159 KB on aarch64), recommended; answer on [#375](https://github.com/moq-dev/rind/pull/375)
