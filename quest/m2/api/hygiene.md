# [S] The audit's hazards are documented or linted

## Goal

Each misuse hazard the 2026-11-08 API audit found, short of an API change, is documented where a caller meets it or caught by the compiler. Debug output stops printing tag bytes.

## Plan

All additive. The audit's findings:

- `hmac::Tag`'s `Debug` prints its bytes, which are secret when HMAC is a PRF (rind-dimpl's DTLS PRF). `aead::gcm::Tag`'s prints all 16 bytes even when truncated. Show the algorithm only, as keys' `Debug` does.
- `#[must_use]` on `hkdf::Okm`, `hkdf::Salt::extract`, `digest::digest`, `hmac::sign`, and `cpu::has_aes_hardware`, so a discarded result warns.
- `agreement` and `kem`'s module examples derive keys through HKDF instead of comparing raw shared secrets, and MIGRATING.md's `agree_ephemeral(.., kdf)` row says to run a KDF.
- `hmac::verify` says how to check a MAC over a message in pieces, or a truncated tag a protocol fixes (SRTP's HMAC-SHA1-80): sign, then `constant_time::verify` the agreed prefix.
- `cipher::AesCtr` and `cipher::ChaCha20`: each call starts at a whole block, so continuing a stream after a length that isn't a multiple of the block size reuses keystream. Fix AesCtr's SRTP counter-width example, which says 16 bits while rind-str0m uses 128.
- `signature::PublicKey::verify`: ECDSA accepts both `(r, s)` and `(r, n-s)`, unlike Ed25519, PKCS#1, and PSS.
- `pbkdf2::Secret`: output beyond one hash adds defender cost but no strength, and iteration counts from untrusted input (PBES2, PKCS#12) need a caller cap.
- `RsaPssSaltLength::Custom`: a salt too long for the key fails at sign or verify as `KeyRejected`, not at construction.
