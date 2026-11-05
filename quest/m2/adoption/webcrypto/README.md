# What WebCrypto adopters need

## Goal

rind offers every operation llrt's WebCrypto provider, pyrind's
pyca-compatible package, and the Dart `cryptography` backend need beyond what
rind has today, so none of them fills a gap with a second library: the
children below. MD5 and SHA-3 are here because llrt and Bun hash with them.

## Plan

Decided with the maintainer on 2026-11-04, in a planning interview:

- These were on the [aws-lc-rs extras](/quest/m3/parity/aws-lc-extras.md)
  on-demand list; the consumers above now ask for them, so they are planned
  in m2 ✅ / kept deferred in the m3 parity epic.
- MD5: added under a `legacy` module, as SHA-1 is ✅ / refused, leaving
  llrt on RustCrypto's md-5.
- Nothing here is added only for Deno or Servo (maintainer: Deno is
  deprecated); they use this set once it lands, and their SLH-DSA, Argon2,
  KMAC, KangarooTwelve, TurboSHAKE, AES-OCB, X448, and Ed448 stay on
  RustCrypto.
- Each child follows `AGENTS.md` for a new primitive (verified source where
  one exists, Wycheproof, differential tests against aws-lc-rs, ctgrind, a
  benchmark, every backend) and updates its `MIGRATING.md` rows.

## Required

- [AES-CBC](/quest/m2/adoption/webcrypto/aes-cbc.md) - AES-CBC with PKCS#7 padding
- [AES-GCM with any IV and tag length](/quest/m2/adoption/webcrypto/aes-gcm-params.md) - WebCrypto's IV lengths and truncated tags
- [AES-CTR with any counter length](/quest/m2/adoption/webcrypto/aes-ctr.md) - WebCrypto's 16-byte counter block and counter width
- [AES-192](/quest/m2/adoption/webcrypto/aes-192.md) - 192-bit keys for every AES mode
- [AES key wrap](/quest/m2/adoption/webcrypto/aes-kw.md) - RFC 3394 AES-KW
- [RSA-OAEP](/quest/m2/adoption/webcrypto/rsa-oaep.md) - RSA-OAEP encryption and decryption
- [RSA-PSS with any salt length](/quest/m2/adoption/webcrypto/rsa-pss-salt.md) - WebCrypto's `saltLength`
- [ECDSA over any curve and hash](/quest/m2/adoption/webcrypto/ecdsa-pairings.md) - signing with each curve and SHA-2 hash pairing
- [SHA-3](/quest/m2/adoption/webcrypto/sha3.md) - SHA3-256, SHA3-384, and SHA3-512 exported on every target
- [MD5](/quest/m2/adoption/webcrypto/md5.md) - legacy MD5 for hashing APIs that offer it
