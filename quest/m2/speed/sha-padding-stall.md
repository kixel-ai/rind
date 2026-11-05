# [S] SHA-1 and SHA-2 padding without a store-forwarding stall

## Goal

Hashing 32 to 64 bytes with SHA-1, SHA-256, and SHA-512 never waits on a store-forwarding stall in the padding they share, so [moq-dev/rind#358](https://github.com/moq-dev/rind/pull/358)'s 8-12% SHA-1 cost at 32-64 B on x86_64 with SHA-NI is gone and no other size or hash slows.

## Plan

#358 traced the cost to the shared padding writing the length and padding bytes in pieces that a wider load then reads before the stores retire; it exists on main and #358's layout changes made it cost more. [moq-dev/rind#338](https://github.com/moq-dev/rind/pull/338) and #352 found the same class of stall in `finish_with`. The padding is under the Lean proofs, so keep it translatable by Aeneas and `admin/prove` passing. Measure 32 B, 64 B, 1350 B, HMAC, and HKDF on SHA-NI and AVX2 hosts and on aarch64 and armv7.
