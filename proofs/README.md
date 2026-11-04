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

`PrivateKey` reaches each curve's `Agree` impl through function pointers
(`Algorithm`'s `generate` and `Keyed`'s `Ops`), which Aeneas cannot translate.
`Rind/X86_64/Dispatch.lean` models that dispatch by hand, in Lean definitions
beside the Rust they model. `admin/prove` fails if that quote no longer
matches the source, or if the source names `Ops` outside it.

SHA-384, SHA-512, and SHA-512/256, from the digest API to aws-lc's block
routine, in `Rind/X86_64/Sha512.lean`, which `admin/prove` also writes for
aarch64:

- `sha512_family_digest`: `digest`'s bytes are the hash of the message;
- `sha512_family_context`: a `Context` given the message in any chunks, then
  finished, returns its hash, for messages under 2^64 bytes.

The hash is cryptol-specs' FIPS 180-4 SHA-512, in `Rind/Sha2.lean`, with its
block compression `processBlock_Common` opaque. Each theorem assumes
`RunsSha512`: on x86_64 that rind picks aws-lc's AVX routine, on an Intel CPU
with AVX, and on aarch64 its scalar routine, on a CPU without the SHA-512
instructions; those are the routines whose proofs state their result. The
digest API reaches each hash through function pointers too, which
`Rind/X86_64/DigestDispatch.lean` models, and `Rind/X86_64/DigestAlgorithm.lean`
models the `Algorithm` statics that hold them.

## Layout

- `Rind/<Arch>/{Types,Funs}.lean`: Aeneas's translation, which `admin/prove`
  writes and git ignores.
- `Rind/<Arch>/{Types,Funs}External.lean` and `Rind/Core.lean`: what the
  translation leaves opaque, and models of the few `core` items Aeneas's
  library lacks.
- `Rind/<Arch>/S2nBignum.lean` and `Rind/<Arch>/AwsLc.lean`: s2n-bignum's and
  aws-lc-verification's theorems, restated as axioms about the routines' Rust
  wrappers.
- `Rind/Spec.lean` and `Rind/Bytes.lean`: X25519's spec and byte-conversion
  lemmas; `Rind/Sha2.lean` and `Rind/Sha2Lemmas.lean`: SHA-512's.
- `Rind/X86_64/{Dispatch,DigestDispatch,DigestAlgorithm}.lean`: the hand
  models of the agreement and digest APIs' dispatch.
- `Rind/X86_64/{X25519,Sha512}.lean`: the proofs.
- `admin/prove` copies the `Rind/X86_64/` models and proofs to
  `Rind/Aarch64/` with the target renamed.

## Trust base

Beyond Lean's kernel:

- Charon and Aeneas's translation, and Aeneas's models of `core`, with
  `Rind/Core.lean`'s.
- That each hand model computes what the Rust it quotes does. They add no
  axiom.
- The restatement of each s2n-bignum and aws-lc-verification theorem as an
  axiom, under the composition rule in the
  [verification epic](/quest/m3/verified/README.md), and on aarch64 the
  caveats aws-lc-verification lists for its NSym proof.
- That `Rind/Sha2.lean` restates cryptol-specs' SHA-512 around
  `processBlock_Common`.
- That rind's inline assembly is s2n-bignum's and aws-lc's object code, as for
  `benchmarks/verified.toml`'s other entries.
- The translation ignores drops, which here wipe keys and hash contexts and
  restore CPU state, and computes nothing an output depends on.
