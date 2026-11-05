#![no_main]

//! RSA-OAEP decryption against aws-lc-rs's, of ciphertexts aws-lc-rs
//! encrypted and the fuzzer tampered with.
//!
//! Both load the same key, so for every ciphertext they must agree on
//! whether it decrypts and to what. The first byte picks the algorithm, and
//! the rest is the message, the label, and then the edit.

use std::sync::LazyLock;

use aws_lc_rs::rsa::{self as theirs, OaepPrivateDecryptingKey, OaepPublicEncryptingKey};
use libfuzzer_sys::{arbitrary, arbitrary::Arbitrary, fuzz_target};
use rind::rsa as ours;

mod edit;

const PKCS8: &[u8] = include_bytes!("../../rind/src/high/rsa/rsa2048.pkcs8.der");

/// Each side's algorithms, ours bound to our key.
const ALGORITHMS: [(&ours::OaepAlgorithm, &theirs::OaepAlgorithm); 4] = [
    (&ours::legacy::OAEP_SHA1, &theirs::OAEP_SHA1_MGF1SHA1),
    (&ours::OAEP_SHA256, &theirs::OAEP_SHA256_MGF1SHA256),
    (&ours::OAEP_SHA384, &theirs::OAEP_SHA384_MGF1SHA384),
    (&ours::OAEP_SHA512, &theirs::OAEP_SHA512_MGF1SHA512),
];

static KEYS: LazyLock<(
    [ours::DecryptingKey; 4],
    OaepPrivateDecryptingKey,
    OaepPublicEncryptingKey,
)> = LazyLock::new(|| {
    let theirs = theirs::PrivateDecryptingKey::from_pkcs8(PKCS8).unwrap();
    let public = OaepPublicEncryptingKey::new(theirs.public_key()).unwrap();
    (
        ALGORITHMS.map(|(algorithm, _)| ours::DecryptingKey::from_pkcs8(algorithm, PKCS8).unwrap()),
        OaepPrivateDecryptingKey::new(theirs).unwrap(),
        public,
    )
});

#[derive(Arbitrary, Debug)]
struct Input {
    algorithm: u8,
    message: Vec<u8>,
    label: Vec<u8>,
    edit: edit::Edit,
}

fuzz_target!(|input: Input| {
    let index = usize::from(input.algorithm % 4);
    let theirs_algorithm = ALGORITHMS[index].1;
    let (ours, theirs, public) = &*KEYS;
    let ours = &ours[index];

    let message = &input.message[..input
        .message
        .len()
        .min(public.max_plaintext_size(theirs_algorithm))];
    let mut ciphertext = vec![0; public.ciphertext_size()];
    public
        .encrypt(
            theirs_algorithm,
            message,
            &mut ciphertext,
            Some(&input.label),
        )
        .unwrap();
    let changed = input.edit.apply(&mut ciphertext);

    let mut plaintext = vec![0; theirs.min_output_size()];
    let expected = theirs
        .decrypt(
            theirs_algorithm,
            &ciphertext,
            &mut plaintext,
            Some(&input.label),
        )
        .ok();
    match ours.decrypt(&ciphertext, &input.label) {
        Ok(ours) => assert_eq!(Some(ours.as_ref()), expected.as_deref()),
        Err(e) => {
            assert_eq!(e, rind::Error::DecryptFailed);
            assert_eq!(expected, None);
        }
    }
    if !changed {
        assert_eq!(expected.as_deref(), Some(message));
    }
});
