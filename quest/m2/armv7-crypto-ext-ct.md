# [S] armv7's crypto-extension assembly is checked for constant time

## Goal

The AES, GHASH, and SHA assembly armv7 runs on cores with the crypto extension gets a constant-time check in CI, as the NEON and integer paths do.

## Plan

Planned with the maintainer on 2026-11-03 from an external audit. Valgrind hides `AT_HWCAP2` from the program, so armv7 ctgrind only checks the NEON and integer code (see `ctgrind.yml` and `admin/ctgrind`).

- Prefer a trace comparison like `admin/ct-sde`: run each case under qemu-arm with the crypto extension enabled and an instruction and memory-address trace plugin, with two secrets, and fail on any difference, including planted-leak cases that must differ.
- Run it in the nightly ctgrind workflow.
