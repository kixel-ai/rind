// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! The module against aws-lc-rs, through its C ABI and its own optimized
//! build of rind: each side verifies, opens, decapsulates, or agrees on what
//! the other made, loads the other's stored keys, and derives the same bytes
//! from the same inputs.
#![cfg(rind_fips_module)]

use std::num::NonZeroU32;

use aws_lc_rs::signature::{self as theirs, KeyPair as _};
use rind_fips::signature::{self, sign, verify};
use rind_fips::{aead, agreement, hkdf, hmac, kem, pbkdf2};

/// `len` random bytes, from the module.
fn random(len: usize) -> Vec<u8> {
    let mut out = vec![0u8; len];
    rind_fips::rand::fill(&mut out).unwrap();
    out
}

/// How many messages each pair signs or derives from.
const ROUNDS: usize = 8;

#[test]
fn ecdsa() {
    let rng = aws_lc_rs::rand::SystemRandom::new();
    for (ours_sign, ours_verify, theirs_sign, theirs_verify) in [
        (
            &sign::ECDSA_P256_SHA256_ASN1,
            &verify::ECDSA_P256_SHA256_ASN1,
            &theirs::ECDSA_P256_SHA256_ASN1_SIGNING,
            &theirs::ECDSA_P256_SHA256_ASN1,
        ),
        (
            &sign::ECDSA_P256_SHA256_FIXED,
            &verify::ECDSA_P256_SHA256_FIXED,
            &theirs::ECDSA_P256_SHA256_FIXED_SIGNING,
            &theirs::ECDSA_P256_SHA256_FIXED,
        ),
        (
            &sign::ECDSA_P384_SHA384_ASN1,
            &verify::ECDSA_P384_SHA384_ASN1,
            &theirs::ECDSA_P384_SHA384_ASN1_SIGNING,
            &theirs::ECDSA_P384_SHA384_ASN1,
        ),
        (
            &sign::ECDSA_P384_SHA384_FIXED,
            &verify::ECDSA_P384_SHA384_FIXED,
            &theirs::ECDSA_P384_SHA384_FIXED_SIGNING,
            &theirs::ECDSA_P384_SHA384_FIXED,
        ),
        (
            &sign::ECDSA_P521_SHA512_ASN1,
            &verify::ECDSA_P521_SHA512_ASN1,
            &theirs::ECDSA_P521_SHA512_ASN1_SIGNING,
            &theirs::ECDSA_P521_SHA512_ASN1,
        ),
        (
            &sign::ECDSA_P521_SHA512_FIXED,
            &verify::ECDSA_P521_SHA512_FIXED,
            &theirs::ECDSA_P521_SHA512_FIXED_SIGNING,
            &theirs::ECDSA_P521_SHA512_FIXED,
        ),
    ] {
        for _ in 0..ROUNDS {
            let message = random(100);

            // Theirs verifies ours.
            let ours = signature::EcdsaKeyPair::generate(ours_sign).unwrap();
            let ours_public = ours.public_key();
            let signature = ours.sign(&message).unwrap();
            theirs::UnparsedPublicKey::new(theirs_verify, ours_public.as_ref())
                .verify(&message, signature.as_ref())
                .unwrap();

            // Ours verifies theirs, and refuses it for another message.
            let theirs_key = theirs::EcdsaKeyPair::generate(theirs_sign).unwrap();
            let signature = theirs_key.sign(&rng, &message).unwrap();
            let verifier =
                signature::PublicKey::new(ours_verify, theirs_key.public_key().as_ref()).unwrap();
            verifier.verify(&message, signature.as_ref()).unwrap();
            assert_eq!(
                verifier.verify(b"another message", signature.as_ref()),
                Err(rind_fips::Error::BadSignature)
            );

            // Each loads the other's PKCS#8 as the same key.
            let pkcs8 = theirs_key.to_pkcs8v1().unwrap();
            let loaded = signature::EcdsaKeyPair::from_pkcs8(ours_sign, pkcs8.as_ref()).unwrap();
            assert_eq!(
                loaded.public_key().as_ref(),
                theirs_key.public_key().as_ref()
            );
            let loaded =
                theirs::EcdsaKeyPair::from_pkcs8(theirs_sign, ours.to_pkcs8().as_ref()).unwrap();
            assert_eq!(loaded.public_key().as_ref(), ours_public.as_ref());
        }
    }
}

