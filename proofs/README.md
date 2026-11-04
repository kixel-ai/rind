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

`PrivateKey` reaches each curve's `Agree` impl through function pointers
(`Algorithm`'s `generate` and `Keyed`'s `Ops`), and `HeaderProtectionKey` each
cipher's `Mask` impl (`Algorithm`'s `new` and `Masker`'s `mask`), which Aeneas
cannot translate. `Rind/X86_64/Dispatch.lean` models that dispatch by hand, in
Lean definitions beside the Rust they model. P-256's key generation draws
through a `dyn RandomSource`, which Aeneas cannot translate either, and
`Rind/Aarch64/P256Dispatch.lean` models it and the `ECDH_P256` static the same
way. `admin/prove` fails if either quote no longer matches the source, or if
the source names `Ops`, builds a `Masker`, or writes its `mask` outside the
first.

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
- `Rind/X86_64/Dispatch.lean`: the hand model of the agreement and
  header-protection APIs' dispatch.
- `Rind/X86_64/X25519.lean` and `Rind/X86_64/ChaCha20.lean`: the X25519 and
  ChaCha20 proofs.
- `admin/prove` copies those three `Rind/X86_64/` files to `Rind/Aarch64/`
  with the target renamed.
- `Rind/Aarch64/P256Dispatch.lean` and `Rind/Aarch64/P256.lean`: the hand
  model of P-256's key generation, and the P-256 proof.

## Trust base

Beyond Lean's kernel:

- Charon and Aeneas's translation, and Aeneas's models of `core`, with
  `Rind/Core.lean`'s.
- That `Rind/X86_64/Dispatch.lean` and `Rind/Aarch64/P256Dispatch.lean`
  compute what the Rust they quote does. They add no axiom.
- The restatement of each s2n-bignum theorem as an axiom, under the
  composition rule in the [verification epic](/quest/m3/verified/README.md).
  It lets a group-membership fact a proof must decide be its defining
  equation, so `group_carrier p256_group` is the curve equation that HOL
  Light's
  [`P256_GROUP`](https://github.com/jrh13/hol-light/blob/217dd32e798d98926d3ab81ed3dfcdf435831e1f/EC/nistp256.ml#L82)
  proves it is.
- That `Rind/Spec.lean`'s ChaCha20 transliterates RFC 8439 and RFC 9001.
- That rind's inline assembly is s2n-bignum's object code, as for
  `benchmarks/verified.toml`'s other s2n-bignum entries.
- The translation ignores drops, which here wipe keys and restore CPU state,
  and computes nothing an output depends on.
