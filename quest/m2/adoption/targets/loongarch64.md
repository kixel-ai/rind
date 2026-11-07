# [S] rind on loongarch64

## Goal

rind and rind-rustls build for loongarch64-unknown-linux-gnu on the [portable backend](/quest/m2/adoption/targets/portable.md), and CI runs the test suite (Wycheproof, differential, rind-rustls handshakes) under qemu on each.

## Plan

Little-endian. Check that qemu and valgrind (for ctgrind) support it in the Nix shell. A missing CPU feature still fails with an error naming it; the portable backend needs none. Add the targets to [PLATFORMS.md](/PLATFORMS.md) and the release checks in the same PR.

## Required

- [Portable backend](/quest/m2/adoption/targets/portable.md) - the backend these targets compile
