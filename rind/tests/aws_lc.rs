//! aws-lc's and BoringSSL's vector files for rind's algorithms, from
//! `thirdparty/vectors`, which `admin/sync-vectors` copies. Files that need
//! crate access run in `src/`: ECDSA, whose files give digests and nonces,
//! Poly1305, Miller-Rabin, and ML-KEM.

use rind::Error;
use rind::aead::{
    AES_128_GCM, AES_192_GCM, AES_256_GCM, Algorithm, CHACHA20_POLY1305, Key, Nonce, RandomNonce,
    RandomizedNonceKey, Tag, gcm,
};
use rind::agreement::{self, ECDH_P256, ECDH_P384, ECDH_P521};
use rind::cipher::{
    AES_128, AES_192, AES_256, Aes, AesCbcDecryptingKey, AesCbcEncryptingKey, AesCtr,
};
use rind::hmac;
use rind::key_wrap::AesKek;
use rind::signature::{self, verify};

#[path = "../src/test/file_test.rs"]
mod file_test;

use file_test::{Test, tests};

fn aes_algorithm(key: &[u8]) -> &'static rind::cipher::Algorithm {
    match key.len() {
        16 => &AES_128,
        24 => &AES_192,
        32 => &AES_256,
        len => panic!("unexpected AES key length {len}"),
    }
}

fn gcm_tag_length(len: usize) -> Option<gcm::TagLength> {
    Some(match len {
        16 => gcm::TagLength::Full,
        15 => gcm::TagLength::Truncated120,
        14 => gcm::TagLength::Truncated112,
        13 => gcm::TagLength::Truncated104,
        12 => gcm::TagLength::Truncated96,
        8 => gcm::TagLength::Truncated64,
        4 => gcm::TagLength::Truncated32,
        _ => return None,
    })
}

/// Checks AES-GCM through `gcm::Key`, which takes any IV and the tag lengths
/// SP 800-38D allows, and through `aead::Key` for 96-bit IVs and full tags.
/// aws-lc's EVP interface takes tags of any length, which rind refuses.
fn check_aes_gcm(
    test: &Test,
    key: &[u8],
    iv: &[u8],
    aad: &[u8],
    pt: &[u8],
    ct: &[u8],
    tag: &[u8],
    valid: bool,
) {
    let Some(tag_length) = gcm_tag_length(tag.len()) else {
        assert!(
            gcm::Key::new(aes_algorithm(key), key, gcm::TagLength::Full).is_ok(),
            "{test}"
        );
        return;
    };

    let ctx = gcm::Key::new(aes_algorithm(key), key, tag_length).unwrap();
    let iv_ = || gcm::Iv::assume_unique_for_key(iv).unwrap();
    let mut got = ct.to_vec();
    let opened = ctx
        .open_in_place_separate_tag(iv_(), aad, tag, &mut got)
        .map(|pt| pt.to_vec());
    match valid {
        true => assert_eq!(opened.as_deref(), Ok(pt), "{test}"),
        false => assert_eq!(opened, Err(Error::DecryptFailed), "{test}"),
    }
    if valid {
        let mut got = pt.to_vec();
        let sealed = ctx
            .seal_in_place_separate_tag(iv_(), aad, &mut got)
            .unwrap();
        assert_eq!((&got[..], sealed.as_ref()), (ct, tag), "{test}");
    }

    let (Ok(nonce), 16) = (<[u8; 12]>::try_from(iv), tag.len()) else {
        return;
    };
    let algorithm: &Algorithm = match key.len() {
        16 => &AES_128_GCM,
        24 => &AES_192_GCM,
        _ => &AES_256_GCM,
    };
    check_aead(test, algorithm, key, nonce, aad, pt, ct, tag, valid);
}

