# [S] rind-rustls, rind-rcgen, and rind-jsonwebtoken refuse an RSA key under 2048 bits, as aws-lc does

## Goal

`rind-rustls`'s `RsaSigningKey::new`, `rind-rcgen`'s key loaders, and
`rind-jsonwebtoken`'s RSA signer refuse a private key whose modulus is under
2048 bits, as the aws-lc-rs provider each mirrors does. rind's own private-key
floor is 2047 bits, so that rind-ring loads the 2047-bit keys ring does, and
these three adapters would otherwise load one aws-lc refuses.

## Plan

- Recommendation: check the modulus's bit length in each adapter, as
  `rind-aws-lc-rs` does in `check_bits` (`rind-aws-lc-rs/src/rsa.rs`), and
  test it against aws-lc-rs with a 2047-bit key (`rind/src/high/rsa/rsa2047.pkcs8.der`).
- `rind::rsa::PublicKey` exposes only `modulus_len` in bytes, which is 256 for
  both 2047 and 2048 bits. Recommendation: read the bit length from the DER the
  adapter already holds, as rind-aws-lc-rs's `der::bits` does, rather than add a
  `modulus_bits` to rind's API for three callers.
- First confirm each crate mirrors aws-lc-rs and not ring for RSA keys; a crate
  that mirrors ring's loads a 2047-bit key and needs nothing.
