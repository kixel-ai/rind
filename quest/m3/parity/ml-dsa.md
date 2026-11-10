# [XL] ML-DSA-44, ML-DSA-65, and ML-DSA-87

## Goal

rind signs and verifies ML-DSA (FIPS 204) at all three parameter sets on every backend, at least as fast as aws-lc-rs, with keys that load and export PKCS#8 and `SubjectPublicKeyInfo` as RFC 9881 defines them.

## Plan

From [the scope](/quest/m4/pq/README.md), 2026-11-06, whose epic still owns the API decisions below. Moved from that epic to m3's parity epic with the maintainer on 2026-11-09: ✅ m3/parity, beside the rustls parity quest that needs ML-DSA (rejected: m2, or pushing rustls parity back to m4). rustls's aws-lc-rs provider signs and verifies ML-DSA today (rustls 0.23.46, `src/crypto/aws_lc_rs/mod.rs:180` and `sign.rs:427`), which rind-rustls filters out of its parity test (`rind-rustls/src/lib.rs:336`), and an m3 quest could not finish while this sat in m4.

- Sources, as aws-lc-rs runs them: port [mldsa-native](https://github.com/pq-code-package/mldsa-native) v2.0.0's C (Apache-2.0 OR ISC OR MIT, all of it CBMC-proven for memory safety and bounds) to Rust, as rind ported mlkem-native's, and run s2n-bignum's `mldsa_*` kernels (NTT, inverse NTT, pointwise and accumulate for l = 4, 5, 7, decompose, use-hint, `chknorm`, `caddq`, `polyz_unpack`, rejection sampling), already vendored at the pinned revision and HOL Light-proven on x86_64 AVX2 and aarch64 (the same kernels as mldsa-native's, which aws-lc imports), through `admin/parse-asm`. Their SPDX is `Apache-2.0 OR ISC OR MIT`, which ALGORITHMS.md and LICENSE already carry for s2n-bignum's ML-KEM. ExpandA, ExpandS, and ExpandMask run on rind's existing four-way Keccak. x86_64 without AVX2, armv7, and the portable backend run the port alone.
- Measured on desktop (Arrow Lake) and kixtop (M4): aws-lc-rs, which is mldsa-native with these same kernels, is the fastest library; libcrux-ml-dsa (hax-verified arithmetic, AVX2 only, portable on aarch64) trails it, and RustCrypto's `ml-dsa` signs 5 to 10 times slower. rind's ML-KEM-768 runs 0.5 to 0.9 times aws-lc-rs's time from the same kind of sources, so expect at least parity.
- API, as the [epic](/quest/m4/pq/README.md) decided: sealed marker types `MlDsa44`, `MlDsa65`, `MlDsa87` parameterize `signature::sign::MlDsaKeyPair<P>` (`generate`, `from_seed`, `to_seed`, `from_pkcs8`, `to_pkcs8`, `public_key`, `sign`) and its fixed-size `MlDsaSignature<P>`, which can't fit `signature::Signature`'s RSA-sized buffer. Verification joins the existing path as `signature::verify::{ML_DSA_44, ML_DSA_65, ML_DSA_87}`, since a certificate names its algorithm at run time; `signature::PublicKey`'s buffer grows to ML-DSA-87's 2592 bytes.
- Behavior follows aws-lc-rs and RFC 9881: pure ML-DSA with the empty context, as TLS (draft-ietf-tls-mldsa) and X.509 use it, hedged signing, PKCS#8 that accepts the seed and expanded private key forms and emits the seed. HashML-DSA, which RFC 9881 disallows, context strings, and external μ wait for a consumer.
- Wipe the seed and the expanded `s1`, `s2`, `t0`, and `K`. Signing's rejection loop count is public, as FIPS 204 allows; ctgrind declassifies it where mldsa-native's valgrind annotations do.
- Tests: Wycheproof's `mldsa_{44,65,87}_{sign_seed,sign_noseed,verify}` vectors, differential signing and verification against aws-lc-rs, ctgrind, and a benchmark on every backend.
- rind-rustls's ML-DSA signing and verification belong to [rustls provider parity](/quest/m3/parity/rustls.md).

## Related

- [rind passes NIST's ACVP vectors](/quest/m2/confidence/acvp.md) - its ML-DSA keyGen, sigGen, and sigVer sets, which this adds to the harness if it has landed
