#![no_main]

//! Signature verification under every algorithm against aws-lc-rs's, for any
//! public key, signature, and message.
//!
//! The first byte picks the algorithm, and the rest is the key and the
//! signature, each after a big-endian 16-bit length, then the message.
//! rind must never accept a signature aws-lc-rs refuses, and refuses one it
//! accepts only for a key it refuses by design.

use aws_lc_rs::signature::{self as theirs, UnparsedPublicKey};
use curve25519_dalek::edwards::CompressedEdwardsY;
use der::{spki, trailing};
use libfuzzer_sys::fuzz_target;
use rind::signature::{
    PublicKey, RsaPssSaltLength, RsaVerificationAlgorithm, VerificationAlgorithm, verify,
};

mod der;

fuzz_target!(|data: &[u8]| {
    let Some((&selector, rest)) = data.split_first() else {
        return;
    };
    let Some((key, rest)) = split(rest) else {
        return;
    };
    let Some((signature, message)) = split(rest) else {
        return;
    };
    let Some((ours, theirs, kind)) = algorithm(selector) else {
        return;
    };

    let accepted = UnparsedPublicKey::new(theirs, key)
        .verify(message, signature)
        .is_ok();
    match PublicKey::new(ours, key) {
        Ok(key) => assert_eq!(key.verify(message, signature).is_ok(), accepted),
        Err(e) => assert!(
            !accepted || refused(kind, key),
            "refused a key aws-lc-rs verifies with: {e:?}"
        ),
    }
});

/// Splits `input` after a leading big-endian 16-bit length.
fn split(input: &[u8]) -> Option<(&[u8], &[u8])> {
    let (len, rest) = input.split_first_chunk::<2>()?;
    rest.split_at_checked(usize::from(u16::from_be_bytes(*len)))
}

#[derive(Clone, Copy)]
enum Kind {
    Ecdsa,
    Rsa,
    Ed25519,
}

