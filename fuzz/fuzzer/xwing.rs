#![no_main]

//! X-Wing against RustCrypto's `x-wing`, which holds the same key, since both
//! import it from a seed. aws-lc-rs lacks X-Wing.
//!
//! The seed gives each library its decapsulation key, whose encapsulation keys
//! must match. `x-wing` encapsulates with fuzzed randomness, the fuzzed edit
//! tampers with the ciphertext, and both must decapsulate it to one secret,
//! rind refusing exactly the wrong lengths. rind's own encapsulation must open
//! under `x-wing`'s key to rind's secret. Fuzzed bytes as an encapsulation key
//! must be accepted by both or by neither. `x-wing`'s plain key, like rind's,
//! takes an all-zero X25519 output, as the draft specifies.

use libfuzzer_sys::fuzz_target;
use rind::kem::{Ciphertext, DecapsulationKey, EncapsulationKey, XWing};
use x_wing::{Decapsulate, Decapsulator, KeyExport};

mod edit;

fuzz_target!(|input: ([u8; 32], [u8; 64], edit::Edit, Vec<u8>)| {
    let (seed, randomness, edit, key) = input;

    let ours = DecapsulationKey::<XWing>::from_seed(&seed).unwrap();
    let theirs = x_wing::DecapsulationKey::from(seed);
    assert_eq!(ours.to_seed().as_ref(), seed);
    let theirs_public = theirs.encapsulation_key();
    assert_eq!(
        ours.public_key().as_ref(),
        theirs_public.to_bytes().as_slice()
    );

    // Their ciphertext, tampered with, to both.
    let (ciphertext, secret) = theirs_public.encapsulate_deterministic(&randomness.into());
    let mut bytes = ciphertext.as_slice().to_vec();
    let len = bytes.len();
    let changed = edit.apply(&mut bytes);
    match Ciphertext::<XWing>::new(&bytes) {
        Ok(c) => {
            assert_eq!(bytes.len(), len);
            let ours_secret = ours.decapsulate(&c);
            let theirs_secret = theirs.decapsulate(&bytes.as_slice().try_into().unwrap());
            assert_eq!(ours_secret.as_ref(), theirs_secret.as_slice());
            assert_eq!(theirs_secret == secret, !changed);
        }
        Err(e) => {
            assert_ne!(bytes.len(), len, "refused a ciphertext of the right length");
            assert_eq!(e, rind::Error::WrongLength);
        }
    }

    // Our ciphertext to their key.
    let (ciphertext, secret) = ours.public_key().encapsulate().unwrap();
    let theirs_secret = theirs.decapsulate(&ciphertext.as_ref().try_into().unwrap());
    assert_eq!(secret.as_ref(), theirs_secret.as_slice());

    // Any bytes as an encapsulation key.
    match (
        EncapsulationKey::<XWing>::new(&key),
        x_wing::EncapsulationKey::try_from(&key[..]),
    ) {
        (Ok(ours), Ok(theirs)) => assert_eq!(ours.as_ref(), theirs.to_bytes().as_slice()),
        (Err(_), Err(_)) => {}
        (ours, theirs) => panic!("ours {}, theirs {}", ours.is_ok(), theirs.is_ok()),
    }
});
