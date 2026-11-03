# [M] Benchmarks run on every host for every library

## Goal

`rind-bench` times every operation the report lists for every library that offers it, and `admin/bench-report` runs the suite on `nixos`, `desktop`, `nixos2`, and `kixtop` over ssh, collecting machine-readable results with each host's CPU, OS, toolchain, and library versions.

## Plan

See the [epic](/quest/m1/benchmarks/README.md) for the settled decisions.

- Add graviola, and libcrux beyond ML-KEM, to `rind-bench`, and fill in OpenSSL and RustCrypto wherever they offer an operation. Keep the existing criterion IDs so CodSpeed history stays.
- The script checks out one commit on each host, builds with the pinned toolchain, and refuses to run on a busy host (load average above a threshold). It runs hosts one at a time with a capped job count, since `nixos2` is a shared 15 GB machine, and writes JSON under `.tmp/`.
- kixtop runs macOS: use its native toolchain, not Nix-only paths, and record the chip.
