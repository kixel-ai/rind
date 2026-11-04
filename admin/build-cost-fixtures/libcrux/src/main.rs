use std::hint::black_box;

use getrandom::SysRng;
use libcrux_aesgcm::{AesGcm128Key, AesGcm128Nonce, AesGcm128Tag};
use libcrux_ecdsa::DigestAlgorithm;
use libcrux_ecdsa::p256::{self, rand::generate_key_pair};

fn main() {
    let message = black_box(b"build cost".as_slice());
    let mut rng = SysRng;

    let hash = libcrux_sha2::sha256(message);

    let key = AesGcm128Key::from([0x42; 16]);
    let nonce = AesGcm128Nonce::from([0; 12]);
    let mut tag = AesGcm128Tag::from([0; 16]);
    let mut ciphertext = vec![0; message.len()];
    let mut plaintext = vec![0; message.len()];
    key.encrypt(&mut ciphertext, &mut tag, &nonce, b"", message)
        .unwrap();
    key.decrypt(&mut plaintext, &nonce, b"", &ciphertext, &tag)
        .unwrap();

    let (private_key, public_key) = generate_key_pair(&mut rng).unwrap();
    let signature =
        p256::rand::sign(DigestAlgorithm::Sha256, message, &private_key, &mut rng).unwrap();
    p256::verify(DigestAlgorithm::Sha256, message, &signature, &public_key).unwrap();

    let (alice, _) = libcrux_ecdh::x25519_key_gen(&mut rng).unwrap();
    let (_, bob_public) = libcrux_ecdh::x25519_key_gen(&mut rng).unwrap();
    let secret = libcrux_ecdh::x25519_derive(&bob_public, &alice).unwrap();

    black_box((hash, secret.0));
}
