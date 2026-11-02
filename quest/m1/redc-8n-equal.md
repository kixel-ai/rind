# [XS] x86_64 redc_8n reduces a result equal to the modulus

## Goal

x86_64's Montgomery reduction `redc_8n` returns 0, not `m`, when its result
equals the modulus, so every caller gets a fully reduced value.

## Plan

Planned with the maintainer on 2026-11-02 from
[moq-dev/rind#242](https://github.com/moq-dev/rind/pull/242)'s investigation.

- `rind/src/low/x86_64/mont.rs` subtracts `m` only when `m < reduced`; the
  check should be `reduced >= m`. A throwaway test on an i7-8700 with ADX
  reproduced it at 16 and 32 words with `m = r·s`: `mont_mul(r, s)` returned
  `m`.
- No valid RSA key or Miller-Rabin input reaches it today, so this is latent;
  keep the fix constant time and add the `m = r·s` differential test at 16
  and 32 words.
