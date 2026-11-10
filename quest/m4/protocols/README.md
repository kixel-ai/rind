# rind offers the building blocks modern protocols need

## Goal

rind offers the primitives that protocols above TLS build on, so their Rust implementations can run entirely on rind:

- HPKE's post-quantum KEMs, and MLS through rind-openmls, on top of `rind::hpke` (RFC 9180);
- RSA blind signatures (RFC 9474) and VOPRF/OPRF (RFC 9497), for Privacy Pass;
- FROST threshold Schnorr signatures (RFC 9591);
- ECVRF (RFC 9381);
- the PAKEs SPAKE2+ (RFC 9383, which Matter uses in a pre-RFC draft) and OPAQUE (RFC 9807).

## Plan

Decided with the maintainer on 2026-11-07, planning m4's long-term work with no token budget. Each block follows `AGENTS.md`'s rules: types that make misuse fail to compile, the RFCs' test vectors and Wycheproof where present, differential tests against an established implementation, and ctgrind for secret paths. aws-lc-rs implements none of these protocols, so the differential tests run against the Rust crate each protocol's consumers already use.

The scope ([moq-dev/rind#449](https://github.com/moq-dev/rind/pull/449)) ordered the blocks by reach and planned the primitives rind lacks (hash-to-curve, ristretto255 with a constant-time edwards25519 scalar multiplication, and Argon2id) as their own quests. Each protocol ships as a public rind module with its own misuse-resistant types, and the primitives under them stay crate-internal, rather than rind exposing scalar and point arithmetic for consumers' generic traits (`voprf::Group`, `frost_core::Ciphersuite`). Adapters for a consumer's crypto trait, such as openmls's `OpenMlsCrypto`, are separate `rind-<consumer>` quests, planned when one is wanted.

## Required

- [HPKE's post-quantum KEMs](/quest/m4/protocols/hpke-pq.md) - ML-KEM and X-Wing as HPKE KEMs
- [RSA blind signatures](/quest/m4/protocols/blind-rsa.md) - RFC 9474, for Privacy Pass's publicly verifiable tokens
- [Hash to the NIST curves](/quest/m4/protocols/hash-to-curve.md) - RFC 9380's SSWU hash-to-curve and `hash_to_field`, crate-internal
- [edwards25519 group and ristretto255](/quest/m4/protocols/ristretto255.md) - constant-time variable-base scalar multiplication and RFC 9496, crate-internal
- [OPRFs](/quest/m4/protocols/oprf.md) - RFC 9497's OPRF and VOPRF, for Privacy Pass's private tokens and OPAQUE
- [ECVRF](/quest/m4/protocols/ecvrf.md) - RFC 9381's TAI suites, for key transparency
- [FROST](/quest/m4/protocols/frost.md) - RFC 9591 threshold signatures on Ed25519, ristretto255, and P-256
- [SPAKE2+](/quest/m4/protocols/spake2plus.md) - RFC 9383 and Matter's commissioning on P-256
- [Argon2id](/quest/m4/protocols/argon2.md) - RFC 9106 password hashing, OPAQUE's key stretch
- [OPAQUE](/quest/m4/protocols/opaque.md) - RFC 9807's augmented PAKE
- [rind-openmls](/quest/m4/protocols/rind-openmls.md) - openmls's crypto provider on rind, after HPKE
