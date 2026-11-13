// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! The numbers the C ABI names algorithms by. `rind-fips` includes this file
//! too, so both sides agree by construction.

/// Hash functions, and the HMACs, HKDFs, and PBKDF2s over them.
pub(crate) mod hash {
    pub(crate) const SHA1: u32 = 1;
    pub(crate) const SHA256: u32 = 2;
    pub(crate) const SHA384: u32 = 3;
    pub(crate) const SHA512: u32 = 4;
    pub(crate) const SHA512_256: u32 = 5;
    pub(crate) const SHA3_256: u32 = 6;
    pub(crate) const SHA3_384: u32 = 7;
    pub(crate) const SHA3_512: u32 = 8;
}

/// AES key sizes, for the block cipher's modes, key wrapping, AES-GCM of
/// any IV length, and QUIC header protection.
pub(crate) mod aes {
    pub(crate) const AES_128: u32 = 1;
    pub(crate) const AES_192: u32 = 2;
    pub(crate) const AES_256: u32 = 3;
}

/// AES-GCM, by key length.
pub(crate) mod aead {
    pub(crate) const AES_128_GCM: u32 = 1;
    pub(crate) const AES_192_GCM: u32 = 2;
    pub(crate) const AES_256_GCM: u32 = 3;
}

/// The NIST curves, for ECDH and ECDSA.
pub(crate) mod curve {
    pub(crate) const P256: u32 = 1;
    pub(crate) const P384: u32 = 2;
    pub(crate) const P521: u32 = 3;
}

/// Key encapsulation mechanisms.
pub(crate) mod kem {
    pub(crate) const ML_KEM_768: u32 = 1;
}

/// ML-DSA's parameter sets.
pub(crate) mod ml_dsa {
    pub(crate) const ML_DSA_44: u32 = 1;
    pub(crate) const ML_DSA_65: u32 = 2;
    pub(crate) const ML_DSA_87: u32 = 3;
}

/// Signature encodings.
pub(crate) mod encoding {
    /// ECDSA's ASN.1 `Ecdsa-Sig-Value`.
    pub(crate) const ASN1: u32 = 1;
    /// ECDSA's fixed-length `r || s`.
    pub(crate) const FIXED: u32 = 2;
}

/// RSA signature schemes.
pub(crate) mod rsa {
    pub(crate) const PKCS1: u32 = 1;
    pub(crate) const PSS: u32 = 2;
}

/// How an RSA-PSS salt's length is chosen.
pub(crate) mod pss_salt {
    /// As long as the digest.
    pub(crate) const DIGEST: u32 = 0;
    /// Empty.
    pub(crate) const ZERO: u32 = 1;
    /// Whatever length the signature carries, when verifying.
    pub(crate) const ANY: u32 = 2;
}

/// Error kinds, as a status's low byte carries them: rind's `Error`
/// variants that an approved service can return. The rest of a status is
/// rind's own code for the error, which names a refused key's reason.
pub(crate) mod error {
    pub(crate) const WRONG_LENGTH: u32 = 1;
    pub(crate) const KEY_REJECTED: u32 = 2;
    pub(crate) const BAD_SIGNATURE: u32 = 3;
    pub(crate) const DECRYPT_FAILED: u32 = 4;
    pub(crate) const RNG_FAILED: u32 = 5;
    pub(crate) const NOT_EQUAL: u32 = 6;
    pub(crate) const FAULT: u32 = 7;
    pub(crate) const UNSUPPORTED: u32 = 8;
}
