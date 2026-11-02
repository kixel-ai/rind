# [XS] x86_64 RSA wipes its heap exponent tables

## Goal

x86_64's RSA exponentiation (`rind/src/low/x86_64/mont_exp.rs` and
`rsaz.rs`) wipes the secret power tables it allocates on the heap before
freeing them, as the portable and aarch64 paths already do.

## Plan

Decided with the maintainer on 2026-11-02, from
[moq-dev/rind#263](https://github.com/moq-dev/rind/pull/263): freed heap
allocations holding secrets are wiped (the wipe-audit rule), and x86_64's RSA
tables were the remaining exception.

- Wipe each heap table once, when it is freed; stack scratch stays unwiped.
- Keep ctgrind passing; a zeroing test that observes the freed table is not
  possible in safe Rust, so state the coverage in the PR.
