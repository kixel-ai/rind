# [L] SHA-256 block functions are proven

## Goal

Every SHA-256 block function rind runs on a common path is proven: HACL*'s Vale SHA-NI routine on x86_64 (switching to it if it is within about 10%), and aws-lc's aarch64 routine through a HOL Light proof in s2n-bignum's style or a switch to a proven alternative. Together with the hash glue, SHA-256, HMAC-SHA256, and HKDF earn ✓, which a proven TLS handshake needs.

## Plan

Planned with the maintainer on 2026-11-03 from the audit, which found no SHA-256 block function rind runs is proven on any path. Measure every switch on the GitHub runners first; a new HOL Light proof is research-level work, so check for upstream efforts before starting one.
