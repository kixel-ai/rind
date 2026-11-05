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

P-256 ECDH on aarch64, from the same `PrivateKey` to s2n-bignum's routines, in
`Rind/Aarch64/P256.lean`:

- `p256_generate`: the key's scalar is the first of up to 64 draws whose
  bytes, read big-endian, are in [1, n), and the key is refused if a draw
  fails before one is, or none is;
- `p256_public_key`: the public key is the X9.62 uncompressed encoding of the
  scalar times G, for a scalar whose multiple is a finite point on the curve;
- `p256_agree`: a peer key is refused unless it is a 65-byte uncompressed
  point whose coordinates are below p and on the curve, and otherwise the
  secret is the 32 big-endian bytes of the x-coordinate of the scalar times
  that point, or a fault unless that is a finite point on the curve;
- `p256_shared_secret`: the secret's bytes are those.

`p256Pow` is HOL Light's `group_pow p256_group`. That a scalar in [1, n) times
a point on the curve is a finite point on the curve, so the public key's
hypothesis always holds and the fault never happens, is the group's theory,
which these theorems do not import.

ChaCha20 QUIC header protection on x86_64 and aarch64, from
`HeaderProtectionKey` to HACL*'s rounds, in `Rind/X86_64/ChaCha20.lean`:

- `chacha20_new`: a key that is not 32 bytes is refused, and otherwise the
  key holds its bytes;
- `chacha20_mask`: the mask is RFC 9001's, the first five bytes of RFC 8439's
  keystream block for the key, with the sample's first four bytes as the
  little-endian block counter and the rest as the nonce.

HACL*'s rounds are Rust, so they are translated and proven with the rest, and
no axiom stands in for HACL*'s proof of them.

Theorems that run an entry guard assume `Runs`: rind's CPU-feature checks
pass, which no input affects. `p256_public_key` also assumes `Tabulated`:
rind's generator table holds the multiples of G that s2n-bignum's proof of
`p256_scalarmulbase` assumes, which the `base_point_precomp` test checks.
`Rind/<Arch>/Axioms.lean` checks the axioms each theorem rests on.

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
(`Algorithm`'s `generate` and `Keyed`'s `Ops`), and `HeaderProtectionKey` each
cipher's `Mask` impl (`Algorithm`'s `new` and `Masker`'s `mask`), which Aeneas
cannot translate. `Rind/X86_64/Dispatch.lean` models that dispatch by hand, in
Lean definitions beside the Rust they model. P-256's key generation draws
through a `dyn RandomSource`, which Aeneas cannot translate either, and
`Rind/Aarch64/P256Dispatch.lean` models it and the `ECDH_P256` static the same
way.

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
models the `Algorithm` statics that hold them, and `Digest`, whose
`&'static Algorithm` Aeneas cannot end a borrow of `Digest` across.

Ed25519 on x86_64 and aarch64, from the signature API's `Ed25519KeyPair` and
`PublicKey` to s2n-bignum's routines and the SHA-512 proof above, in
`Rind/X86_64/Ed25519.lean`, which `admin/prove` also writes for aarch64:

- `ed25519_generate`: the key pair's seed is the 32 drawn bytes, and a failed
  draw is refused;
- `ed25519_from_seed_and_public_key`: a seed that is not 32 bytes is refused,
  so is a public key that is not the seed's, and otherwise the key pair's
  seed is the seed;
- `ed25519_sign`: the signature's bytes are RFC 8032's PureEd25519 signature
  of the message under the seed;
- `ed25519_key_pair_public_key`: the public key's bytes are RFC 8032's public
  key of the seed;
- `ed25519_public_key_new`: a public key is refused unless it is 32 bytes,
  refused if its low 255 bits are one of libsodium's seven small-order
  y-coordinates, refused unless it encodes a point of the group, and
  otherwise its `verify` accepts exactly the signatures RFC 8032 verifies with
  that point: 64 bytes, S below L, and R the encoding of SB - kA;
- `ed25519_key_pair_verify`: a key pair's public key verifies the same way,
  with its point the base point times its secret scalar, for a scalar whose
  multiple is a point of the group.

The spec, in `Rind/Ed25519.lean`, is RFC 8032 over HOL Light's
`edwards25519_group`, whose multiplication and power stay opaque, with
s2n-bignum's `ed25519_encode` and `ed25519_decode` of its points. Each theorem
assumes `Runs` and `RunsSha512`, and each with a message bounds it at
2^64 - 64 bytes. That a multiple of the base point is a point of the group,
which `ed25519_key_pair_verify` assumes, is the group's theory, which these
theorems do not import. `PublicKey` reaches each algorithm's key parser, and
each parsed key its verification, through function pointers, which
`Rind/X86_64/SignatureDispatch.lean` models.

