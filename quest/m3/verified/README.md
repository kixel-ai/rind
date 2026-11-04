# Every computation rind runs is formally verified

## Goal

Every operation rind exports, on every path, runs code whose whole computation is covered by a published formal proof, so the benchmark report's strict ✓ appears on every rind cell. A gap that can't be closed is recorded with its reason.

## Plan

Decided with the maintainer on 2026-11-03, after the [benchmark report](/quest/m1/benchmarks/README.md) adopted its strict ✓ rule: a ✓ needs the whole computation proven, padding and protocol glue included.

- Scope: an m3 epic that starts with an audit ✅ / only the two known proofs / the same epic in m2.
- The audit ([moq-dev/rind#318](https://github.com/moq-dev/rind/pull/318)) lists what each path runs, what is proven, and the cheapest route to a proof for each gap. Plan quests from its report, starting with the most common operations.
- Rust proof tool (decided with the maintainer on 2026-11-04, from [moq-dev/rind#326](https://github.com/moq-dev/rind/pull/326)): Aeneas → Lean ✅ / hax → F*. Every proof of rind's Rust uses it under the composition rule below; a later quest does not reopen the choice.
- Rust that Aeneas cannot translate on a proven path (decided with the maintainer on 2026-11-04, for the agreement API's function-pointer dispatch): model it by hand ✅ / withdraw the ✓ until Aeneas translates it / keep the ✓ and list the gap. The model is retired once Aeneas translates function pointers.
- There are three routes, chosen per gap:
  - switch to an existing verified source (s2n-bignum, HACL*/libcrux, fiat-crypto), subject to the ~10% speed rule in `AGENTS.md`;
  - prove rind's own Rust with Aeneas to Lean, in `proofs/` (see its README), under the composition rule below;
  - accept the gap and document it.
- Composition rule: a proof of rind's Rust relies on an imported routine's published theorem only through one axiom per routine, in `proofs/Rind/<Arch>/`.
  - The axiom is about the opaque Rust wrapper around that routine, and states the theorem's postcondition over the wrapper's arguments and result as the Lean model reads them (`wordsNat` for HOL Light's `bignum_from_memory`), and nothing more. Its docstring names the theorem and links it at the pinned revision.
  - Each precondition of the theorem holds for every call safe Rust can make (no aliasing, the ABI's stack alignment), or becomes a hypothesis of the axiom.
  - A function the theorem's statement names, such as `rfcx25519`, is an `opaque` Lean constant whose docstring cites its definition; no proof assumes more about it.
  - Every other untranslated item is `opaque`, not an axiom. A fact a proof needs about one, such as rind's CPU checks passing, is a hypothesis of the theorem.
  - Rust on the path that Aeneas cannot translate, such as function-pointer dispatch, is modelled by hand in Lean definitions, never axioms. The model's file quotes the Rust it models, and `admin/prove` fails when the quote no longer matches the source.
  - `Axioms.lean` pins, with `#guard_msgs`, the axioms each top-level theorem rests on, so growing the trust base fails the build.
  - Trusted: each restatement, each hand model, the translation and Aeneas's models of `core`, and the transliteration, as for the other s2n-bignum entries.
- Audit summary (2026-11-03): under the strict rule no rind operation earned a ✓. X25519 on x86_64 and aarch64 now does, through `proofs/`.
  - Closest, where every core routine is proven and only rind's Rust glue is not: ChaCha20 header protection on x86_64 (HACL*'s rounds in a 45-line wrapper), Ed25519 on aarch64 and Intel x86_64 (encoding, clamping, small-order refusal, and SHA-512's padding), ML-KEM-768 on aarch64 (the FIPS 203 construction and SHA-3 sponge), AES-GCM on x86_64 with AVX and MOVBE but no VAES (HACL*'s Vale AES-GCM under rind's key expansion, H-power computation, and about 30 lines that copy the partial blocks and split the message), and P-256 on aarch64 (ECDH's byte conversion and point checks, which [aarch64 P-256 ECDH is proven end to end](/quest/m3/verified/p256-ecdh.md) proves, and the ECDSA glue; key generation is already proven end to end).
  - Unproven core code on common paths: every SHA-256 block function; x86_64 SHA-512 on AMD; AES-GCM's glue and in-place use on aarch64; every SIMD ChaCha20-Poly1305; x86_64 P-256 generator multiplication; RSA products off x86_64 ADX.
  - Glue to prove with a Rust tool: SHA padding, HMAC, HKDF, PBKDF2, the AEAD compositions, the ECDSA verification double multiplication, RSA's exponentiation and EMSA, ML-KEM's construction and sponge. The constant-time compare loops are inline asm, better proven in s2n-bignum's HOL Light.
  - Verified alternatives worth measuring: s2n-bignum's `edwards25519_encode` and its x86_64 `p256_scalarmul` for agreement, SymCrypt's Aeneas-verified ML-KEM and Formosa's mlkem-libjade.
  - armv7 without NEON keeps aws-lc's integer ChaCha20 and SHA-512 block function, which should be proven instead ([moq-dev/rind#327](https://github.com/moq-dev/rind/pull/327)). libcrux's HACL\* SHA-512 measured 6-7% slower at every size, and its AEAD 1-8% slower from 512 B; its compiled decrypt also checks the tag with early-exit branches, which rules it out with NEON too, where it seals 1.09-1.18x faster up to 64 B. The maintainer's rule (2026-11-03) keeps a verified switch only where it is at least as fast at every size.
  - Accepted unless a route changes it: AES and GHASH on x86_64 without AVX, aarch64 without the crypto extension, and armv7; VAES AES-GCM; SIMD ChaCha20-Poly1305; x86_64 P-256 generator multiplication (s2n-bignum's proven routine cost 12-17%); RSA off x86_64 ADX and key generation; armv7's curves; SHA-1; parsing for now.
  - aarch64 SHA-256 on the SHA-2 instructions (2026-11-03), until [awslabs/s2n-bignum#450](https://github.com/awslabs/s2n-bignum/pull/450) merges: nothing proven runs at full speed. s2n-bignum models the instructions but has no SHA-2 routine, and pyca/verified-garbage's Lean-proven one is 1.9x slower. Once #450's FIPS 180-4 spec lands, revisit a HOL Light proof of aws-lc's `sha256_block_data_order_hw` on it: 123 instructions, an estimated 3-5 person-weeks for someone fluent in s2n-bignum.
  - Randomness, including the HMAC-DRBG behind ECDSA's hedged nonces, is outside the functional spec: a proof shows the output is right for whatever was drawn.

## Required

- [SHA-512 padding is proven](/quest/m3/verified/sha512-padding.md) - rind's SHA-512 earns the ✓ its verified block function already has
- [aarch64 P-256 ECDH is proven end to end](/quest/m3/verified/p256-ecdh.md) - the Rust glue around s2n-bignum's proven multiplies
- [Ed25519 is proven end to end](/quest/m3/verified/ed25519.md) - s2n-bignum's encoder and proven glue
- [ChaCha20 header protection is proven](/quest/m3/verified/chacha-hp.md) - HACL*'s rounds and a proven wrapper
- [The hash and KDF glue is proven](/quest/m3/verified/hash-glue.md) - SHA padding, HMAC, HKDF, PBKDF2, and the constant-time compare
- [x86_64 SHA-NI SHA-256 block function is proven](/quest/m3/verified/sha256-block.md) - today's routine proven on s2n-bignum's SHA-256 spec, or a proven one as fast
- [x86_64 AES-GCM's Vale glue is proven](/quest/m3/verified/aes-gcm-vale.md) - the ✓ for the Vale AES-GCM that tier runs
