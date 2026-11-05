# [M] rind-rustls adds little to a binary

## Goal

A program that switches its rustls provider to rind-rustls grows by no more than it would with aws-lc-rs's or ring's provider, and pays for P-384 and P-521 only if it negotiates them.

## Plan

Found on 2026-11-05 by the [migration prompt](https://github.com/moq-dev/rind/pull/357)'s trial: rind-rustls's default provider added 3.4 MB to rustypaste's stripped binary, 30% of it, mostly P-384 and P-521 code. Measure what each algorithm costs, then pick: dropping the larger curves from the default provider, sharing code between curves, or trimming per-CPU dispatch that links every tier. Keep the default provider's algorithm list as aws-lc-rs's unless the maintainer agrees otherwise. Report sizes against aws-lc-rs and ring on x86_64 and aarch64.
