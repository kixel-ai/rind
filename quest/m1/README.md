# m1: MoQ coverage and Bun

## Goal

Bun's fastest asymmetric operations run on rind, ahead of Bun writing its own.

MoQ's half is done: rind carries everything [MoQ](https://github.com/moq-dev/moq)
needs to take all its cryptography from rind, on every target MoQ releases,
and MoQ switched in [moq-dev/moq#8250](https://github.com/moq-dev/moq/pull/8250).
Its last open question, which AES-GCM tier Zen 2 runs, waits on an outside
measurement in [m3](/quest/m3/quic-path.md) (maintainer, 2026-11-09: ✅ m3;
rejected: keep it here, where it held m1 open).

## Required

- [Bun runs its fastest asymmetric crypto on rind](/quest/m1/bun.md) - Ed25519, X25519, P-384, and P-521 in Bun on rind, before Bun writes its own
