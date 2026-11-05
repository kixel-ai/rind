# [S] AES-GCM with any IV and tag length

## Goal

rind's AES-GCM accepts IVs of any length WebCrypto allows (hashed through
GHASH when not 12 bytes) and truncated tags of 32, 64, 96, 104, 112, 120, and
128 bits, as WebCrypto, pyca, and Dart's `AesGcm` expose.

## Plan

- Keep the 12-byte, 128-bit-tag path as fast as today; the general case
  should not cost it a branch it can avoid.
- Name the types by role so a caller cannot ask for a short tag by accident;
  short tags weaken forgery resistance, which the docs say.
- Wycheproof covers both IV and tag lengths.
