# [M] rind generates P-256 keys faster than Bun's BoringSSL

## Goal

`EcdsaKeyPair::generate` and ECDH key generation on P-256 beat Bun's pinned
BoringSSL's `EC_KEY_generate_key` on EPYC, Neoverse-N2, and M1. With signing
already ahead and verification level, P-256 can then join a Bun PR.

## Plan

Decided with the maintainer on 2026-11-06: plan it in m1. That reopens an option
the maintainer turned down on 2026-11-05, when they accepted
[moq-dev/rind#374](https://github.com/moq-dev/rind/pull/374) and finished the old
key generation quest. The extended Bun prototype
([moq-dev/rind#368](https://github.com/moq-dev/rind/pull/368)) left P-256 on
BoringSSL. The rule there is to move an operation only when it is clearly ahead:

- key generation is 0.83x of BoringSSL as a primitive, and 0.5x to 0.8x end to end;
- verification is about 1.0x;
- signing is 1.3x to 1.4x.

#374 found where the gap is. rind's base point multiplication and inversion already
match aws-lc's. The difference is that rind computes the public key's affine
coordinates during generation, while `EC_KEY_generate_key` puts that off until the
key is encoded. Against BoringSSL plus `EC_KEY_key2buf`, rind is already 1.17x to
1.25x. Two levers remain:

- **Put off the affine conversion** until the public key is first read (its bytes or
  `public_key()`). Keep the Jacobian point and convert it
  once, through `ReuseCache::get_or_build_now` as #374 did for the odd multiples.
  The put-off inversion must stay constant time, since Z depends on the secret scalar. Check
  whether Bun's WebCrypto and node:crypto `generateKey` read the public key
  straight away. If they do, this lever saves nothing end to end, so measure
  the calls Bun makes, not only the primitive.
- **aws-lc's armv8 nistz256 base multiply** on aarch64, which #374 estimated at
  about 8.5% faster than s2n-bignum's proven `p256_scalarmulbase`. The ~10% rule
  for verified ties keeps the proven routine, so use this lever only if the first
  one falls short on aarch64, and ask the maintainer first.

Measure with #368's harness on the four GitHub runners and on `nixos`, comparing
only matching `CPU:` lines. Put the first lever's Lean change through
`admin/prove`, since aarch64's key generation proof covers the conversion. Run
`admin/ctgrind` on the changed generation path.

## Related

- [Bun runs its fastest asymmetric crypto on rind](/quest/m1/bun.md) - P-256 stays out of the Bun PR until this lands
