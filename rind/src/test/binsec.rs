// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! The harnesses `admin/ct-binsec` checks under BINSEC: each runs one
//! primitive's secret paths through the public API in a single checked
//! region. A key is secret from where rind marks it, once parsed, and a
//! harness marks the other secrets it passes, such as a plaintext. A
//! harness ignores what a declassified check returns, since BINSEC takes
//! both of its values.

use crate::low::ct;
use crate::low::ct_binsec::checked;

/// `N` bytes of `fill`, marked secret.
fn secret<const N: usize>(fill: u8) -> [u8; N] {
    let bytes = [fill; N];
    ct::secret_slice(&bytes);
    bytes
}

// Messages take a whole block, then a partial one, through each cipher's
// tail handling, at a length that keeps BINSEC's search short.
const MESSAGE: usize = 75;

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_aes_gcm() {
    use crate::aead::*;

    checked(|| {
        for algorithm in [&AES_128_GCM, &AES_192_GCM, &AES_256_GCM] {
            let key = Key::new(algorithm, &secret::<32>(1)[..algorithm.key_len()]).unwrap();
            let nonce = || Nonce::assume_unique_for_key([2; 12]);
            let mut msg = secret::<MESSAGE>(3);
            let tag = key.seal_in_place_separate_tag(nonce(), &[4; 21], &mut msg).unwrap();
            let _ = key.open_in_place_separate_tag(nonce(), &[4; 21], tag, &mut msg);
        }
    });
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_chacha20_poly1305() {
    use crate::aead::*;

    checked(|| {
        let key = Key::new(&CHACHA20_POLY1305, &secret::<32>(1)).unwrap();
        let nonce = || Nonce::assume_unique_for_key([2; 12]);
        let mut msg = secret::<MESSAGE>(3);
        let tag = key.seal_in_place_separate_tag(nonce(), &[4; 21], &mut msg).unwrap();
        let _ = key.open_in_place_separate_tag(nonce(), &[4; 21], tag, &mut msg);
    });
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_xchacha20_poly1305() {
    use crate::aead::*;

    checked(|| {
        let key = RandomizedNonceKey::new(&secret::<32>(1));
        let mut msg = secret::<MESSAGE>(3).to_vec();
        let nonce = key.seal_in_place_append_tag(&[4; 21], &mut msg).unwrap();
        let _ = key.open_in_place(nonce, &[4; 21], &mut msg);
    });
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_quic_header_protection() {
    use crate::aead::quic::*;

    checked(|| {
        for algorithm in [&AES_128, &AES_256, &CHACHA20] {
            let key = HeaderProtectionKey::new(algorithm, &secret::<32>(1)[..algorithm.key_len()]);
            key.unwrap().mask(&[2; SAMPLE_LEN]);
        }
    });
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_aes() {
    use crate::cipher::*;

    checked(|| {
        for algorithm in [&AES_128, &AES_192, &AES_256] {
            let key = &secret::<32>(1)[..algorithm.key_len];
            Aes::new(algorithm, key).unwrap().encrypt_block(&mut secret(2));
            let ctr = AesCtr::new(algorithm, key, 32).unwrap();
            ctr.apply_keystream(&[3; 16], &mut secret::<MESSAGE>(4)).unwrap();
        }
    });
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_aes_cbc() {
    use crate::cipher::*;

    checked(|| {
        for algorithm in [&AES_128, &AES_192, &AES_256] {
            let key = &secret::<32>(1)[..algorithm.key_len];
            let mut msg = secret::<MESSAGE>(2).to_vec();
            let iv = CbcIv::assume_unpredictable([3; 16]);
            let encrypting = AesCbcEncryptingKey::new(algorithm, key).unwrap();
            encrypting.encrypt(iv, &mut msg);
            let decrypting = AesCbcDecryptingKey::new(algorithm, key).unwrap();
            let _ = decrypting.decrypt(&[3; 16], &mut msg);
        }
    });
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_chacha20() {
    use crate::cipher::*;

    checked(|| {
        let key = ChaCha20::new(&secret(1));
        key.apply_keystream(&[2; 12], 3, &mut secret::<MESSAGE>(4)).unwrap();
    });
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_aes_kw() {
    use crate::key_wrap::*;

    checked(|| {
        for algorithm in [&AES_128, &AES_192, &AES_256] {
            let kek = AesKek::new(algorithm, &secret::<32>(1)[..algorithm.key_len]).unwrap();
            let (mut wrapped, mut key) = ([0; 24], [0; 16]);
            kek.wrap(&secret::<16>(2), &mut wrapped).unwrap();
            let _ = kek.unwrap(&wrapped, &mut key);
            let (mut wrapped, mut key) = ([0; 32], [0; 20]);
            kek.wrap_padded(&secret::<20>(2), &mut wrapped).unwrap();
            let _ = kek.unwrap_padded(&wrapped, &mut key);
        }
    });
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_digest() {
    use crate::digest::*;

    checked(|| {
        for algorithm in [&legacy::MD5, &legacy::SHA1, &SHA256, &SHA384, &SHA512]
            .into_iter()
            .chain([&SHA512_256, &SHA3_256, &SHA3_384, &SHA3_512])
        {
            let _ = digest(algorithm, &secret::<150>(1));
        }
    });
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_hmac() {
    use crate::hmac::*;

    checked(|| {
        for algorithm in [&legacy::HMAC_SHA1, &HMAC_SHA256, &HMAC_SHA384, &HMAC_SHA512] {
            let key = Key::new(algorithm, &secret::<200>(1));
            let tag = sign(&key, &secret::<150>(2));
            let _ = verify(&key, &secret::<150>(2), tag.as_ref());
        }
    });
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_hkdf() {
    use crate::hkdf::*;

    checked(|| {
        let prk = Salt::new(&HKDF_SHA256, &[1; 32]).extract(&secret::<32>(2));
        let mut okm = [0; 80];
        prk.expand(&[b"info"], okm.len()).fill(&mut okm).unwrap();
    });
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_pbkdf2() {
    use crate::pbkdf2::*;

    checked(|| {
        let secret = Secret::new(&PBKDF2_HMAC_SHA256, &secret::<20>(1));
        let mut out = [0; 40];
        let iterations = core::num::NonZeroU32::new(2).unwrap();
        secret.derive(iterations, &[2; 16], &mut out).unwrap();
        let _ = secret.verify(iterations, &[2; 16], &out);
    });
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_x25519() {
    use crate::agreement::*;

    let peer = PrivateKey::from_scalar(&X25519, &[7; 32]).unwrap();
    let peer = peer.public_key().as_ref().to_vec();
    checked(|| {
        let key = PrivateKey::from_scalar(&X25519, &[1; 32]).unwrap();
        let _ = key.agree(&peer);
    });
}

fn ecdh(algorithm: &'static crate::agreement::Algorithm, len: usize) {
    use crate::agreement::*;

    // Each scalar is below its curve's order, P-521's having a top byte of 1.
    let mut scalar = vec![1; len];
    scalar[len - 1] = 2;
    let peer = PrivateKey::from_scalar(algorithm, &scalar).unwrap();
    let peer = peer.public_key().as_ref().to_vec();
    checked(|| {
        let key = PrivateKey::from_scalar(algorithm, &vec![1; len]).unwrap();
        let _ = key.agree(&peer);
    });
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_ecdh_p256() {
    ecdh(&crate::agreement::ECDH_P256, 32);
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_ecdh_p384() {
    ecdh(&crate::agreement::ECDH_P384, 48);
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_ecdh_p521() {
    ecdh(&crate::agreement::ECDH_P521, 66);
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_mlkem768() {
    use crate::mid::mlkem768::DecapKey;

    let (_, ciphertext) = DecapKey::keygen_internal(&[1; 64]).encapsulation_key().encaps().unwrap();
    checked(|| DecapKey::keygen_internal(&[1; 64]).decaps(&ciphertext));
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_ed25519() {
    use crate::signature::*;

    checked(|| {
        let key = Ed25519KeyPair::from_seed(&[1; 32]).unwrap();
        key.sign(&secret::<40>(2))
    });
}

fn ecdsa(algorithm: &'static crate::signature::EcdsaSigningAlgorithm, pkcs8: &[u8]) {
    use crate::signature::*;

    checked(|| {
        let key = EcdsaKeyPair::from_pkcs8(algorithm, pkcs8).unwrap();
        let _ = key.sign(&secret::<40>(1));
    });
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_ecdsa_p256() {
    use crate::signature::sign::ECDSA_P256_SHA256_FIXED;
    ecdsa(&ECDSA_P256_SHA256_FIXED, include_bytes!("../high/ecdsa/secp256r1.pkcs8.der"));
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_ecdsa_p384() {
    use crate::signature::sign::ECDSA_P384_SHA384_FIXED;
    ecdsa(&ECDSA_P384_SHA384_FIXED, include_bytes!("../high/ecdsa/secp384r1.pkcs8.der"));
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_ecdsa_p521() {
    use crate::signature::sign::ECDSA_P521_SHA512_FIXED;
    ecdsa(&ECDSA_P521_SHA512_FIXED, include_bytes!("../high/ecdsa/secp521r1.pkcs8.der"));
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_constant_time_verify() {
    let _ = checked(|| crate::constant_time::verify(&secret::<33>(1), &secret::<33>(2)));
}
