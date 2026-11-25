# [S] rind-ring verifies with ring's byte-rounded RSA modulus floors

## Goal

rind-ring's `RSA_*` verification algorithms, through `UnparsedPublicKey::verify`
and `PublicKeyComponents::verify`, accept a modulus as ring 0.17 does: ring
rounds its bit length up to whole bytes before comparing it to an algorithm's
floor (`src/rsa/public_modulus.rs`). So ring verifies a signature of a 2047-bit
key under `RSA_PSS_2048_8192_SHA256`, and of a 3071-bit key under
`RSA_PKCS1_3072_8192_SHA384`, which rind-ring refuses, though it signs with
both keys since it sizes them by their primes.

## Plan

- rind's verification algorithms compare exact bits, and it has no PSS or
  SHA-384 algorithm below 2048 and 3072 bits. Open decision: give rind's
  `VerificationAlgorithm` a byte-rounded floor, or list the 2047- and 3071-bit
  verifications as refused in rind-ring's README. Recommendation: the README,
  since no one signs with a modulus of an odd size outside ring's own tests,
  and an adapter's divergence it lists is not a bug.
- Test 2047- and 3071-bit signatures from `rind-ring/tests/rsa.rs`'s keys
  against ring, replacing the 2047-bit skip in `key_pair_prime_lengths`.

## Waiting

- Maintainer: pick the README or the byte-rounded floor in rind, per the Plan;
  recommend the README. Check it by reading the Plan's decision recorded.
