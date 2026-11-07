# [M] Every published test vector rind can run

## Goal

rind's tests run every published vector set that covers an algorithm it offers. That includes:
- C2SP's CCTV, such as ML-KEM's accumulated and unlucky vectors, and the Ed25519 edge cases from "Taming the many EdDSAs";
- C2SP's latest Wycheproof, including its newer ML-KEM, ML-DSA, and edge-case files;
- aws-lc's and BoringSSL's own vector files for the algorithms they share with rind.

Each set runs on every dispatch tier.

## Plan

- Check which sets rind's Wycheproof harness already loads, and at which revision; pin each new source to a revision.
- Large sets, such as CCTV's millions of ML-KEM vectors, run in a slow workflow, not in `just ci`.
- Each failure is a bug to fix, or a documented refusal that follows aws-lc-rs.
