# [M] pyca-compatible pyrind

## Goal

A second package offers pyca/cryptography's `hazmat` names and behavior for
what rind covers, on pyrind, so a library such as pyjwt or joserfc, or Home
Assistant's Noise transport, switches by changing an import.

## Plan

- Decided with the maintainer on 2026-11-04.
  Name it after pyrind, such as `pyrind-cryptography`.
- Match pyca's signatures, exceptions, and key serialization (PEM and DER:
  PKCS#8, SPKI, PKCS#1, SEC1) for the covered subset, and raise pyca's
  `UnsupportedAlgorithm` for the rest; never call into pyca as a fallback.
- Prove it by running pyjwt's and joserfc's test suites against it, and
  report what they still need.
