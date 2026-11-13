// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! Constant-time checks of the module as it ships, run under valgrind by
//! `admin/ctgrind fips`: its own optimized build of rind, its C ABI, its
//! pairwise consistency tests, and its DRBG.
//!
//! Secret inputs are marked undefined, so memcheck flags any branch or memory
//! index inside the module that depends on them. Outputs that are public by
//! design are marked defined before the test checks them. The module's build
//! of rind, with `rind/__ctgrind`, marks the keys it generates or parses and
//! declassifies what it makes public.
#![cfg(rind_fips_module)]
#![cfg(feature = "__ctgrind")]

use std::num::NonZeroU32;

use crabgrind::memcheck::{self, MemState};
use crabgrind::valgrind::{self, RunningMode};
use rind_fips::signature::sign::{self, MlDsa65, MlDsaKeyPair};
use rind_fips::signature::{EcdsaKeyPair, Ed25519KeyPair, RsaKeyPair};
use rind_fips::{aead, agreement, cipher, hkdf, hmac, kem, key_wrap, pbkdf2, rand};

/// Marks `value` secret: memcheck flags any branch or index that depends on it.
fn secret<T: ?Sized>(value: &T) {
    mark(value, MemState::Undefined);
}

/// Marks `value` public, so the test may branch on it.
fn public<T: ?Sized>(value: &T) {
    mark(value, MemState::Defined);
}

fn mark<T: ?Sized>(value: &T, state: MemState) {
    if let RunningMode::Valgrind = valgrind::running_mode() {
        memcheck::mark_memory((value as *const T).cast(), size_of_val(value), state).unwrap();
    }
}

const MESSAGE: &[u8] = b"message";

#[test]
fn hmac_hkdf_and_pbkdf2() {
    let key_value = [0x0b; 32];
    let expected = rind::hmac::sign(
        &rind::hmac::Key::new(&rind::hmac::HMAC_SHA256, &key_value),
        MESSAGE,
    );
    secret(&key_value);
    let key = hmac::Key::new(&hmac::HMAC_SHA256, &key_value);
    let tag = hmac::sign(&key, MESSAGE);
    public(tag.as_ref());
    assert_eq!(tag.as_ref(), expected.as_ref());
    assert!(hmac::verify(&key, MESSAGE, tag.as_ref()).is_ok());

    let ikm = [0x0c; 32];
    secret(&ikm);
    let prk = hkdf::Salt::new(&hkdf::HKDF_SHA256, b"salt").extract(&ikm);
    let mut okm = [0u8; 42];
    prk.expand(&[b"info"], okm.len()).fill(&mut okm).unwrap();
    public(&okm);
    let key = hmac::Key::from(prk.expand(&[b"info"], &hmac::HMAC_SHA256));
    let tag = hmac::sign(&key, MESSAGE);
    public(tag.as_ref());

    let password = *b"correct horse battery staple";
    secret(&password);
    let iterations = NonZeroU32::new(1000).unwrap();
    let derived = pbkdf2::Secret::new(&pbkdf2::PBKDF2_HMAC_SHA256, &password);
    let mut out = [0u8; 32];
    derived.derive(iterations, &[5; 16], &mut out).unwrap();
    secret(&out);
    assert!(derived.verify(iterations, &[5; 16], &out).is_ok());
}

#[test]
fn aes() {
    let key = [0x42; 32];
    let sealing = rind::aead::Key::new(&rind::aead::AES_256_GCM, &key).unwrap();
    let mut sealed = MESSAGE.to_vec();
    sealing
        .seal_in_place_append_tag(
            rind::aead::Nonce::assume_unique_for_key([1; 12]),
            b"aad",
            &mut sealed,
        )
        .unwrap();

    secret(&key);
    let opening = aead::Key::new(&aead::AES_256_GCM, &key).unwrap();
    let opened = opening
        .open_in_place(
            aead::Nonce::assume_unique_for_key([1; 12]),
            b"aad",
            &mut sealed,
        )
        .unwrap();
    public(&*opened);
    assert_eq!(opened, MESSAGE);

    let mut block = [7u8; 16];
    cipher::Aes::new(&cipher::AES_256, &key)
        .unwrap()
        .encrypt_block(&mut block);
    public(&block);

    let mut stream = [0u8; 40];
    cipher::AesCtr::new(&cipher::AES_256, &key, 32)
        .unwrap()
        .apply_keystream(&[0; 16], &mut stream)
        .unwrap();
    public(&stream);

    let mut padded = MESSAGE.to_vec();
    cipher::AesCbcEncryptingKey::new(&cipher::AES_256, &key)
        .unwrap()
        .encrypt(cipher::CbcIv::assume_unpredictable([3; 16]), &mut padded);
    public(&padded[..]);
    let plaintext = cipher::AesCbcDecryptingKey::new(&cipher::AES_256, &key)
        .unwrap()
        .decrypt(&[3; 16], &mut padded)
        .unwrap();
    public(&*plaintext);
    assert_eq!(plaintext, MESSAGE);

    let kek = key_wrap::AesKek::new(&key_wrap::AES_256, &key).unwrap();
    let wrapped_key = [0x24u8; 32];
    secret(&wrapped_key);
    let mut wrapped = [0u8; 40];
    kek.wrap(&wrapped_key, &mut wrapped).unwrap();
    public(&wrapped);
    let mut unwrapped = [0u8; 32];
    kek.unwrap(&wrapped, &mut unwrapped).unwrap();
    public(&unwrapped);
    assert_eq!(unwrapped, [0x24; 32]);
}

