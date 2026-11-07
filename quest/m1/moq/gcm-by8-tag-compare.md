# [XS] AES-GCM by-8 opens check the tag with one vector compare

## Goal

by-8's AES-GCM open compares the tag in constant time with one vector compare rather than a byte loop, so its opens no longer trail its seals by 8-12 ns at every length.

## Plan

Decided with the maintainer on 2026-11-06: plan it in m1. [moq-dev/rind#409](https://github.com/moq-dev/rind/pull/409) measured by-8 opens 8-12 ns behind its seals at every length, which shifts the open crossovers against Vale. Compare the computed and received tags as one 16-byte vector, reducing to a single mask with no secret-dependent branch, and keep what an open does with its output on failure. Add a ctgrind test for the compare (`admin/ctgrind`), then re-measure the open crossovers on GitHub's VAES runners and `nixos`.

## Waiting

- moq-dev/rind: [moq-dev/rind#409](https://github.com/moq-dev/rind/pull/409) merges; check its state.
