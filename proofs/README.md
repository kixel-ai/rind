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
models the `Algorithm` statics that hold them.

AES-128-GCM and AES-256-GCM on x86_64 CPUs with AVX and MOVBE but no VAES,
from the AEAD API's `Key` to HACL*'s Vale AES-GCM routines, in
`Rind/X86_64/AesGcm.lean`:

- `aes_gcm_new`: a key that is not the algorithm's length is refused, and
  otherwise the key holds FIPS 197's round keys for its bytes, as Vale's
  `key_to_round_keys_LE` lays them out, and the GHASH key powers Vale's
  `hkeys_reqs_pub` requires of `E_K(0)`;
- `aes_gcm_seal`: for AAD and messages under 2^32 bytes, the ciphertext in
  place and the tag are Vale's `gcm_encrypt_LE` of the key, nonce, message,
  and AAD;
- `aes_gcm_open_separate_tag` and `aes_gcm_open`: for those lengths, the
  call succeeds exactly when Vale's `gcm_decrypt_LE` accepts the tag, leaving
  its plaintext in place, and otherwise fails, leaving zeros.

Longer AAD or messages run the by-8 code, which no proof covers. The key
setup is rind's: its AES-NI key expansion and block cipher, and its
PCLMULQDQ GHASH key powers, whose Karatsuba product and reduction
`Rind/Gf128.lean` proves to be Vale's `gf128_mul_rev` of the shifted keys
(`mul_shiftKey1`). The rest is the Rust around Vale's routines, which copies
the partial blocks and picks the six-block loop's share, as EverCrypt's proven
Low* wrapper does. The theorems assume `RunsValeAesGcm`: rind's CPU-feature
checks pick Vale's tier. `Rind/X86_64/AeadDispatch.lean` models the AEAD API's
function pointers (`Algorithm`'s `expand` and `Sealer`'s `Ops`).

`admin/prove` fails if a hand model's quote no longer matches the source, if
the source names `Ops`, builds a `Masker`, or writes its `mask` outside the
dispatch models' quotes, or if it builds a digest `Algorithm` outside
`DigestAlgorithm.lean`'s.

## Layout

- `Rind/<Arch>/{Types,Funs}.lean`: Aeneas's translation, which `admin/prove`
  writes and git ignores.
- `Rind/<Arch>/{Types,Funs}External.lean` and `Rind/Core.lean`: what the
  translation leaves opaque, and models of the few `core` items Aeneas's
  library lacks.
- `Rind/<Arch>/S2nBignum.lean`, `Rind/<Arch>/AwsLc.lean`, and
  `Rind/X86_64/ValeAesGcm.lean`: s2n-bignum's, aws-lc-verification's, and
  Vale's theorems, restated as axioms about the routines' Rust wrappers.
- `Rind/X86_64/Simd.lean` and `Rind/X86_64/AesNi.lean`: models of the x86_64
  intrinsics rind's AES-GCM setup calls, and of its AES-NI key expansion and
  block cipher, which load and store through raw pointers.
- `Rind/Spec.lean` and `Rind/Bytes.lean`: the elliptic-curve and ChaCha20
  specs and byte-conversion lemmas; `Rind/Sha2.lean` and
  `Rind/Sha2Lemmas.lean`: SHA-512's; `Rind/Vale.lean`, `Rind/ValeBytes.lean`,
  and `Rind/Gf128.lean`: Vale's AES and GF(2^128) specs and their lemmas.
- `Rind/X86_64/{Dispatch,DigestDispatch,DigestAlgorithm,AeadDispatch}.lean`:
  the hand models of the agreement, header-protection, digest, and AEAD APIs'
  dispatch.
- `Rind/X86_64/{X25519,Sha512,ChaCha20}.lean`: the X25519, SHA-512, and
  ChaCha20 proofs; `Rind/X86_64/{AesKey,Ghash,AesGcmGlue,AesGcm}.lean`: the
  AES-GCM proof, on x86_64 alone.
- `admin/prove` copies the `Rind/X86_64/` models and proofs to
  `Rind/Aarch64/` with the target renamed.
- `Rind/Aarch64/P256Dispatch.lean` and `Rind/Aarch64/P256.lean`: the hand
  model of P-256's key generation, and the P-256 proof.

## Trust base

Beyond Lean's kernel:

- Charon and Aeneas's translation, and Aeneas's models of `core`, with
  `Rind/Core.lean`'s.
- That each hand model computes what the Rust it quotes does. They add no
  axiom.
- The restatement of each s2n-bignum and aws-lc-verification theorem as an
  axiom, under the composition rule in the
  [verification epic](/quest/m3/verified/README.md), and on aarch64 the
  caveats aws-lc-verification lists for its NSym proof. It lets a
  group-membership fact a proof must decide be its defining equation, so
  `group_carrier p256_group` is the curve equation that HOL Light's
  [`P256_GROUP`](https://github.com/jrh13/hol-light/blob/217dd32e798d98926d3ab81ed3dfcdf435831e1f/EC/nistp256.ml#L82)
  proves it is.
- That `Rind/Sha2.lean` restates cryptol-specs' SHA-512 around
  `processBlock_Common`.
- That `Rind/Spec.lean`'s ChaCha20 transliterates RFC 8439 and RFC 9001.
- That `Rind/Vale.lean` transliterates Vale's AES and GF(2^128) specs and
  `hkeys_reqs_pub`, with the round functions Vale's AES spec assumes read as
  FIPS 197's, the S-box and `MixColumns` opaque.
- That `Rind/X86_64/Simd.lean`'s intrinsics compute what Intel's manual
  defines their instructions to, as an instruction model is trusted for
  s2n-bignum's and Vale's own proofs.
- That rind's inline assembly is s2n-bignum's, aws-lc's, and Vale's object
  code, as for `benchmarks/verified.toml`'s other entries.
- The translation ignores drops, which here wipe keys and hash contexts and
  restore CPU state, and computes nothing an output depends on.