/// The algorithm `selector` picks on each side, and its key type.
fn algorithm(
    selector: u8,
) -> Option<(
    &'static VerificationAlgorithm,
    &'static dyn theirs::VerificationAlgorithm,
    Kind,
)> {
    use verify::legacy;
    Some(match selector {
        0 => (&verify::ED25519, &theirs::ED25519, Kind::Ed25519),
        1 => (
            &verify::ECDSA_P256_SHA256_ASN1,
            &theirs::ECDSA_P256_SHA256_ASN1,
            Kind::Ecdsa,
        ),
        2 => (
            &verify::ECDSA_P256_SHA384_ASN1,
            &theirs::ECDSA_P256_SHA384_ASN1,
            Kind::Ecdsa,
        ),
        3 => (
            &verify::ECDSA_P256_SHA512_ASN1,
            &theirs::ECDSA_P256_SHA512_ASN1,
            Kind::Ecdsa,
        ),
        4 => (
            &verify::ECDSA_P384_SHA256_ASN1,
            &theirs::ECDSA_P384_SHA256_ASN1,
            Kind::Ecdsa,
        ),
        5 => (
            &verify::ECDSA_P384_SHA384_ASN1,
            &theirs::ECDSA_P384_SHA384_ASN1,
            Kind::Ecdsa,
        ),
        6 => (
            &verify::ECDSA_P384_SHA512_ASN1,
            &theirs::ECDSA_P384_SHA512_ASN1,
            Kind::Ecdsa,
        ),
        7 => (
            &verify::ECDSA_P521_SHA256_ASN1,
            &theirs::ECDSA_P521_SHA256_ASN1,
            Kind::Ecdsa,
        ),
        8 => (
            &verify::ECDSA_P521_SHA384_ASN1,
            &theirs::ECDSA_P521_SHA384_ASN1,
            Kind::Ecdsa,
        ),
        9 => (
            &verify::ECDSA_P521_SHA512_ASN1,
            &theirs::ECDSA_P521_SHA512_ASN1,
            Kind::Ecdsa,
        ),
        10 => (
            &verify::ECDSA_P256_SHA256_FIXED,
            &theirs::ECDSA_P256_SHA256_FIXED,
            Kind::Ecdsa,
        ),
        11 => (
            &verify::ECDSA_P384_SHA384_FIXED,
            &theirs::ECDSA_P384_SHA384_FIXED,
            Kind::Ecdsa,
        ),
        12 => (
            &verify::ECDSA_P521_SHA512_FIXED,
            &theirs::ECDSA_P521_SHA512_FIXED,
            Kind::Ecdsa,
        ),
        13 => (
            verify::RSA_PKCS1_SHA256.as_ref(),
            &theirs::RSA_PKCS1_2048_8192_SHA256,
            Kind::Rsa,
        ),
        14 => (
            verify::RSA_PKCS1_SHA384.as_ref(),
            &theirs::RSA_PKCS1_2048_8192_SHA384,
            Kind::Rsa,
        ),
        15 => (
            verify::RSA_PKCS1_SHA512.as_ref(),
            &theirs::RSA_PKCS1_2048_8192_SHA512,
            Kind::Rsa,
        ),
        16 => (
            verify::RSA_PSS_SHA256.as_ref(),
            &theirs::RSA_PSS_2048_8192_SHA256,
            Kind::Rsa,
        ),
        17 => (
            verify::RSA_PSS_SHA384.as_ref(),
            &theirs::RSA_PSS_2048_8192_SHA384,
            Kind::Rsa,
        ),
        18 => (
            verify::RSA_PSS_SHA512.as_ref(),
            &theirs::RSA_PSS_2048_8192_SHA512,
            Kind::Rsa,
        ),
        19 => (
            legacy::RSA_PKCS1_SHA1.as_ref(),
            &theirs::RSA_PKCS1_2048_8192_SHA1_FOR_LEGACY_USE_ONLY,
            Kind::Rsa,
        ),
        20 => (
            legacy::RSA_PKCS1_1024_SHA1.as_ref(),
            &theirs::RSA_PKCS1_1024_8192_SHA1_FOR_LEGACY_USE_ONLY,
            Kind::Rsa,
        ),
        21 => (
            legacy::RSA_PKCS1_1024_SHA256.as_ref(),
            &theirs::RSA_PKCS1_1024_8192_SHA256_FOR_LEGACY_USE_ONLY,
            Kind::Rsa,
        ),
        22 => (
            legacy::RSA_PKCS1_1024_SHA512.as_ref(),
            &theirs::RSA_PKCS1_1024_8192_SHA512_FOR_LEGACY_USE_ONLY,
            Kind::Rsa,
        ),
        23 => (
            legacy::RSA_PKCS1_3072_SHA384.as_ref(),
            &theirs::RSA_PKCS1_3072_8192_SHA384,
            Kind::Rsa,
        ),
        24 => (
            OURS_PSS_SHA256_NO_SALT.as_ref(),
            &THEIRS_PSS_SHA256_NO_SALT,
            Kind::Rsa,
        ),
        25 => (
            OURS_PSS_SHA512_MAX_SALT.as_ref(),
            &THEIRS_PSS_SHA512_MAX_SALT,
            Kind::Rsa,
        ),
        _ => return None,
    })
}

// PSS with salt lengths other than the hash's, at both ends of the range.
static OURS_PSS_SHA256_NO_SALT: RsaVerificationAlgorithm =
    RsaVerificationAlgorithm::pss_sha256(RsaPssSaltLength::Custom(0));
static THEIRS_PSS_SHA256_NO_SALT: theirs::RsaParameters =
    theirs::RSA_PSS_2048_8192_SHA256.with_pss_salt_length(theirs::RsaPssSaltLength::Custom(0));
static OURS_PSS_SHA512_MAX_SALT: RsaVerificationAlgorithm =
    RsaVerificationAlgorithm::pss_sha512(RsaPssSaltLength::Max);
static THEIRS_PSS_SHA512_MAX_SALT: theirs::RsaParameters =
    theirs::RSA_PSS_2048_8192_SHA512.with_pss_salt_length(theirs::RsaPssSaltLength::Max);

/// Whether rind refuses `key` by design where aws-lc-rs takes it.
fn refused(kind: Kind, key: &[u8]) -> bool {
    match kind {
        // aws-lc-rs also takes a `SubjectPublicKeyInfo`, and a compressed or
        // hybrid point; rind takes only the uncompressed point.
        Kind::Ecdsa => key.first() != Some(&4),
        // aws-lc-rs also takes a `SubjectPublicKeyInfo`, and ignores bytes
        // after the key.
        Kind::Rsa => spki(key) || trailing(key),
        // aws-lc-rs also takes a `SubjectPublicKeyInfo`, any length but 32,
        // and rind refuses a key of small order, under which signatures
        // nobody made verify.
        Kind::Ed25519 => match <[u8; 32]>::try_from(key) {
            Ok(key) => CompressedEdwardsY(key)
                .decompress()
                .is_some_and(|point| point.is_small_order()),
            Err(_) => true,
        },
    }
}
