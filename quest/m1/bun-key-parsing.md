# [M] Bun parses its moved keys with rind

## Goal

Bun imports and exports the keys of the operations it moves to rind (Ed25519, X25519, and P-256, P-384, and P-521 ECDSA and ECDH) through rind's parsers rather than BoringSSL's, in the raw, PKCS#8, SPKI, and JWK forms node:crypto and WebCrypto use, byte for byte as Bun does today.

## Plan

The Bun prototype ([moq-dev/rind#368](https://github.com/moq-dev/rind/pull/368)) found that Bun's P-384 key import alone takes 670 µs, more than a signature, because it still goes through BoringSSL's `EVP_PKEY`. The maintainer decided on 2026-11-05 that the first Bun PR waits for this.

- Find which formats rind already parses and exports for each key type, and add only what is missing. Additions only, so they can ship in a patch release.
- JWK is JSON, so it likely stays in Bun, on rind's raw forms.
- Treat every encoding as hostile. Test against Wycheproof where it has vectors, and against aws-lc-rs.
- Measure Bun's import and export against BoringSSL through the `bun-bench/harness` branch.
