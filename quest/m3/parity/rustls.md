# [S] rustls provider parity

## Goal

rind-rustls offers the rest of aws-lc-rs's rustls provider: the MLKEM1024 key-exchange group, and the ML-DSA-44, ML-DSA-65, and ML-DSA-87 signature schemes, both signing and verifying.

## Plan

- Waits on rind having ML-KEM-1024 and ML-DSA, which its siblings below build. They moved here from m4's post-quantum epic with the maintainer on 2026-11-09 (✅ m3/parity; rejected: m2, or pushing this quest back to m4), so this quest no longer waits on a later milestone.
- rind-rustls already offers every other algorithm aws-lc-rs's provider does. The provider's `hpke` module is the one other omission [the adapter's API quest](/quest/m0/adapters/rustls.md) lists, and [HPKE and ECH](/quest/m4/protocols/hpke.md) owns it.
- `aws_lc_rs_parity` in `rind-rustls/src/lib.rs` lists these as the only gaps in the algorithm lists it compares;
  drop each exclusion as it lands.

## Required

- [ML-KEM-512 and ML-KEM-1024](/quest/m3/parity/ml-kem.md) - rind's ML-KEM-1024
- [ML-DSA-44, ML-DSA-65, and ML-DSA-87](/quest/m3/parity/ml-dsa.md) - rind's ML-DSA

## Related

- [HPKE and ECH](/quest/m4/protocols/hpke.md) - the provider's `hpke` module, rind-rustls's other omission
