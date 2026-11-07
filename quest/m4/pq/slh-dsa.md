# [L] SLH-DSA

## Goal

rind signs and verifies SLH-DSA (FIPS 205), pure and with the empty context, at every parameter set, on every backend, as fast as the fastest permissively licensed implementation measured, with keys that load and export PKCS#8 and `SubjectPublicKeyInfo` as RFC 9909 defines them.

## Plan

From [the scope](/quest/m4/pq/README.md), 2026-11-06. aws-lc-rs offers no SLH-DSA, so the bar is the fastest source measured rather than aws-lc-rs, and behavior follows FIPS 205 and the LAMPS RFC.

- Source: port the SPHINCS+ team's FIPS 205 code ([`sphincs/sphincsplus` branch `bas/fips205`](https://github.com/sphincs/sphincsplus/tree/bas/fips205), public domain or CC0-1.0, 0BSD, or MIT-0) to Rust: its reference tree code, its four-way SHAKE (x86_64 AVX2) and two-way SHAKE (aarch64 SHA-3) hashing, and its eight-way SHA-256 (x86_64 AVX2). No SLH-DSA implementation carries a functional-correctness proof; slhdsa-c's CBMC proofs cover only its portable C, which measured slowest.
- Hashing runs rind's own primitives where they are as fast: SHAKE on rind's four-way Keccak (s2n-bignum, proven), SHA-512 and single-stream SHA-256 on today's code. The AVX2 eight-way SHA-256 is new code; keep it only where it beats SHA-NI single-stream, as it did on Arrow Lake (61 ms against RustCrypto's SHA-NI 109 ms for SHA2-128s signing).
- Measured, SHA2-128s and SHAKE-128s signing: the SPHINCS+ AVX2 code takes 61 ms and 136 ms on desktop, 2 to 6 times faster than RustCrypto's `slh-dsa` and integritychain's `fips205`; on kixtop the aarch64 SHAKE code takes 146 ms, and the Rust crates trail even the portable C reference.
- API: sealed marker types per parameter set (`SlhDsaSha2_128s` through `SlhDsaShake256f`) parameterize `signature::sign::SlhDsaKeyPair<P>` and its `SlhDsaSignature<P>`, up to 49,856 bytes, so the type is heap-backed rather than a stack buffer. Verification joins the existing path as `signature::verify::SLH_DSA_*` constants.
- All twelve sets, since RFC 9909 (X.509) and RFC 9814 (CMS) assign each an OID and the code is generic over them; BoringSSL ships only SHA2-128s and SHAKE-256f, and COSE's draft only the two 128s sets. SP 800-230's six "-24" sets, capped at 2^24 signatures per key, wait until it is final.
- Signing is randomized by default, as FIPS 205 recommends; HashSLH-DSA, which RFC 9909 also defines, and context strings wait for a consumer.
- Wipe `SK.seed` and `SK.prf`. Signing is constant time over them; ctgrind covers keygen and signing.
- Tests: ACVP's SLH-DSA keyGen, sigGen, and sigVer vectors (Wycheproof has none), differential against RustCrypto's `slh-dsa` and `fips205`, and a benchmark on every backend.
