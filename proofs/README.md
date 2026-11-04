# Proofs of rind's Rust

Lean proofs that rind's own Rust computes its specified result, composed with
the published proofs of the routines it imports, so that an operation's whole
computation is proven. [Charon](https://github.com/AeneasVerif/charon) and
[Aeneas](https://github.com/AeneasVerif/aeneas) translate the Rust to Lean, and
the theorems are about that translation.

`nix develop .#prove --command admin/prove` translates the Rust and checks
every proof against the translation. The `prove` workflow runs it nightly and
on pull requests that change rind's source or these files.

## What is proven

X25519 on x86_64 and aarch64, from the agreement API's `PrivateKey` to
s2n-bignum's routines, in `Rind/X86_64/X25519.lean`, which `admin/prove` also
writes for aarch64:

- `x25519_generate`: the key's scalar is the 32 drawn bytes, read
  little-endian, and a failed draw is refused;
- `x25519_public_key`: the public key is the 32 little-endian bytes of
  `rfcx25519(scalar, 9)`;
- `x25519_agree`: a peer key that is not 32 bytes is refused, so is an
  all-zero result, and otherwise the secret is the 32 little-endian bytes of
  `rfcx25519(scalar, u)`, for the peer's bytes `u` read little-endian;
- `x25519_shared_secret`: the secret's bytes are those.

`rfcx25519` is HOL Light's RFC 7748 X25519, clamping and masking included.
Each theorem assumes `Runs`: rind's CPU-feature checks pass, which no input
affects. `Rind/<Arch>/Axioms.lean` checks the axioms each theorem rests on.

SHA-1 and SHA-256's padding and finalization, and HMAC's keyed states over
any hash, on x86_64 and aarch64, in `Rind/X86_64/{Blockwise,Sha,Hmac}.lean`,
against FIPS 180-4 and RFC 2104 as `Rind/HashSpec.lean` transliterates them:

- `sha256_hash`, `sha1_hash`: a message's digest, one-shot, and
  `sha256_hashSpec`, `sha1_hashSpec`: every method of each `Hash` impl,
  streaming included;
- `hmac_key_new_spec`, `hmac_sign_spec`, `hmac_start_spec`,
  `hmac_update_spec`, `hmac_finish_spec`: `HmacKey` and `Hmac` over any hash
  meeting `HashSpec`, and `hmac_sha256_sign`, `hmac_sha1_sign` over SHA-256
  and SHA-1.

No proof covers a SHA-1 or SHA-256 block function rind runs on either target,
so these theorems take `ShaBlocks` as a hypothesis, in each target's own
`Rind/<Arch>/ShaBlocks.lean`: each routine computes FIPS 180-4's block
function, and rind's checks pass. They add no axiom, which
`Rind/<Arch>/HashAxioms.lean` checks. An input is at most `maxInput`
(2^61 - 1) bytes, under FIPS 180-4's 2^64-bit limit. `Rind/HashSpecTest.lean`
checks the transliterations against FIPS 180-4's, RFC 4231's, RFC 5869's, and
RFC 6070's vectors.

`PrivateKey` reaches each curve's `Agree` impl through function pointers
(`Algorithm`'s `generate` and `Keyed`'s `Ops`), which Aeneas cannot translate.
`Rind/X86_64/Dispatch.lean` models that dispatch by hand, in Lean definitions
beside the Rust they model. `admin/prove` fails if that quote no longer
matches the source, or if the source names `Ops` outside it. `high::digest`
holds function pointers too, so `Rind/X86_64/Digest.lean` models its
`Algorithm` and `Digest` by hand, the same way.

## Layout

- `Rind/<Arch>/{Types,Funs}.lean`: Aeneas's translation, which `admin/prove`
  writes and git ignores.
- `Rind/<Arch>/{Types,Funs}External.lean` and `Rind/Core.lean`: what the
  translation leaves opaque, and models of the few `core` items Aeneas's
  library lacks.
- `Rind/<Arch>/S2nBignum.lean`: s2n-bignum's theorems, restated as axioms
  about the routines' Rust wrappers.
- `Rind/Spec.lean` and `Rind/Bytes.lean`: the spec and byte-conversion
  lemmas.
- `Rind/HashSpec.lean`: SHA-1, SHA-256, HMAC, HKDF, and PBKDF2, and
  `Rind/HashSpecTest.lean`, their known-answer tests.
- `Rind/X86_64/Dispatch.lean`: the hand model of the agreement API's
  dispatch, and `Rind/X86_64/Digest.lean`, of `high::digest`.
- `Rind/X86_64/X25519.lean`: the X25519 proof, and
  `Rind/X86_64/{Blockwise,Sha,Hmac}.lean`, the hash and HMAC proofs.
- `Rind/<Arch>/ShaBlocks.lean`: SHA-1 and SHA-256's block functions on each
  target, and their padded last blocks.
- `admin/prove` copies the other `Rind/X86_64/` proof files to `Rind/Aarch64/`
  with the target renamed.

## Trust base

Beyond Lean's kernel:

- Charon and Aeneas's translation, and Aeneas's models of `core`, with
  `Rind/Core.lean`'s.
- That `Rind/X86_64/Dispatch.lean` and `Rind/X86_64/Digest.lean` compute
  what the Rust they quote does. They add no axiom.
- That `Rind/HashSpec.lean` transliterates FIPS 180-4, RFC 2104, RFC 5869,
  and RFC 8018.
- The restatement of each s2n-bignum theorem as an axiom, under the
  composition rule in the [verification epic](/quest/m3/verified/README.md).
- That rind's inline assembly is s2n-bignum's object code, as for
  `benchmarks/verified.toml`'s other s2n-bignum entries.
- The translation ignores drops, which here wipe keys and restore CPU state,
  and computes nothing an output depends on.
