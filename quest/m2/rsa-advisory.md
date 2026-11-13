# [XS] The bench compares against the fixed rsa release

## Goal

rind-bench compares against `rsa` 0.10.0, the release that fixes the Marvin attack, and `deny.toml` no longer ignores `RUSTSEC-2023-0071`, so `cargo deny` would catch that advisory anywhere else in the tree.

## Plan

Found by the 2026-11-12 audit.

- `rind-bench/Cargo.toml:47` pins `rsa = { version = "=0.10.0-rc.19", features = ["sha2"] }`, and `deny.toml:14` ignores `RUSTSEC-2023-0071` because of it. crates.io had `rsa` 0.10.0 as its stable release that day, and the audit read the advisory as listing `patched = [">= 0.10.0"]`. Confirm both, move to `"0.10"`, and delete the ignore and its comment.
- If `cargo deny check advisories` still reports it, the advisory's patched range is not what the audit read: restore the ignore and say so in the PR.
- The pre-release's API may differ from 0.10.0's, so `rind-bench/benches/rsa_*.rs` may need to follow.
- The RSA rows in BENCHMARKS.md that name RustCrypto were measured on the release candidate. Don't rerun the report for this; the next refresh picks up the new version.
