# [M] rind on PowerPC

## Goal

rind and rind-rustls build for powerpc64le-unknown-linux-gnu, powerpc64-unknown-linux-gnu and powerpc-unknown-linux-gnu on the [portable backend](/ARCHITECTURE.md), and CI runs the test suite (Wycheproof, differential, rind-rustls handshakes) under qemu on each.

## Plan

powerpc64 and powerpc are big-endian; powerpc64le is little-endian. Run the tests on both byte orders. `just qemu <shell>` runs a target's tests from a flake shell built by `qemu-shell`, as s390x's does. On 2026-11-09, with nixpkgs' `pkgsCross.ppc32` toolchain (built from source, as the cache lacks it), rind's own tests and Wycheproof passed on powerpc, but every test calling the aws-lc-rs dev-dependency crashed in aws-lc's `OPENSSL_malloc` through a null function pointer, so the differential tests need that fixed first. A missing CPU feature still fails with an error naming it; the portable backend needs none. Add the targets to [PLATFORMS.md](/PLATFORMS.md) and the release checks in the same PR.
