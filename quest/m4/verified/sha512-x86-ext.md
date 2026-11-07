# [L] x86_64 SHA-512 on the SHA512 instructions is proven

## Goal

SHA-384, SHA-512, SHA-512/256, Ed25519, and HMAC and HKDF over SHA-384 earn the ✓ on x86_64 CPUs with the SHA512 instructions (Arrow Lake, Lunar Lake, and later Intel cores).

## Plan

- Runs: OpenSSL's `sha512_block_data_order_sha512ext` (`low/x86_64/openssl/`), 5.4x faster than aws-lc's AVX routine on Arrow Lake.
- Already proven: nothing. s2n-bignum's x86_64 model lacks `vsha512rnds2`, `vsha512msg1`, and `vsha512msg2`.
- Route: add the three instructions to s2n-bignum's x86_64 model from Intel's manual, then a HOL Light proof of the routine against [awslabs/s2n-bignum#420](https://github.com/awslabs/s2n-bignum/pull/420)'s FIPS 180-4 SHA-512 spec. Offer both upstream; ask the maintainer before posting outside the moq-dev and kixelated orgs.

## Required

- [x86_64 SHA-512 on AVX2 is proven](/quest/m4/verified/sha512-x86-avx2.md) - the SHA-512 spec work and the `RunsSha512` widening this extends
