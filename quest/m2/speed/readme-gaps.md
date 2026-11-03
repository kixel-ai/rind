# [XS] README's Algorithms table shows current numbers and the reason for each accepted gap

## Goal

Every cell in README's Algorithms table comes from a nightly run after [moq-dev/rind#271](https://github.com/moq-dev/rind/pull/271), [#274](https://github.com/moq-dev/rind/pull/274), [#263](https://github.com/moq-dev/rind/pull/263), and [#254](https://github.com/moq-dev/rind/pull/254), and every gap left without a quest is bolded with its reason.

## Plan

Planned with the maintainer on 2026-11-03 from the speed-gap audit. Most bold cells are stale (armv7 RSA, rustls handshakes, and ChaCha20-Poly1305; aarch64 AES block and AES-CTR) or noise (1.01-1.04). Record these accepted gaps, re-measuring each:

- x86_64 RSA at widths that aren't a multiple of eight words (RSA-2056 and 2560) gathers with s2n-bignum's verified `bignum_copy_row_from_table`, not aws-lc's `bn_mul_mont_gather5`, as decided in [moq-dev/rind#224](https://github.com/moq-dev/rind/pull/224).
- P-256 verification without ADX or AVX2 runs s2n-bignum's verified routines, 3-5% behind aws-lc's `ecp_nistz256`, within the 10% rind accepts for verified code.
- aarch64 AES-128-GCM sealing 32 B trails ring by 4-5 ns; opening and larger sizes lead.
- x86_64 ChaCha20-Poly1305 without SSE4.1 (the no-AES-NI and SSE2 tiers) trails because aws-lc's Poly1305 is BoringSSL's SSE2 `poly1305_vec.c` and rind's is Graviola's scalar one; the maintainer chose not to port it for pre-Westmere CPUs.
