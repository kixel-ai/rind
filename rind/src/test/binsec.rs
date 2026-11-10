// SPDX-License-Identifier: Apache-2.0 OR ISC OR MIT-0

//! The harnesses `admin/ct-binsec` checks under BINSEC: each runs one
//! primitive's secret paths through the public API in a single checked
//! region. The key is marked secret where rind marks it once parsed, and a
//! harness marks the other secrets it passes, such as a plaintext.

use crate::low::ct;
use crate::low::ct_binsec::checked;

fn secret<const N: usize>(fill: u8) -> [u8; N] {
    let bytes = [fill; N];
    ct::secret_slice(&bytes);
    bytes
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_aes_gcm() {
    use crate::aead::*;

    checked(|| {
        for algorithm in [&AES_128_GCM, &AES_256_GCM] {
            let key = Key::new(algorithm, &secret::<32>(1)[..algorithm.key_len()]).unwrap();
            let nonce = || Nonce::assume_unique_for_key([2; 12]);
            let mut msg = secret::<75>(3);
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
        let mut msg = secret::<75>(3);
        let tag = key.seal_in_place_separate_tag(nonce(), &[4; 21], &mut msg).unwrap();
        let _ = key.open_in_place_separate_tag(nonce(), &[4; 21], tag, &mut msg);
    });
}

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_hmac() {
    use crate::hmac::*;

    checked(|| {
        for algorithm in [&HMAC_SHA256, &HMAC_SHA384] {
            let key = Key::new(algorithm, &secret::<200>(1));
            let tag = sign(&key, &secret::<150>(2));
            let _ = verify(&key, &secret::<150>(2), tag.as_ref());
        }
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
        key.agree(&peer).unwrap()
    });
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
fn ct_binsec_ecdsa_p256() {
    use crate::signature::*;

    let der = include_bytes!("../high/ecdsa/secp256r1.pkcs8.der");
    checked(|| {
        let key = EcdsaKeyPair::from_pkcs8(&sign::ECDSA_P256_SHA256_FIXED, der).unwrap();
        key.sign(&secret::<40>(1)).unwrap()
    });
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

#[test]
#[ignore = "admin/ct-binsec runs it under BINSEC"]
fn ct_binsec_rsa2048() {
    use crate::signature::*;

    let der = include_bytes!("../high/rsa/rsa2048.pkcs8.der");
    checked(|| {
        let key = RsaKeyPair::from_pkcs8(der).unwrap();
        key.sign(&sign::RSA_PKCS1_SHA256, &secret::<40>(1)).unwrap()
    });
}
