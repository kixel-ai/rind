# Every computation rind runs is formally verified

## Goal

Every operation rind exports, on every path, runs code whose whole computation is covered by a published formal proof, so the benchmark report's strict ✓ appears on every rind cell. A gap that can't be closed is recorded with its reason.

## Plan

Decided with the maintainer on 2026-11-03, after the [benchmark report](/quest/m1/benchmarks/README.md) adopted its strict ✓ rule: a ✓ needs the whole computation proven, padding and protocol glue included.

- Scope: an m3 epic that starts with an audit ✅ / only the two known proofs / the same epic in m2.
- The [audit](/quest/m3/verified/audit.md) lists what each path runs, what is proven, and the cheapest route to a proof for each gap. You plan quests from its report, starting with the most common operations.
- There are three routes, chosen per gap:
  - switch to an existing verified source (s2n-bignum, HACL*/libcrux, fiat-crypto), subject to the ~10% speed rule in `AGENTS.md`;
  - prove rind's own Rust, for example with hax to F* or with Aeneas;
  - accept the gap and document it.
- Known unproven parts today: the glue around verified cores (SHA padding, HMAC, HKDF, AEAD composition, the ECDSA and RSA protocol layers, P-256 ECDH's Jacobian-to-affine conversion, DER parsing) and the unverified imported assembly (aws-lc's AES-GCM, ChaCha20, P-256 generator multiplication, and RSAZ; mlkem-native's ML-KEM; OpenSSL's Keccak).

## Required

- [Verification audit](/quest/m3/verified/audit.md) - what is and isn't proven on every path, with a recommended route per gap
- [SHA-512 padding is proven](/quest/m3/verified/sha512-padding.md) - rind's SHA-512 earns the ✓ its verified block function already has
- [aarch64 P-256 ECDH is proven end to end](/quest/m3/verified/p256-ecdh.md) - agreement runs s2n-bignum's proven affine-to-affine multiply