/// Checks an `aead::Key` opens `ct` and `tag` to `pt`, and seals it back, or
/// for an invalid test refuses it.
fn check_aead(
    test: &Test,
    algorithm: &'static Algorithm,
    key: &[u8],
    nonce: [u8; 12],
    aad: &[u8],
    pt: &[u8],
    ct: &[u8],
    tag: &[u8],
    valid: bool,
) {
    // aws-lc truncates tags on request, which rind refuses.
    if tag.len() != 16 {
        assert_eq!(Tag::try_from(tag).err(), Some(Error::WrongLength), "{test}");
        return;
    }
    let ctx = Key::new(algorithm, key).unwrap();
    let nonce = || Nonce::assume_unique_for_key(nonce);
    let mut got = ct.to_vec();
    let opened = Tag::try_from(tag).and_then(|tag| {
        ctx.open_in_place_separate_tag(nonce(), aad, tag, &mut got)
            .map(|pt| pt.to_vec())
    });
    match valid {
        true => assert_eq!(opened.as_deref(), Ok(pt), "{test}"),
        false => assert!(
            matches!(opened, Err(Error::DecryptFailed | Error::WrongLength)),
            "{test}: {opened:?}"
        ),
    }
    if valid {
        let mut got = pt.to_vec();
        let sealed = ctx
            .seal_in_place_separate_tag(nonce(), aad, &mut got)
            .unwrap();
        assert_eq!((&got[..], sealed.as_ref()), (ct, tag), "{test}");
    }
}

// AES-GCM, ChaCha20-Poly1305, and XChaCha20-Poly1305 through aws-lc's AEAD
// interface.
#[test]
fn aead() {
    for (file, algorithm) in [
        ("aes_128_gcm_tests.txt", &AES_128_GCM),
        ("aes_192_gcm_tests.txt", &AES_192_GCM),
        ("aes_256_gcm_tests.txt", &AES_256_GCM),
        ("chacha20_poly1305_tests.txt", &CHACHA20_POLY1305),
        ("xchacha20_poly1305_tests.txt", &CHACHA20_POLY1305),
    ] {
        for test in tests(&format!("aws-lc/crypto/cipher_extra/test/{file}")) {
            let (key, nonce, aad) = (test.bytes("KEY"), test.bytes("NONCE"), test.bytes("AD"));
            let (pt, ct, tag) = (test.bytes("IN"), test.bytes("CT"), test.bytes("TAG"));
            // Every test is valid: aws-lc checks that each fails once altered.
            if file.starts_with("aes") {
                check_aes_gcm(&test, &key, &nonce, &aad, &pt, &ct, &tag, true);
                let mut bad = tag.clone();
                bad[0] ^= 1;
                check_aes_gcm(&test, &key, &nonce, &aad, &pt, &ct, &bad, false);
            } else if file.starts_with("xchacha") {
                // rind takes only full tags.
                if tag.len() != 16 {
                    continue;
                }
                let ctx = RandomizedNonceKey::new(&key.try_into().unwrap());
                let nonce: [u8; 24] = nonce.try_into().unwrap();
                let mut sealed = [&ct[..], &tag[..]].concat();
                let opened = ctx.open_in_place(RandomNonce::from(nonce), &aad, &mut sealed);
                assert_eq!(opened.as_deref(), Ok(&pt[..]), "{test}");
                let mut sealed = [&ct[..], &tag[..]].concat();
                *sealed.last_mut().unwrap() ^= 1;
                let opened = ctx.open_in_place(RandomNonce::from(nonce), &aad, &mut sealed);
                assert_eq!(opened, Err(Error::DecryptFailed), "{test}");
            } else {
                let nonce: [u8; 12] = nonce.try_into().unwrap();
                check_aead(&test, algorithm, &key, nonce, &aad, &pt, &ct, &tag, true);
                let mut bad = tag.clone();
                bad[0] ^= 1;
                check_aead(&test, algorithm, &key, nonce, &aad, &pt, &ct, &bad, false);
            }
        }
    }
}

