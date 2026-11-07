# [XS] rind-rustls offers SecP384r1MLKEM1024

## Goal

rind-rustls offers RFC 10024's `SecP384r1MLKEM1024` key exchange group (`0x11ED`), for TLS 1.3, beside its X25519MLKEM768 and SecP256r1MLKEM768.

## Plan

From [the scope](/quest/m4/pq/README.md), 2026-11-06.

- It's an RFC 10024 hybrid like the two rind-rustls already composes in `kx_group/hybrid.rs`: ECDH share first, then ML-KEM-1024, and an 80-byte secret.
- rustls 0.23.46 has no `NamedGroup` variant for it (only rustls `main` does), so name it `NamedGroup::Unknown(0x11ED)`; aws-lc-rs's provider doesn't offer it, so `aws_lc_rs_parity` lists it as rind-rustls's own addition. Keep it out of the default groups, as RFC 10024 marks it not recommended.
- Test it in `tests/pair.rs` against itself, and against rustls's own provider once one offers it.

## Required

- [ML-KEM-512 and ML-KEM-1024](/quest/m4/pq/ml-kem.md) - rind's ML-KEM-1024
