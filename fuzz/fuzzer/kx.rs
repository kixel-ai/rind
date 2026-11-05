#![no_main]

use aws_lc_rs::agreement as theirs;
use libfuzzer_sys::{arbitrary, arbitrary::Arbitrary, fuzz_target};
use rind::agreement as ours;

fuzz_target!(|op: Operation| {
    match op {
        Operation::X25519 { scalar, peer } => {
            check(&ours::X25519, &theirs::X25519, &scalar, &peer);
        }
        Operation::P256 { scalar, peer } => {
            check(&ours::ECDH_P256, &theirs::ECDH_P256, &scalar, &peer);
        }
        Operation::P384 { scalar, peer } => {
            check(&ours::ECDH_P384, &theirs::ECDH_P384, &scalar, &peer);
        }
        Operation::P521 { scalar, peer } => {
            check(&ours::ECDH_P521, &theirs::ECDH_P521, &scalar, &peer);
        }
    }
});

// Both load the fuzzed scalar, which checks our base and variable-base
// multiplication against aws-lc-rs's, and agree with the fuzzed peer key.
fn check(
    ours_algorithm: &'static ours::Algorithm,
    theirs_algorithm: &'static theirs::Algorithm,
    scalar: &[u8],
    peer: &[u8],
) {
    let ours_key = ours::PrivateKey::from_private_key(ours_algorithm, scalar);
    let theirs_key = theirs::PrivateKey::from_private_key(theirs_algorithm, scalar);
    assert_eq!(ours_key.is_ok(), theirs_key.is_ok());
    let (Ok(ours_key), Ok(theirs_key)) = (ours_key, theirs_key) else {
        return;
    };
    let ours_public = ours_key.public_key();
    let theirs_public = theirs_key.compute_public_key().unwrap();
    assert_eq!(ours_public.as_ref(), theirs_public.as_ref());

    // Both accept or refuse the same peer key, and agree on the secret.
    let ours_secret = ours_key.agree(peer);
    let theirs_secret = theirs::agree(
        &theirs_key,
        theirs::UnparsedPublicKey::new(theirs_algorithm, peer),
        (),
        |secret| Ok(secret.to_vec()),
    );
    match (ours_secret, theirs_secret) {
        (Ok(ours), Ok(theirs)) => assert_eq!(ours.as_ref(), &theirs[..]),
        (Err(_), Err(())) => {}
        (ours, theirs) => panic!("rind: {:?}, aws-lc-rs: {:?}", ours.err(), theirs.err()),
    }
}

#[derive(Arbitrary, Debug)]
enum Operation {
    X25519 { scalar: [u8; 32], peer: [u8; 32] },
    P256 { scalar: [u8; 32], peer: [u8; 65] },
    P384 { scalar: [u8; 48], peer: [u8; 97] },
    P521 { scalar: [u8; 66], peer: [u8; 133] },
}
