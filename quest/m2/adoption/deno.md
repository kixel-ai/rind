# [L] Deno's WebCrypto and node:crypto run on rind

## Goal

A PR to [Deno](https://github.com/denoland/deno), with numbers, moves every
operation rind covers in `ext/crypto` (WebCrypto) and `ext/node_crypto`
(node:crypto) from RustCrypto onto rind: ECDSA and ECDH, X25519, Ed25519,
RSA, the AES modes, HMAC, HKDF, PBKDF2, and the hashes. The win is visible:
WebCrypto ES256 verification took 437 µs on RustCrypto's p256 against Node's
46 ([denoland/deno#36072](https://github.com/denoland/deno/pull/36072)).

## Plan

Decided with the maintainer on 2026-11-04, in a planning interview:

- Deno is a marketing target even though the maintainer considers it
  deprecated: it runs the slow RustCrypto crates where rind is several times
  faster. Nothing is added to rind only for Deno; what it uses beyond the
  WebCrypto set (SLH-DSA, Argon2, KMAC, KangarooTwelve, TurboSHAKE, AES-OCB,
  X448, Ed448, ML-DSA) stays on its current crates.
- Scope: WebCrypto and node:crypto ✅ / WebCrypto only.
- Timing: after the WebCrypto epic, so one PR moves the most ✅ / now with
  today's set.
- Posting is the maintainer's call; prepare the branch, the numbers, and the
  PR text, then ask.

Guidance:

- #36072 (closed unmerged on 2026-10-29) routed ECDSA through aws-lc and was
  called ready to land; read its review for what Deno's maintainers asked.
  Deno already links aws-lc-rs, so the pitch is rind's speed over RustCrypto,
  its lead over aws-lc on aarch64 and P-384, and the RSA timing advisory
  (RUSTSEC-2023-0071) the `rsa` crate carries.
- Deno's WPT and node compat suites are the bar; keys must round-trip
  byte for byte through every import and export format.