#[test]
fn ed25519() {
    for _ in 0..ROUNDS {
        let message = random(100);

        // Signing is deterministic, so one key signs alike on both sides.
        let ours = signature::Ed25519KeyPair::generate().unwrap();
        let theirs_key = theirs::Ed25519KeyPair::from_pkcs8(ours.to_pkcs8().as_ref()).unwrap();
        let ours_public = ours.public_key();
        assert_eq!(ours_public.as_ref(), theirs_key.public_key().as_ref());
        let signature = ours.sign(&message);
        assert_eq!(signature.as_ref(), theirs_key.sign(&message).as_ref());
        theirs::UnparsedPublicKey::new(&theirs::ED25519, ours_public.as_ref())
            .verify(&message, signature.as_ref())
            .unwrap();

        // Ours loads theirs, and verifies what it signs.
        let theirs_key = theirs::Ed25519KeyPair::generate().unwrap();
        let pkcs8 = theirs_key.to_pkcs8().unwrap();
        let loaded = signature::Ed25519KeyPair::from_pkcs8(pkcs8.as_ref()).unwrap();
        assert_eq!(
            loaded.public_key().as_ref(),
            theirs_key.public_key().as_ref()
        );
        let signature = theirs_key.sign(&message);
        signature::PublicKey::new(&verify::ED25519, theirs_key.public_key().as_ref())
            .unwrap()
            .verify(&message, signature.as_ref())
            .unwrap();
    }
}

#[test]
fn rsa() {
    let rng = aws_lc_rs::rand::SystemRandom::new();
    // Key generation is slow, so two keys each sign every algorithm.
    let ours = signature::RsaKeyPair::generate(rind_fips::rsa::KeySize::Rsa2048).unwrap();
    let theirs_key = aws_lc_rs::rsa::KeyPair::generate(aws_lc_rs::rsa::KeySize::Rsa2048).unwrap();
    // PKCS#1 v1.5 signing is deterministic, so ours loaded into theirs
    // signs alike.
    let ours_in_theirs = aws_lc_rs::rsa::KeyPair::from_pkcs8(ours.to_pkcs8().as_ref()).unwrap();
    for (ours_sign, ours_verify, theirs_sign, theirs_verify, deterministic) in [
        (
            &sign::RSA_PKCS1_SHA256,
            &verify::RSA_PKCS1_SHA256,
            &theirs::RSA_PKCS1_SHA256,
            &theirs::RSA_PKCS1_2048_8192_SHA256,
            true,
        ),
        (
            &sign::RSA_PKCS1_SHA384,
            &verify::RSA_PKCS1_SHA384,
            &theirs::RSA_PKCS1_SHA384,
            &theirs::RSA_PKCS1_2048_8192_SHA384,
            true,
        ),
        (
            &sign::RSA_PKCS1_SHA512,
            &verify::RSA_PKCS1_SHA512,
            &theirs::RSA_PKCS1_SHA512,
            &theirs::RSA_PKCS1_2048_8192_SHA512,
            true,
        ),
        (
            &sign::RSA_PSS_SHA256,
            &verify::RSA_PSS_SHA256,
            &theirs::RSA_PSS_SHA256,
            &theirs::RSA_PSS_2048_8192_SHA256,
            false,
        ),
        (
            &sign::RSA_PSS_SHA384,
            &verify::RSA_PSS_SHA384,
            &theirs::RSA_PSS_SHA384,
            &theirs::RSA_PSS_2048_8192_SHA384,
            false,
        ),
        (
            &sign::RSA_PSS_SHA512,
            &verify::RSA_PSS_SHA512,
            &theirs::RSA_PSS_SHA512,
            &theirs::RSA_PSS_2048_8192_SHA512,
            false,
        ),
    ] {
        let message = random(100);

        // Theirs verifies ours, whose public key is its PKCS#1 DER.
        let signature = ours.sign(ours_sign, &message).unwrap();
        theirs::UnparsedPublicKey::new(theirs_verify, ours.public_key(ours_sign).as_ref())
            .verify(&message, signature.as_ref())
            .unwrap();
        if deterministic {
            let mut theirs_signature = vec![0; ours_in_theirs.public_modulus_len()];
            ours_in_theirs
                .sign(theirs_sign, &rng, &message, &mut theirs_signature)
                .unwrap();
            assert_eq!(signature.as_ref(), theirs_signature);
        }

        // Ours verifies theirs.
        let mut theirs_signature = vec![0; theirs_key.public_modulus_len()];
        theirs_key
            .sign(theirs_sign, &rng, &message, &mut theirs_signature)
            .unwrap();
        signature::PublicKey::new(ours_verify, theirs_key.public_key().as_ref())
            .unwrap()
            .verify(&message, &theirs_signature)
            .unwrap();
    }
}

