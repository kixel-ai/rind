# [M] Scope FIPS 140-3 validation

## Goal

A report gives the maintainer what FIPS 140-3 validation of rind would take,
so they can decide whether to pursue it: the module boundary, the changes
(power-on self-tests, an approved-mode API, the DRBG and entropy source,
zeroization, the service indicator), a lab, the cost, and the timeline, with
aws-lc's validated module as the reference.

## Plan

Planned by the maintainer on 2026-11-04 in m4. This quest only scopes;
the validation itself is planned from its report. Note which consumers want
it (Bun's FIPS request, [oven-sh/bun#4869](https://github.com/oven-sh/bun/issues/4869),
and Deno's and Node's FIPS builds are the precedent) and whether a FIPS build
can stay a separate crate so rind's default build pays nothing.
Zeroization starts from rind's opt-in `wipe` feature; say what FIPS adds to
it, such as wiping copies inside a call.
Algorithm testing starts from the ACVP sample sets rind passes, which
`admin/sync-acvp` lists with the groups it keeps. Recorded on 2026-11-09
against ACVP-Server v1.1.0.43, ACVP covers these that rind lacks:

- Ciphers: AES-ECB decryption (rind exposes only block encryption), AES-CCM,
  CFB, OFB, XTS, the CBC ciphertext-stealing modes, GCM-SIV, XPN, FF1, FF3-1,
  CMAC, every TDES mode, and Ascon.
- Hashes: SHA-224, SHA-512/224, SHA3-224, SHAKE (internal only), cSHAKE,
  KMAC, TupleHash, ParallelHash, and messages that are not whole bytes.
  ACVP v1.1.0.43 publishes no SHA-1 hash set.
- Signatures: ECDSA on P-224 and the binary curves, or with SHA-3 or SHAKE;
  SP 800-106 randomized hashing for ECDSA and RSA;
  RSA with SHA-3, SHAKE, or a SHAKE mask; RSA public exponents above 33 bits,
  which rind refuses as aws-lc does; FIPS 186-5 RSA key generation, whose
  sets give the primes' seeds or candidates; Ed448, Ed25519ph, Ed25519ctx;
  DSA, LMS, ML-DSA, and SLH-DSA.
- Key establishment: Curve448; KAS-ECC, whose sample sets hold no curve rind
  offers, so ECDH runs CAVP's CDH vectors instead; KAS-FFC and safe primes;
  KAS-IFC and KTS-IFC, the only ACVP sets for RSA-OAEP, which wrap it in key
  confirmation.
- KDFs: SP 800-108, the one-step and two-step KDAs, HKDF's multi-expansion,
  the TLS 1.2, TLS 1.3, SSH, IKE, SRTP, SNMP, and TPM KDFs, and PBKDF2 (its
  sample set holds only SHA2-224, which rind's PBKDF2 lacks).
- DRBGs: CTR_DRBG, Hash_DRBG, and HMAC_DRBG with reseeding or additional
  input; rind's HMAC_DRBG makes only ECDSA's nonces, and runs CAVP's vectors.
- Entropy conditioning components (SP 800-90B).

A validation needs more than these samples: an ACVP client that answers fresh
sets from NIST's server for rind's registered algorithms, as aws-lc's
`acvptool` does, and for each algorithm the test types the samples skip, such
as key generation from the server's seeds.