`admin/prove` fails if a hand model's quote no longer matches the source, if
the source names `Ops`, builds a `Masker`, or writes its `mask` outside the
dispatch models' quotes, if it builds a digest `Algorithm` outside
`DigestAlgorithm.lean`'s, or if it mentions `Verification::Ed25519(` or
`Parsed::Ed25519(` outside `SignatureDispatch.lean`'s.

## Layout

- `Rind/<Arch>/{Types,Funs}.lean`: Aeneas's translation, which `admin/prove`
  writes and git ignores.
- `Rind/<Arch>/{Types,Funs}External.lean` and `Rind/Core.lean`: what the
  translation leaves opaque, and models of the few `core` items Aeneas's
  library lacks.
- `Rind/<Arch>/S2nBignum.lean` and `Rind/<Arch>/AwsLc.lean`: s2n-bignum's and
  aws-lc-verification's theorems, restated as axioms about the routines' Rust
  wrappers.
- `Rind/Spec.lean` and `Rind/Bytes.lean`: the elliptic-curve and ChaCha20
  specs and byte-conversion lemmas; `Rind/Sha2.lean` and
  `Rind/Sha2Lemmas.lean`: SHA-512's; `Rind/Ed25519.lean`: Ed25519's;
  `Rind/HashSpec.lean`: SHA-1's, SHA-256's, HMAC's, HKDF's, and PBKDF2's, and
  `Rind/HashSpecTest.lean`, their known-answer tests.
- `Rind/X86_64/{Dispatch,DigestDispatch,DigestAlgorithm,SignatureDispatch}.lean`:
  the hand models of the agreement, header-protection, digest, and signature
  APIs' dispatch.
- `Rind/X86_64/{X25519,Sha512,ChaCha20,Ed25519}.lean`: the X25519, SHA-512,
  ChaCha20, and Ed25519 proofs, and `Rind/X86_64/{Blockwise,Sha,Hmac}.lean`,
  SHA-1's, SHA-256's, and HMAC's.
- `Rind/<Arch>/ShaBlocks.lean`: SHA-1 and SHA-256's block functions on each
  target, and their padded last blocks.
- `admin/prove` copies the other `Rind/X86_64/` models and proofs to
  `Rind/Aarch64/` with the target renamed.
- `Rind/Aarch64/P256Dispatch.lean` and `Rind/Aarch64/P256.lean`: the hand
  model of P-256's key generation, and the P-256 proof.

## Trust base

Beyond Lean's kernel:

- Charon and Aeneas's translation, and Aeneas's models of `core`, with
  `Rind/Core.lean`'s.
- That each hand model computes what the Rust it quotes does. They add no
  axiom.
- That `Rind/HashSpec.lean` transliterates FIPS 180-4, RFC 2104, RFC 5869,
  and RFC 8018.
- The restatement of each s2n-bignum and aws-lc-verification theorem as an
  axiom, under the composition rule in the
  [verification epic](/quest/m3/verified/README.md), and on aarch64 the
  caveats aws-lc-verification lists for its NSym proof. It lets a
  group-membership fact a proof must decide be its defining equation, so
  `group_carrier p256_group` is the curve equation that HOL Light's
  [`P256_GROUP`](https://github.com/jrh13/hol-light/blob/217dd32e798d98926d3ab81ed3dfcdf435831e1f/EC/nistp256.ml#L82)
  proves it is, and `group_carrier edwards25519_group` the one
  [`EDWARDS25519_GROUP`](https://github.com/jrh13/hol-light/blob/217dd32e798d98926d3ab81ed3dfcdf435831e1f/EC/edwards25519.ml#L92)
  does.
- That `Rind/Sha2.lean` restates cryptol-specs' SHA-512 around
  `processBlock_Common`.
- That `Rind/Spec.lean`'s ChaCha20 transliterates RFC 8439 and RFC 9001, and
  `Rind/Ed25519.lean` RFC 8032 and s2n-bignum's encoding and decoding of
  edwards25519 points, whose `ed25519_decode` picks by Hilbert's choice as
  Lean's `Classical.epsilon` does.
- That rind's inline assembly is s2n-bignum's and aws-lc's object code, as for
  `benchmarks/verified.toml`'s other entries.
- The translation ignores drops, which here wipe keys and hash contexts and
  restore CPU state, and computes nothing an output depends on.
