use std::hint::black_box;

use aws_lc_rs::rand::SystemRandom;
use aws_lc_rs::signature::{self, EcdsaKeyPair, KeyPair, UnparsedPublicKey};
use aws_lc_rs::{aead, agreement, digest};

fn main() {
    let message = black_box(b"build cost".as_slice());
    let rng = SystemRandom::new();

    let hash = digest::digest(&digest::SHA256, message);

    let key =
        aead::LessSafeKey::new(aead::UnboundKey::new(&aead::AES_128_GCM, &[0x42; 16]).unwrap());
    let nonce = || aead::Nonce::assume_unique_for_key([0; 12]);
    let mut in_out = message.to_vec();
    key.seal_in_place_append_tag(nonce(), aead::Aad::empty(), &mut in_out)
        .unwrap();
    key.open_in_place(nonce(), aead::Aad::empty(), &mut in_out)
        .unwrap();

    let key_pair = EcdsaKeyPair::generate(&signature::ECDSA_P256_SHA256_ASN1_SIGNING).unwrap();
    let sig = key_pair.sign(&rng, message).unwrap();
    UnparsedPublicKey::new(
        &signature::ECDSA_P256_SHA256_ASN1,
        key_pair.public_key().as_ref(),
    )
    .verify(message, sig.as_ref())
    .unwrap();

    let alice = agreement::EphemeralPrivateKey::generate(&agreement::X25519, &rng).unwrap();
    let bob = agreement::EphemeralPrivateKey::generate(&agreement::X25519, &rng).unwrap();
    let bob_public = bob.compute_public_key().unwrap();
    let secret = agreement::agree_ephemeral(
        alice,
        agreement::UnparsedPublicKey::new(&agreement::X25519, bob_public.as_ref()),
        (),
        |secret| Ok(secret.to_vec()),
    )
    .unwrap();

    black_box((hash.as_ref(), secret));
}