#[test]
fn ml_dsa_65() {
    use aws_lc_rs::signature::{ML_DSA_65, ML_DSA_65_SIGNING, PqdsaKeyPair};
    use rind_fips::signature::sign::{MlDsa65, MlDsaKeyPair};

    for _ in 0..ROUNDS {
        // One seed gives both sides the same key and encodings.
        let seed = random(32);
        let theirs_key = PqdsaKeyPair::from_seed(&ML_DSA_65_SIGNING, &seed).unwrap();
        let ours = MlDsaKeyPair::<MlDsa65>::from_seed(&seed).unwrap();
        let public = theirs_key.public_key().as_ref().to_vec();
        assert_eq!(ours.public_key().as_ref(), public);
        assert_eq!(
            ours.to_pkcs8().as_ref(),
            theirs_key.to_pkcs8v1().unwrap().as_ref()
        );

        // Signing is hedged, so each verifies the other's signature rather
        // than matching its bytes.
        let message = random(100);
        let signature = ours.sign(&message).unwrap();
        theirs::UnparsedPublicKey::new(&ML_DSA_65, &public)
            .verify(&message, signature.as_ref())
            .unwrap();
        let mut theirs_signature = vec![0; ML_DSA_65_SIGNING.signature_len()];
        theirs_key.sign(&message, &mut theirs_signature).unwrap();
        signature::PublicKey::new(&verify::ML_DSA_65, &public)
            .unwrap()
            .verify(&message, &theirs_signature)
            .unwrap();
    }
}

#[test]
fn ecdh() {
    for (ours_algorithm, theirs_algorithm) in [
        (&agreement::ECDH_P256, &aws_lc_rs::agreement::ECDH_P256),
        (&agreement::ECDH_P384, &aws_lc_rs::agreement::ECDH_P384),
        (&agreement::ECDH_P521, &aws_lc_rs::agreement::ECDH_P521),
    ] {
        for _ in 0..ROUNDS {
            let ours = agreement::PrivateKey::generate(ours_algorithm).unwrap();
            let theirs_key = aws_lc_rs::agreement::PrivateKey::generate(theirs_algorithm).unwrap();
            let theirs_public = theirs_key.compute_public_key().unwrap();

            let ours_secret = ours.agree(theirs_public.as_ref()).unwrap();
            let theirs_secret = aws_lc_rs::agreement::agree(
                &theirs_key,
                aws_lc_rs::agreement::UnparsedPublicKey::new(
                    theirs_algorithm,
                    ours.public_key().as_ref(),
                ),
                (),
                |secret| Ok(secret.to_vec()),
            )
            .unwrap();
            assert_eq!(ours_secret.as_ref(), theirs_secret);
        }
    }
}

#[test]
fn ml_kem_768() {
    use aws_lc_rs::kem::{Ciphertext, DecapsulationKey, EncapsulationKey, ML_KEM_768};

    for _ in 0..ROUNDS {
        // Theirs decapsulates what ours encapsulates to it.
        let theirs_key = DecapsulationKey::generate(&ML_KEM_768).unwrap();
        let theirs_public = theirs_key.encapsulation_key().unwrap().key_bytes().unwrap();
        let (ciphertext, secret) =
            kem::EncapsulationKey::new(&kem::ML_KEM_768, theirs_public.as_ref())
                .unwrap()
                .encapsulate()
                .unwrap();
        let theirs_secret = theirs_key
            .decapsulate(Ciphertext::from(ciphertext.as_ref()))
            .unwrap();
        assert_eq!(secret.as_ref(), theirs_secret.as_ref());

        // Ours decapsulates what theirs encapsulates to it.
        let ours = kem::DecapsulationKey::generate(&kem::ML_KEM_768).unwrap();
        let (ciphertext, theirs_secret) =
            EncapsulationKey::new(&ML_KEM_768, ours.public_key().as_ref())
                .unwrap()
                .encapsulate()
                .unwrap();
        let secret = ours.decapsulate(ciphertext.as_ref()).unwrap();
        assert_eq!(secret.as_ref(), theirs_secret.as_ref());
    }
}

#[test]
fn hmac() {
    for (ours, theirs_algorithm) in [
        (
            &hmac::legacy::HMAC_SHA1,
            aws_lc_rs::hmac::HMAC_SHA1_FOR_LEGACY_USE_ONLY,
        ),
        (&hmac::HMAC_SHA256, aws_lc_rs::hmac::HMAC_SHA256),
        (&hmac::HMAC_SHA384, aws_lc_rs::hmac::HMAC_SHA384),
        (&hmac::HMAC_SHA512, aws_lc_rs::hmac::HMAC_SHA512),
    ] {
        // Keys shorter than, as long as, and longer than a hash block.
        for (key_len, message_len) in [(0, 0), (16, 1), (64, 64), (128, 200), (200, 1000)] {
            let (key, message) = (random(key_len), random(message_len));
            let tag = hmac::sign(&hmac::Key::new(ours, &key), &message);
            let theirs_tag =
                aws_lc_rs::hmac::sign(&aws_lc_rs::hmac::Key::new(theirs_algorithm, &key), &message);
            assert_eq!(tag.as_ref(), theirs_tag.as_ref());
        }
    }
}

