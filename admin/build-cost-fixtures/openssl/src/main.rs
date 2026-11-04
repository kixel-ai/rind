use std::hint::black_box;

use openssl::derive::Deriver;
use openssl::ec::{EcGroup, EcKey};
use openssl::ecdsa::EcdsaSig;
use openssl::hash::{MessageDigest, hash};
use openssl::nid::Nid;
use openssl::pkey::PKey;
use openssl::symm::{Cipher, decrypt_aead, encrypt_aead};

fn main() {
    let message = black_box(b"build cost".as_slice());

    let digest = hash(MessageDigest::sha256(), message).unwrap();

    let cipher = Cipher::aes_128_gcm();
    let mut tag = [0; 16];
    let ciphertext =
        encrypt_aead(cipher, &[0x42; 16], Some(&[0; 12]), b"", message, &mut tag).unwrap();
    decrypt_aead(cipher, &[0x42; 16], Some(&[0; 12]), b"", &ciphertext, &tag).unwrap();

    let group = EcGroup::from_curve_name(Nid::X9_62_PRIME256V1).unwrap();
    let key = EcKey::generate(&group).unwrap();
    let signature = EcdsaSig::sign(&digest, &key).unwrap();
    assert!(signature.verify(&digest, &key).unwrap());

    let alice = PKey::generate_x25519().unwrap();
    let bob = PKey::generate_x25519().unwrap();
    let mut deriver = Deriver::new(&alice).unwrap();
    deriver.set_peer(&bob).unwrap();
    let secret = deriver.derive_to_vec().unwrap();

    black_box((digest, secret));
}
