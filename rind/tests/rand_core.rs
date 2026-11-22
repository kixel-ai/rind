//! `rand::SystemRandom` as RustCrypto's crates take it.
#![cfg(feature = "rand_core")]

use p256::elliptic_curve::Generate;
use rand_core::{TryRng, UnwrapErr};
use rind::rand::SystemRandom;

#[test]
fn draws_differ() {
    let mut rng = SystemRandom;
    let mut a = [0u8; 32];
    let mut b = [0u8; 32];
    rng.try_fill_bytes(&mut a).unwrap();
    rng.try_fill_bytes(&mut b).unwrap();
    assert_ne!(a, b);
    assert_ne!(rng.try_next_u64().unwrap(), rng.try_next_u64().unwrap());
    // Two equal draws of 32 bits happen once in 2^32 pairs.
    assert_ne!(
        (rng.try_next_u32().unwrap(), rng.try_next_u32().unwrap()),
        (rng.try_next_u32().unwrap(), rng.try_next_u32().unwrap())
    );
}

#[test]
fn rustcrypto_takes_it() {
    // Fallible, as RustCrypto's `try_` forms take it, and infallible
    // through `UnwrapErr`.
    let a = p256::SecretKey::try_generate_from_rng(&mut SystemRandom).unwrap();
    let b = p256::SecretKey::generate_from_rng(&mut UnwrapErr(SystemRandom));
    assert_ne!(a.to_bytes(), b.to_bytes());
}
