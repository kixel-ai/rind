# [M] rind passes NIST's ACVP vectors

## Goal

A test harness runs NIST's ACVP vector sets (from usnistgov/ACVP-Server's JSON) against every algorithm rind offers that ACVP covers, on every backend, in a slow CI workflow.

## Plan

Moved from m4's assurance epic to m2 with the maintainer on 2026-11-09: ✅ ACVP to m2, and cryptofuzz deleted (rejected: retargeting cryptofuzz at MozillaSecurity's fork, leaving both in m4). The sets are static JSON that needs no outside party, rind's only NIST vectors today are the retired CAVP's (`thirdparty/cavp/`), and the post-quantum leaves already plan their tests on ACVP sets.

- Take the sample vector sets for AES modes, SHA-1, SHA-2, SHA-3, HMAC, the KDFs, ECDSA, EdDSA, RSA, ML-KEM, ML-DSA, and the rest, as aws-lc's ACVP tooling does. They are in [`gen-val/json-files`](https://github.com/usnistgov/ACVP-Server/tree/master/gen-val/json-files), 177 sets at v1.1.0.43 (2026-08-12), each with a `prompt.json` and an `expectedResults.json`. RustCrypto copies the sets it needs into its crates' test directories ([`ml-kem/tests`](https://github.com/RustCrypto/KEMs/tree/master/ml-kem/tests), [`slh-dsa/tests/acvp`](https://github.com/RustCrypto/signatures/tree/master/slh-dsa/tests/acvp)); rind keeps vectors under `thirdparty/`, as it does CAVP's. GitHub detects no license on ACVP-Server, so read its terms before vendoring it.
- The harness is shared: [SLH-DSA](/quest/m4/pq/slh-dsa.md) and [FN-DSA](/quest/m4/pq/fn-dsa.md) add their sets to it, as [ML-KEM](/quest/m3/parity/ml-kem.md) and [ML-DSA](/quest/m3/parity/ml-dsa.md) add their new parameter sets. ACVP has no FN-DSA or HQC set yet.
- Three CAVP directories are vendored but read by no test: `thirdparty/cavp/drbg` (`HMAC_DRBG.rsp`), `thirdparty/cavp/ecdh` (`KAS_ECC_CDH_PrimitiveTest.txt`), and `thirdparty/cavp/rsa` (the RSADP and RSASP1 component files). The HMAC-DRBG under ECDSA's nonces and the RSA tests has one test of its own, RFC 6979's example at `rind/src/high/hmac_drbg.rs:122`. Cover all three here, from those files or from ACVP's `hmacDRBG-SP800-90Ar1`, `KAS-ECC-CDH-Component-Sp800-56Ar3`, `RSA-DecryptionPrimitive-Sp800-56Br2`, and `RSA-SignaturePrimitive-2.0` sets, and delete whichever CAVP files end up unread.
- Record which ACVP algorithms rind lacks, and what [the FIPS scope](/quest/m4/fips-scope.md), which waits for this quest, would need beyond passing vectors: these are sample sets with their answers published, and a validation answers fresh ones from NIST's ACVP server.
