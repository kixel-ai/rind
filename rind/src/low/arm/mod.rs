// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! 32-bit ARM, backed by libcrux's portable Rust, by aws-lc's assembly for
//! ChaCha20, SHA-512, and RSA's Montgomery multiplication, for Poly1305 where
//! the CPU has NEON, and for the ARMv8 crypto extension where the CPU has it,
//! and by OpenSSL's for Keccak-f.
//!
//! libcrux exposes only a few operations at this layer's granularity.  The
//! rest are swapped in `mid`, where libcrux's whole operations fit, except
//! the NIST curves, whose arithmetic is in `generic::p256`, `generic::p384`,
//! and `generic::p521`, RSA's, which is portable Rust in `generic::bignum`
//! around aws-lc's, and ML-KEM's, which is `generic::mlkem_poly`.

/// The symbol for an aws-lc routine, qualified by rind's version so two
/// semver-incompatible copies of rind can link into one binary.
macro_rules! aws_lc_symbol {
    ($name:literal) => {
        concat!(
            "rind_",
            env!("CARGO_PKG_VERSION_MAJOR"),
            "_",
            env!("CARGO_PKG_VERSION_MINOR"),
            "_",
            env!("CARGO_PKG_VERSION_PATCH"),
            "_",
            $name
        )
    };
}

pub(crate) mod aes;
pub(crate) mod aes_ctr;
pub(crate) mod aesv8_armx;
pub(crate) mod bignum_eq;
pub(crate) mod chacha20;
mod chacha_armv4;
pub(crate) mod cpu;
#[cfg(test)]
pub(crate) mod ct_qemu;
pub(crate) mod curve25519;
#[path = "../generic/ghash_nohw.rs"]
pub(crate) mod ghash_nohw;
pub(crate) mod ghashv8_armx;
pub(crate) mod keccak1600_armv4;
pub(crate) mod mont;
pub(crate) mod poly1305;
mod poly1305_arm;
pub(crate) mod sha_armv4;
