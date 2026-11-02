# [S] ML-KEM keys hold the key hash, not a second copy

## Goal

`EncapKey` stores the 32-byte hash of the encapsulation key instead of a
second 1152-byte encoding, so ML-KEM-768's key types shrink from about 8.5 KB
to 7.4 KB and stop holding the same bytes twice.

## Plan

Planned with the maintainer on 2026-11-02 from the investigation of
CodSpeed's ML-KEM flags after
[moq-dev/rind#233](https://github.com/moq-dev/rind/pull/233).

- #233 added `t_hat_coeffs` and pushed the key types past 8 KiB, where glibc's
  `memcpy` switches to `rep movsb` on CPUs without FSRM; CodSpeed's simulator
  counts that per byte, so ML-KEM looked 19-31% slower there though real
  hardware got faster. CodSpeed itself stays as is (maintainer decision).
- Replace `EncapKey.t_hat` with `h_ek`, computed in `from_bytes` and in
  keygen; `DecapKey` reads `ek_pke.h_ek`; `as_bytes` re-encodes from
  `t_hat_coeffs` (only `public_key()` needs it). A prototype measured
  encapsulation 17% and decapsulation 20% fewer instructions than before #233.
- The hash is public, so no new secret path; keep ctgrind and the aws-lc-rs
  crosscheck passing on every backend.
