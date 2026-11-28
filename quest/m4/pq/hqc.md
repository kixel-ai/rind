# [L] HQC

## Goal

rind offers HQC, NIST's second KEM, at its three parameter sets, on every backend, once NIST publishes its final FIPS.

## Plan

From [the scope](/quest/m4/pq/README.md), 2026-11-06.

- Candidate: the [HQC team's implementation](https://gitlab.com/pqc-hqc/hqc) (public domain), with a reference and an x86_64 AVX2 path and nothing for aarch64. v5.1.0 (2026-10-26) changed parameters, sampling, and the key format, so PQClean's 2023 code, which measured 0.8, 1.6, and 2.7 ms for HQC-128 key generation, encapsulation, and decapsulation on desktop, is obsolete. No verified implementation exists, and aws-lc-rs has none, so differential tests follow the [epic](/quest/m4/pq/README.md)'s rule. Its oracle is RustCrypto's [`hqc-kem`](https://github.com/RustCrypto/KEMs/tree/master/hqc-kem), a pure-Rust crate at 0.1.0-rc.0 that tracks the team's code at a 2026-02-10 commit, before v5.1.0, so it qualifies only once it tracks the final standard; the scope missed it. Measure it as a source too when this is scoped again.
- Its "constant-time" code had new timing leaks published in late 2025 (ePrint 2025/2162); audit whatever source is chosen with ctgrind before trusting it.
- Scope it again when the standard lands: the API joins ML-KEM's.
- Readiness, checked 2026-11-28 on a claim ([kixel-ai/rind#1193](https://github.com/kixel-ai/rind/pull/1193)): NIST has published neither a final nor a draft HQC FIPS, so nothing was built against the team's pre-standard code. The team's newest tag is still v5.1.0 (2026-10-26). `hqc-kem` is still 0.1.0-rc.0 (2026-07-11), and its only change since is a 2026-10-25 dependency bump, so it still predates v5.1.0 and is no oracle yet. A claim before the FIPS lands only repeats this check: claim it once both waits below clear.

## Waiting

- NIST: publishes the final HQC FIPS (expected as FIPS 207); rind does not implement a draft. As of 2026-11-28 not even a draft is out (NIST planned a draft for comment about a year after selecting HQC on 2025-03-11, and the final in 2027). Check [the CSRC FIPS list](https://csrc.nist.gov/publications/fips), which on 2026-11-28 lists nothing above FIPS 205, and [drafts open for comment](https://csrc.nist.gov/publications/drafts-open-for-comment); the final one, not a draft, clears this.
- RustCrypto/KEMs: `hqc-kem` tracks the final HQC FIPS, so it can serve as the differential-test oracle (aws-lc-rs has no HQC). On 2026-11-28 it is 0.1.0-rc.0, tracking the HQC team's code from 2026-02-10, before v5.1.0. Check [its crates.io versions](https://crates.io/crates/hqc-kem/versions) and [its commits](https://github.com/RustCrypto/KEMs/commits/master/hqc-kem) for a release that names the final standard; if it never does, another Rust HQC sharing no code with rind's source serves instead.
