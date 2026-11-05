use std::hint::black_box;

use graviola::aead::AesGcm;
use graviola::hashing::{Hash, Sha256};
use graviola::key_agreement::x25519;
use graviola::signing::ecdsa::{P256, SigningKey, VerifyingKey};

fn main() {
    let message = black_box(b"build cost".as_slice());

    let hash = Sha256::hash(message);

    let key = AesGcm::new(&[0x42; 16]);
    let mut in_out = message.to_vec();
    let mut tag = [0; 16];
    key.encrypt(&[0; 12], b"", &mut in_out, &mut tag);
    key.decrypt(&[0; 12], b"", &mut in_out, &tag).unwrap();

    let signing_key = SigningKey::<P256>::generate().unwrap();
    let public_key = signing_key.private_key.public_key_uncompressed();
    let mut signature = [0; 64];
    let signature = signing_key
        .sign::<Sha256>(&[message], &mut signature)
        .unwrap();
    VerifyingKey::<P256>::from_x962_uncompressed(&public_key)
        .unwrap()
        .verify::<Sha256>(&[message], signature)
        .unwrap();

    let alice = x25519::PrivateKey::new_random().unwrap();
    let bob = x25519::PrivateKey::new_random().unwrap();
    let secret = alice.diffie_hellman(&bob.public_key()).unwrap();

    black_box((hash.as_ref(), secret.0));
}
