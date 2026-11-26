# ChaCha20-Poly1305 is proven on aarch64

## Goal

ChaCha20-Poly1305 and XChaCha20-Poly1305 earn the ✓ on every aarch64 CPU, with and without SVE2 and the crypto extension, and `cipher::ChaCha20` earns it on every aarch64 CPU at the lengths its NEON code runs: below 128 bytes with SVE2, and without it below 192 bytes and from 257 to 447.

## Plan

- Done in [kixel-ai/rind#1077](https://github.com/kixel-ai/rind/pull/1077): `proofs/Rind/X86_64/ChaCha20Poly1305Api.lean`, which `admin/prove` copies to aarch64, proves the AEAD API (`aead::Key` for `CHACHA20_POLY1305`, and `RandomizedNonceKey`), the `mid` glue, and HChaCha20 over HACL*'s rounds down to the one pass, from `Seals` and `Opens`, that the one pass computes RFC 8439's AEAD at the message's length. `Rind/Aarch64/VgChaCha20Poly1305.lean` restates VG's theorems about `seal_framed` and `open_framed` at the NEON variant as axioms, as it did the SVE2 ones, and `Rind/Aarch64/ChaCha20Poly1305.lean` proves `Seals` and `Opens` at every length on SVE2 CPUs and, without SVE2, at the lengths VG's NEON routines run, so `benchmarks/verified.toml` gives the ✓ to every ChaCha20-Poly1305 and XChaCha20-Poly1305 row with SVE2 and the 1350 B and 16 KB rows without it. At the other lengths without SVE2 it proves them from `AwsLc`, aws-lc's NEON routines' contract.
- `cipher::ChaCha20` from 128 bytes with SVE2, and without it from 192 to 256 bytes and from 448, runs VG's routines ([kixel-ai/rind#882](https://github.com/kixel-ai/rind/pull/882)), which `proofs/Rind/Aarch64/VgChaCha20.lean` proves from axioms restating VG's theorems; its `chacha20_apply_keystream` takes the NEON code's contract at the other lengths as the hypothesis `Neon`.
- Split (agent's call on kixel-ai/rind#1077 with the maintainer away, as the x86_64 epic split on 2026-11-11): one child per remaining proof, aws-lc's one pass behind `AwsLc` and the NEON cipher behind `Neon`.
- Upstream: offering this work to awslabs/s2n-bignum is optional, and there is no standing approval: stop and ask the maintainer before posting there or anywhere outside [the orgs AGENTS.md lists](/AGENTS.md#development) (decided with the maintainer on 2026-11-07 on [kixel-ai/rind#448](https://github.com/kixel-ai/rind/pull/448)).
