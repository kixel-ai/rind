// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! 32-bit ARM, backed by libcrux's portable Rust, and by aws-lc's assembly for
//! ChaCha20, SHA-512, and RSA's Montgomery multiplication, for Poly1305 where
//! the CPU has NEON, and for the ARMv8 crypto extension where the CPU has it.
//!
//! libcrux exposes only a few operations at this layer's granularity.  The
//! rest are swapped in `mid`, where libcrux's whole operations fit, except
//! P-384, whose arithmetic is fiat-crypto's in `generic::p384`, and RSA's,
//! which is portable Rust in `generic::bignum` around aws-lc's.

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
pub(crate) mod curve25519;
pub(crate) mod ghashv8_armx;
pub(crate) mod mont;
pub(crate) mod poly1305;
mod poly1305_arm;
pub(crate) mod sha_armv4;
