#![no_main]

//! ML-KEM-768 decapsulating what aws-lc-rs encapsulates, tampered with.
//!
//! rind's decapsulation keys are only ever generated, and never exported, so
//! aws-lc-rs cannot hold the same key: this checks rind recovers aws-lc-rs's
//! secret exactly when the ciphertext is untouched. The in-crate crosscheck
//! compares the implicit-rejection secret.

use aws_lc_rs::kem as theirs;
use libfuzzer_sys::fuzz_target;
use rind::kem as ours;

mod edit;

fuzz_target!(|edit: edit::Edit| {
    let key = ours::DecapsulationKey::<ours::MlKem768>::generate().unwrap();
    let (ciphertext, secret) =
        theirs::EncapsulationKey::new(&theirs::ML_KEM_768, key.public_key().as_ref())
            .unwrap()
            .encapsulate()
            .unwrap();
    let mut ciphertext = ciphertext.as_ref().to_vec();
    let changed = edit.apply(&mut ciphertext);

    match (ciphertext.len(), ours::Ciphertext::new(&ciphertext)) {
        (1088, Ok(c)) => assert_eq!(key.decapsulate(&c).as_ref() == secret.as_ref(), !changed),
        (1088, Err(e)) => panic!("refused a ciphertext of the right length: {e:?}"),
        (_, result) => assert_eq!(result.err(), Some(rind::Error::WrongLength)),
    }
});