#[test]
fn agreement_and_kem() {
    let peer = agreement::PrivateKey::generate(&agreement::ECDH_P256).unwrap();
    let scalar = [0x11u8; 32];
    secret(&scalar);
    let ours = agreement::PrivateKey::from_scalar(&agreement::ECDH_P256, &scalar).unwrap();
    let shared = ours.agree(peer.public_key().as_ref()).unwrap();
    let theirs = peer.agree(ours.public_key().as_ref()).unwrap();
    public(shared.as_ref());
    public(theirs.as_ref());
    assert_eq!(shared.as_ref(), theirs.as_ref());

    let key = kem::DecapsulationKey::generate(&kem::ML_KEM_768).unwrap();
    let (ciphertext, sent) = key.public_key().encapsulate().unwrap();
    let received = key.decapsulate(ciphertext.as_ref()).unwrap();
    public(sent.as_ref());
    public(received.as_ref());
    assert_eq!(sent.as_ref(), received.as_ref());
}

#[test]
fn signatures() {
    let ecdsa = EcdsaKeyPair::generate(&sign::ECDSA_P256_SHA256_ASN1).unwrap();
    let mut scalar = ecdsa.to_scalar().as_ref().to_vec();
    let public_key = ecdsa.public_key().as_ref().to_vec();
    secret(&scalar[..]);
    let loaded = EcdsaKeyPair::from_scalar_and_public_key(
        &sign::ECDSA_P256_SHA256_ASN1,
        &scalar,
        &public_key,
    )
    .unwrap();
    scalar.fill(0);
    let signature = loaded.sign(MESSAGE).unwrap();
    public(signature.as_ref());
    assert!(
        loaded
            .public_key()
            .verify(MESSAGE, signature.as_ref())
            .is_ok()
    );

    let seed = [0x33u8; 32];
    secret(&seed);
    let ed25519 = Ed25519KeyPair::from_seed(&seed).unwrap();
    let signature = ed25519.sign(MESSAGE);
    public(signature.as_ref());
    assert!(
        ed25519
            .public_key()
            .verify(MESSAGE, signature.as_ref())
            .is_ok()
    );
    let signature = Ed25519KeyPair::generate().unwrap().sign(MESSAGE);
    public(signature.as_ref());

    let seed = [0x44u8; 32];
    secret(&seed);
    let ml_dsa = MlDsaKeyPair::<MlDsa65>::from_seed(&seed).unwrap();
    let signature = ml_dsa.sign(MESSAGE).unwrap();
    public(signature.as_ref());
    assert!(
        ml_dsa
            .public_key()
            .verify(MESSAGE, signature.as_ref())
            .is_ok()
    );
    let signature = MlDsaKeyPair::<MlDsa65>::generate()
        .unwrap()
        .sign(MESSAGE)
        .unwrap();
    public(signature.as_ref());

    let rsa = RsaKeyPair::generate(rind_fips::rsa::KeySize::Rsa2048).unwrap();
    let signature = rsa.sign(&sign::RSA_PSS_SHA256, MESSAGE).unwrap();
    public(signature.as_ref());
    assert!(
        rsa.public_key(&sign::RSA_PSS_SHA256)
            .verify(MESSAGE, signature.as_ref())
            .is_ok()
    );
}

#[test]
fn random() {
    let mut out = [0u8; 48];
    rand::fill(&mut out).unwrap();
    public(&out);
    rand::fill(&mut out).unwrap();
    public(&out);
}