/// aws-lc-rs's HKDF output length.
struct Len(usize);

impl aws_lc_rs::hkdf::KeyType for Len {
    fn len(&self) -> usize {
        self.0
    }
}

#[test]
fn hkdf() {
    for (ours, theirs_algorithm) in [
        (
            &hkdf::legacy::HKDF_SHA1,
            aws_lc_rs::hkdf::HKDF_SHA1_FOR_LEGACY_USE_ONLY,
        ),
        (&hkdf::HKDF_SHA256, aws_lc_rs::hkdf::HKDF_SHA256),
        (&hkdf::HKDF_SHA384, aws_lc_rs::hkdf::HKDF_SHA384),
        (&hkdf::HKDF_SHA512, aws_lc_rs::hkdf::HKDF_SHA512),
    ] {
        for (salt_len, secret_len, out_len) in [(16, 32, 16), (32, 64, 42), (100, 100, 300)] {
            let (salt, secret, info) = (random(salt_len), random(secret_len), random(20));
            let info = [&info[..10], &info[10..]];
            let mut out = vec![0u8; out_len];
            hkdf::Salt::new(ours, &salt)
                .extract(&secret)
                .expand(&info, out_len)
                .fill(&mut out)
                .unwrap();
            let mut theirs_out = vec![0u8; out_len];
            aws_lc_rs::hkdf::Salt::new(theirs_algorithm, &salt)
                .extract(&secret)
                .expand(&info, Len(out_len))
                .unwrap()
                .fill(&mut theirs_out)
                .unwrap();
            assert_eq!(out, theirs_out);
        }
    }
}

#[test]
fn pbkdf2() {
    for (ours, theirs_algorithm) in [
        (
            &pbkdf2::legacy::PBKDF2_HMAC_SHA1,
            aws_lc_rs::pbkdf2::PBKDF2_HMAC_SHA1,
        ),
        (
            &pbkdf2::PBKDF2_HMAC_SHA256,
            aws_lc_rs::pbkdf2::PBKDF2_HMAC_SHA256,
        ),
        (
            &pbkdf2::PBKDF2_HMAC_SHA384,
            aws_lc_rs::pbkdf2::PBKDF2_HMAC_SHA384,
        ),
        (
            &pbkdf2::PBKDF2_HMAC_SHA512,
            aws_lc_rs::pbkdf2::PBKDF2_HMAC_SHA512,
        ),
    ] {
        // At SP 800-132's floors and above them; outputs past one block.
        for (password_len, salt_len, iterations, out_len) in
            [(14, 16, 1000, 14), (32, 32, 1001, 100)]
        {
            let (password, salt) = (random(password_len), random(salt_len));
            let iterations = NonZeroU32::new(iterations).unwrap();
            let secret = pbkdf2::Secret::new(ours, &password);
            let mut out = vec![0u8; out_len];
            secret.derive(iterations, &salt, &mut out).unwrap();
            let mut theirs_out = vec![0u8; out_len];
            aws_lc_rs::pbkdf2::derive(
                theirs_algorithm,
                iterations,
                &salt,
                &password,
                &mut theirs_out,
            );
            assert_eq!(out, theirs_out);
        }
    }
}

#[test]
fn aes_gcm() {
    use aws_lc_rs::aead::{Aad, LessSafeKey, Nonce, UnboundKey};

    for (ours, theirs_algorithm) in [
        (&aead::AES_128_GCM, &aws_lc_rs::aead::AES_128_GCM),
        (&aead::AES_192_GCM, &aws_lc_rs::aead::AES_192_GCM),
        (&aead::AES_256_GCM, &aws_lc_rs::aead::AES_256_GCM),
    ] {
        for len in [0, 1, 16, 63, 64, 1000] {
            let key = random(ours.key_len());
            let nonce: [u8; 12] = random(12).try_into().unwrap();
            let (aad, message) = (random(len % 40), random(len));
            let theirs_key = LessSafeKey::new(UnboundKey::new(theirs_algorithm, &key).unwrap());
            let mut sealed = message.clone();
            theirs_key
                .seal_in_place_append_tag(
                    Nonce::assume_unique_for_key(nonce),
                    Aad::from(&aad),
                    &mut sealed,
                )
                .unwrap();

            let ours_key = aead::Key::new(ours, &key).unwrap();
            let opened = ours_key
                .open_in_place(aead::Nonce::assume_unique_for_key(nonce), &aad, &mut sealed)
                .unwrap();
            assert_eq!(opened, message);
        }
    }
}
