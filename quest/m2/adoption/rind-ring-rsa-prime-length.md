# [S] rind-ring sizes RSA keys by their primes, as ring does

## Goal

rind-ring's `rsa::KeyPair` loaders (`from_pkcs8`, `from_der`, and
`from_components`) accept and refuse a key's size exactly as ring 0.17 does.
ring requires each prime to be `ceil(n_bits / 2)` bits long and a multiple of
512 bits (`src/rsa/keypair.rs`, `PrivatePrime::new`). rind-ring instead
requires the modulus to be a multiple of 512 bits. So it refuses a 3071-bit
modulus with two 1536-bit primes, or a 4095-bit one with two 2048-bit primes,
which ring loads. It also loads a 3072-bit key with unbalanced primes, which
ring refuses.

## Plan

- Check both primes' bit lengths in rind-ring's shared `KeyPair::new`.
  Revealing only the verdict, whether each prime has the expected length, is
  acceptable, as ring and aws-lc check it too. Read the length without a
  branch or variable-time instruction on the prime's bytes.
- Recommendation: give `rind::rsa::KeyPair` a way to report whether its
  primes are balanced at a given width, rather than re-parse its PKCS#8 in
  the adapter, since rind already holds the primes and its `ct` tools.
- Test against ring with 3071-, 3072-, 4095-, and 4096-bit keys whose primes
  are each `ceil(n / 2)` bits, an unbalanced 3072-bit key, and a 2560-bit key
  (1280-bit primes, refused), under `rind-ring/tests/rsa.rs`. Update the
  `KeyPair` doc comment in `rind-ring/src/rsa.rs`.
