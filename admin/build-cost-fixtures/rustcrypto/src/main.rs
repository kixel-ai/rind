use std::hint::black_box;

use aes_gcm::aead::{AeadInOut, KeyInit};
use aes_gcm::{Aes128Gcm, Nonce};
use p256::ecdsa::signature::{Signer, Verifier};
use p256::ecdsa::{Signature, SigningKey};
use p256::elliptic_curve::Generate;
use sha2::{Digest, Sha256};
use x25519_dalek::{EphemeralSecret, PublicKey};

fn main() {
    let message = black_box(b"build cost".as_slice());

    let hash = Sha256::digest(message);

    let key = Aes128Gcm::new(&[0x42; 16].into());
    let nonce = Nonce::from([0; 12]);
    let mut in_out = message.to_vec();
    key.encrypt_in_place(&nonce, b"", &mut in_out).unwrap();
    key.decrypt_in_place(&nonce, b"", &mut in_out).unwrap();

    let signing_key = SigningKey::try_generate().unwrap();
    let signature: Signature = signing_key.sign(message);
    signing_key
        .verifying_key()
        .verify(message, &signature)
        .unwrap();

    let alice = EphemeralSecret::random();
    let bob = EphemeralSecret::random();
    let secret = alice.diffie_hellman(&PublicKey::from(&bob));

    black_box((hash, secret.as_bytes()));
}