// The EVP cipher tests for the AES modes rind has; DES, RC4, and OFB it
// doesn't.
#[test]
fn cipher() {
    for test in tests("aws-lc/crypto/cipher_extra/test/cipher_tests.txt") {
        let cipher = test.str("Cipher");
        let (key, pt, ct) = (
            test.bytes("Key"),
            test.bytes("Plaintext"),
            test.bytes("Ciphertext"),
        );
        let algorithm = || aes_algorithm(&key);
        let iv = || -> [u8; 16] { test.bytes("IV").try_into().unwrap() };
        let invalid = test.get("Operation") == Some("InvalidDecrypt");
        let Some(mode) = cipher.strip_prefix("AES-") else {
            continue;
        };
        match mode {
            m if m.ends_with("-ECB") => {
                let aes = Aes::new(algorithm(), &key).unwrap();
                for (p, c) in pt.chunks(16).zip(ct.chunks(16)) {
                    let mut block: [u8; 16] = p.try_into().unwrap();
                    aes.encrypt_block(&mut block);
                    assert_eq!(block, c, "{test}");
                }
            }
            m if m.ends_with("-CBC") => {
                let mut got = pt.clone();
                let enc = AesCbcEncryptingKey::new(algorithm(), &key).unwrap();
                enc.encrypt_blocks(&iv(), &mut got).unwrap();
                assert_eq!(got, ct, "{test}");
                let dec = AesCbcDecryptingKey::new(algorithm(), &key).unwrap();
                dec.decrypt_blocks(&iv(), &mut got).unwrap();
                assert_eq!(got, pt, "{test}");
            }
            m if m.ends_with("-CTR") => {
                let ctr = AesCtr::new(algorithm(), &key, 128).unwrap();
                let mut got = pt.clone();
                ctr.apply_keystream(&iv(), &mut got).unwrap();
                assert_eq!(got, ct, "{test}");
            }
            m if m.ends_with("-GCM") => {
                let (aad, tag) = (test.bytes("AAD"), test.bytes("Tag"));
                let iv = test.bytes("IV");
                check_aes_gcm(&test, &key, &iv, &aad, &pt, &ct, &tag, !invalid);
            }
            m if m.ends_with("-OFB") => {}
            _ => panic!("{test}: unexpected cipher {cipher}"),
        }
    }
}

// The AES block, AES-KW, and AES-KWP.
#[test]
fn aes() {
    for test in tests("aws-lc/crypto/fipsmodule/aes/aes_tests.txt") {
        let (key, pt, ct) = (
            test.bytes("Key"),
            test.bytes("Plaintext"),
            test.bytes("Ciphertext"),
        );
        let algorithm = aes_algorithm(&key);
        match test.str("Mode") {
            "Raw" => {
                let mut block: [u8; 16] = pt.clone().try_into().unwrap();
                Aes::new(algorithm, &key).unwrap().encrypt_block(&mut block);
                assert_eq!(block, &ct[..], "{test}");
            }
            "KeyWrap" => {
                let kek = AesKek::new(algorithm, &key).unwrap();
                let mut got = vec![0; ct.len()];
                kek.wrap(&pt, &mut got).unwrap();
                assert_eq!(got, ct, "{test}");
                let mut got = vec![0; pt.len()];
                kek.unwrap(&ct, &mut got).unwrap();
                assert_eq!(got, pt, "{test}");
            }
            "KeyWrapWithPadding" => {
                let kek = AesKek::new(algorithm, &key).unwrap();
                let mut got = vec![0; ct.len()];
                kek.wrap_padded(&pt, &mut got).unwrap();
                assert_eq!(got, ct, "{test}");
                let mut got = vec![0; ct.len() - 8];
                assert_eq!(kek.unwrap_padded(&ct, &mut got).unwrap(), pt, "{test}");
            }
            mode => panic!("{test}: unexpected mode {mode}"),
        }
    }
}

// GCM with IVs of many lengths.
#[test]
fn gcm() {
    for test in tests("aws-lc/crypto/fipsmodule/modes/gcm_tests.txt") {
        let key = test.bytes("Key");
        let (iv, aad) = (test.bytes("Nonce"), test.bytes("AdditionalData"));
        let (pt, ct, tag) = (
            test.bytes("Plaintext"),
            test.bytes("Ciphertext"),
            test.bytes("Tag"),
        );
        check_aes_gcm(&test, &key, &iv, &aad, &pt, &ct, &tag, true);
    }
}

