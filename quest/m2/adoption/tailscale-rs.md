# [M] tailscale-rs's tunnel runs on rind

## Goal

A PR to [tailscale-rs](https://github.com/tailscale/tailscale-rs), with
numbers, moves its WireGuard data plane (ChaCha20-Poly1305 on every packet)
and handshake (X25519, HKDF) from RustCrypto onto rind.

## Plan

Decided with the maintainer on 2026-11-04, in a planning interview.

- [BENCHMARKS.md](/BENCHMARKS.md)'s `nixos2` (an i7-8700) has rind sealing a
  1350 B packet about 3x faster than chacha20poly1305 0.11; measure against the version tailscale-rs uses, in
  its own tunnel benchmark if it has one.
- It is young, in preview, and security-critical: open an issue asking
  whether they want a backend change before preparing a large PR. Posting is
  the maintainer's call.
- Check its binding targets (C, Python, Elixir) against rind's.
