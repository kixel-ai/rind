# [S] ECDSA over any curve and hash

## Goal

rind signs and verifies ECDSA on P-256, P-384, and P-521 with each of
SHA-256, SHA-384, and SHA-512, in both ASN.1 and fixed (r || s) encodings,
as WebCrypto (which uses the fixed encoding) and pyca allow. Today
verification covers the ASN.1 pairings, and signing and the fixed encoding
only each curve's own hash.

## Plan

Match the existing constants' names. ECDSA with SHA-1, SHA-224, or SHA-3
stays with the [aws-lc-rs extras](/quest/m3/parity/aws-lc-extras.md).
