# Every computation rind runs is formally verified

## Goal

Every operation rind exports, on every path, runs code whose whole computation is covered by a published formal proof, so the benchmark report's strict ✓ appears on every rind cell. A gap that can't be closed is recorded with its reason.

## Plan

Decided with the maintainer on 2026-11-03, after the [benchmark report](/quest/m1/benchmarks/README.md) adopted its strict ✓ rule: a ✓ needs the whole computation proven, padding and protocol glue included.

- Scope: an m3 epic that starts with an audit ✅ / only the two known proofs / the same epic in m2.
- The audit ([moq-dev/rind#318](https://github.com/moq-dev/rind/pull/318)) lists what each path runs, what is proven, and the cheapest route to a proof for each gap. Plan quests from its report, starting with the most common operations.
- Rust proof tool (decided with the maintainer on 2026-11-04, from [moq-dev/rind#326](https://github.com/moq-dev/rind/pull/326)): Aeneas → Lean ✅ / hax → F*. Every proof of rind's Rust uses it under the composition rule below; a later quest does not reopen the choice.
- Rust that Aeneas cannot translate on a proven path (decided with the maintainer on 2026-11-04, for the agreement API's function-pointer dispatch): model it by hand ✅ / withdraw the ✓ until Aeneas translates it / keep the ✓ and list the gap. The model is retired once Aeneas translates function pointers.
- aarch64 P-256's ✓ with its generator table unproven (decided with the maintainer on 2026-11-04, from [moq-dev/rind#336](https://github.com/moq-dev/rind/pull/336)): keep the ✓ with the assumption stated in `benchmarks/verified.toml` ✅ / prove the table first. [The table's proof](/quest/m3/verified/p256-table-lean.md) retires it.
- aarch64 SHA-512 with the SHA-512 instructions (decided with the maintainer on 2026-11-04, from [moq-dev/rind#337](https://github.com/moq-dev/rind/pull/337)): strict for both ✅ / trust the store / leave as is. NSym's proof of aws-lc's routine for them leaves the digest in registers, and the store to the state is outside it, so neither rind nor aws-lc-rs earns the ✓ there.
- There are three routes, chosen per gap:
  - switch to an existing verified source (s2n-bignum, HACL*/libcrux, fiat-crypto), subject to the ~10% speed rule in `AGENTS.md`;
  - prove rind's own Rust with Aeneas to Lean, in `proofs/` (see its README), under the composition rule below;
  - accept the gap and document it.
- Composition rule: a proof of rind's Rust relies on an imported routine's published theorem only through one axiom per routine, in `proofs/Rind/<Arch>/`.
  - The axiom is about the opaque Rust wrapper around that routine, and states the theorem's postcondition over the wrapper's arguments and result as the Lean model reads them (`wordsNat` for HOL Light's `bignum_from_memory`), and nothing more. Its docstring names the theorem and links it at the pinned revision.
  - Each precondition of the theorem holds for every call safe Rust can make (no aliasing, the ABI's stack alignment), or becomes a hypothesis of the axiom.
  - A function the theorem's statement names, such as `rfcx25519`, is an `opaque` Lean constant whose docstring cites its definition; no proof assumes more about it.
  - A group-membership fact a proof must decide, such as a point being in `group_carrier p256_group`, may be stated as its defining equation, citing the pinned HOL Light theorem it follows from (`P256_GROUP`) (decided with the maintainer on 2026-11-04: amend the rule ✅ / a separate axiom / drop the ✓).
  - Every other untranslated item is `opaque`, not an axiom. A fact a proof needs about one, such as rind's CPU checks passing, is a hypothesis of the theorem.
  - Rust on the path that Aeneas cannot translate, such as function-pointer dispatch, is modelled by hand in Lean definitions, never axioms. The model's file quotes the Rust it models, and `admin/prove` fails when the quote no longer matches the source.
  - `Axioms.lean` pins, with `#guard_msgs`, the axioms each top-level theorem rests on, so growing the trust base fails the build.
  - Trusted: each restatement, each hand model, the translation and Aeneas's models of `core`, and the transliteration, as for the other s2n-bignum entries.
- Audit summary (2026-11-03): under the strict rule no rind operation earned a ✓. X25519 and ChaCha20 header protection on x86_64 and aarch64, P-256 ECDH on aarch64, and SHA-384/512 and Ed25519 on Intel x86_64 and on aarch64 without the SHA-512 instructions now do, through `proofs/`.
  - Closest, where every core routine is proven and only rind's Rust glue is not: ML-KEM-768 on aarch64 (the FIPS 203 construction and SHA-3 sponge), AES-GCM on x86_64 with AVX and MOVBE but no VAES (HACL*'s Vale AES-GCM under rind's key expansion, H-power computation, and about 30 lines that copy the partial blocks and split the message), and P-256 ECDSA on aarch64 (its signing and verification glue).
  - Unproven core code on common paths: every SHA-256 block function; x86_64 SHA-512 on AMD; the final store of aarch64's SHA-512 routine for the SHA-512 instructions, which NSym's proof stops short of; AES-GCM's glue and in-place use on aarch64; every SIMD ChaCha20-Poly1305; x86_64 P-256 generator multiplication; RSA products off x86_64 ADX.
  - Glue to prove with a Rust tool: the HMAC and digest APIs over SHA-1 and SHA-256 (their padding and HMAC's keyed states are proven), HKDF, PBKDF2, the AEAD compositions, the ECDSA verification double multiplication, RSA's exponentiation and EMSA, ML-KEM's construction and sponge. The constant-time compare loops are inline asm, better proven in s2n-bignum's HOL Light.
  - Verified alternatives worth measuring: s2n-bignum's `edwards25519_encode` and its x86_64 `p256_scalarmul` for agreement, SymCrypt's Aeneas-verified ML-KEM and Formosa's mlkem-libjade.
  - armv7 without NEON keeps aws-lc's integer ChaCha20 and SHA-512 block function, which should be proven instead ([moq-dev/rind#327](https://github.com/moq-dev/rind/pull/327)). libcrux's HACL\* SHA-512 measured 6-7% slower at every size, and its AEAD 1-8% slower from 512 B; its compiled decrypt also checks the tag with early-exit branches, which rules it out with NEON too, where it seals 1.09-1.18x faster up to 64 B. The maintainer's rule (2026-11-03) keeps a verified switch only where it is at least as fast at every size.
  - Accepted unless a route changes it: AES and GHASH on x86_64 without AVX, aarch64 without the crypto extension, and armv7; VAES AES-GCM; SIMD ChaCha20-Poly1305; x86_64 P-256 generator multiplication (s2n-bignum's proven routine cost 12-17%); RSA off x86_64 ADX and key generation; armv7's curves; SHA-1; parsing for now.
  - aarch64 SHA-256 on the SHA-2 instructions (2026-11-03), until [awslabs/s2n-bignum#450](https://github.com/awslabs/s2n-bignum/pull/450) merges: nothing proven runs at full speed. s2n-bignum models the instructions but has no SHA-2 routine, and pyca/verified-garbage's Lean-proven one is 1.9x slower. Once #450's FIPS 180-4 spec lands, revisit a HOL Light proof of aws-lc's `sha256_block_data_order_hw` on it: 123 instructions, an estimated 3-5 person-weeks for someone fluent in s2n-bignum.
  - Randomness, including the HMAC-DRBG behind ECDSA's hedged nonces, is outside the functional spec: a proof shows the output is right for whatever was drawn.

## Required

- [aarch64 P-256 ECDSA is proven end to end](/quest/m3/verified/p256-ecdsa.md) - sign's `s` and verify's twin multiplication, over s2n-bignum
- [The hash and KDF glue is proven](/quest/m3/verified/hash-glue.md) - the HMAC, HKDF, PBKDF2, and digest APIs over the proven SHA and HMAC core, and the constant-time compare
- [x86_64 SHA-NI SHA-256 block function is proven](/quest/m3/verified/sha256-block.md) - today's routine proven on s2n-bignum's SHA-256 spec, or a proven one as fast
- [x86_64 AES-GCM's Vale glue is proven](/quest/m3/verified/aes-gcm-vale.md) - the ✓ for the Vale AES-GCM that tier runs
- [rind's P-256 base-point table is proven in Lean](/quest/m3/verified/p256-table-lean.md) - retires the generator-table hypothesis of P-256's ✓
