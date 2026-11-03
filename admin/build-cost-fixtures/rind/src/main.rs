use std::hint::black_box;

use rind::signature::{EcdsaKeyPair, PublicKey, sign, verify};
use rind::{aead, agreement, digest};

fn main() {
    let message = black_box(b"build cost".as_slice());

    let hash = digest::digest(&digest::SHA256, message);

    let key = aead::Key::new(&aead::AES_128_GCM, &[0x42; 16]).unwrap();
    let nonce = || aead::Nonce::assume_unique_for_key([0; 12]);
    let mut in_out = message.to_vec();
    key.seal_in_place_append_tag(nonce(), b"", &mut in_out)
        .unwrap();
    key.open_in_place(nonce(), b"", &mut in_out).unwrap();

    let key_pair = EcdsaKeyPair::generate(&sign::ECDSA_P256_SHA256_ASN1).unwrap();
    let signature = key_pair.sign(message).unwrap();
    PublicKey::new(
        &verify::ECDSA_P256_SHA256_ASN1,
        key_pair.public_key().as_ref(),
    )
    .unwrap()
    .verify(message, signature.as_ref())
    .unwrap();

    let alice = agreement::PrivateKey::generate(&agreement::X25519).unwrap();
    let bob = agreement::PrivateKey::generate(&agreement::X25519).unwrap();
    let secret = alice.agree(bob.public_key().as_ref()).unwrap();

    black_box((hash.as_ref(), secret.as_ref()));
}