// HMAC with the hashes rind has. MD5, SHA-224, SHA-512/224, SHA-512/256,
// and SHA-3 it doesn't offer for HMAC.
#[test]
fn hmac() {
    for test in tests("aws-lc/crypto/hmac_extra/hmac_tests.txt") {
        let algorithm = match test.str("HMAC") {
            "SHA1" => &hmac::legacy::HMAC_SHA1,
            "SHA256" => &hmac::HMAC_SHA256,
            "SHA384" => &hmac::HMAC_SHA384,
            "SHA512" => &hmac::HMAC_SHA512,
            "MD5" | "SHA224" | "SHA512/224" | "SHA512/256" | "SHA3-224" | "SHA3-256"
            | "SHA3-384" | "SHA3-512" => continue,
            other => panic!("{test}: unexpected hash {other}"),
        };
        let key = hmac::Key::new(algorithm, &test.bytes("Key"));
        let tag = hmac::sign(&key, &test.bytes("Input"));
        assert_eq!(tag.as_ref(), test.bytes("Output"), "{test}");
    }
}

// Ed25519 signing and verification, from the reference implementation's
// `sign.input`.
#[test]
fn ed25519() {
    for test in tests("aws-lc/crypto/fipsmodule/curve25519/ed25519_tests.txt") {
        let (private, public) = (test.bytes("PRIV"), test.bytes("PUB"));
        let (msg, sig) = (test.bytes("MESSAGE"), test.bytes("SIG"));
        let key =
            signature::Ed25519KeyPair::from_seed_and_public_key(&private[..32], &public).unwrap();
        assert_eq!(key.sign(&msg).as_ref(), sig, "{test}");
        let public = signature::PublicKey::new(&verify::ED25519, &public).unwrap();
        public.verify(&msg, &sig).unwrap();
    }
}

fn uncompressed(test: &Test, x: &str, y: &str) -> Vec<u8> {
    [&[4][..], &test.bytes(x), &test.bytes(y)].concat()
}

// Public keys of edge-case scalars. aws-lc multiplies by any scalar, but
// refuses a private key outside 1 to n - 1, as rind does. P-224 and secp256k1
// rind doesn't offer.
#[test]
fn ec_scalar_base_mult() {
    for test in tests("aws-lc/crypto/fipsmodule/ec/ec_scalar_base_mult_tests.txt") {
        let (algorithm, order) = match test.str("Curve") {
            "P-256" => (
                &ECDH_P256,
                "ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551",
            ),
            "P-384" => (
                &ECDH_P384,
                "ffffffffffffffffffffffffffffffffffffffffffffffffc7634d81f4372ddf\
                 581a0db248b0a77aecec196accc52973",
            ),
            "P-521" => (
                &ECDH_P521,
                "01ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\
                 fffa51868783bf2f966b7fcc0148f709a5d03bb5c9b8899c47aebb6fb71e9138\
                 6409",
            ),
            "P-224" | "secp256k1" => continue,
            other => panic!("{test}: unexpected curve {other}"),
        };
        let order = hex::decode(order).unwrap();
        let n = test.bytes("N");
        let n = &n[n.iter().position(|b| *b != 0).unwrap_or(n.len())..];
        let scalar = [&vec![0; order.len().saturating_sub(n.len())][..], n].concat();
        let key = agreement::PrivateKey::from_scalar(algorithm, &scalar);
        if n.is_empty() || scalar.len() > order.len() || scalar >= order {
            assert!(key.is_err(), "{test}");
            continue;
        }
        assert_eq!(
            key.unwrap().public_key().as_ref(),
            uncompressed(&test, "X", "Y"),
            "{test}"
        );
    }
}

// NIST's ECDH vectors. P-224 and secp256k1 rind doesn't offer.
#[test]
fn ecdh() {
    for test in tests("aws-lc/crypto/ecdh_extra/ecdh_tests.txt") {
        let algorithm = match test.str("Curve") {
            "P-256" => &ECDH_P256,
            "P-384" => &ECDH_P384,
            "P-521" => &ECDH_P521,
            "P-224" | "secp256k1" => continue,
            other => panic!("{test}: unexpected curve {other}"),
        };
        let key = agreement::PrivateKey::from_scalar(algorithm, &test.bytes("Private")).unwrap();
        assert_eq!(
            key.public_key().as_ref(),
            uncompressed(&test, "X", "Y"),
            "{test}"
        );
        let secret = key.agree(&uncompressed(&test, "PeerX", "PeerY")).unwrap();
        assert_eq!(secret.as_ref(), test.bytes("Z"), "{test}");
    }
}
