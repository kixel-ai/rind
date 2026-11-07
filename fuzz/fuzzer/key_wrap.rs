#![no_main]

use aws_lc_rs::key_wrap::{KeyWrap, KeyWrapPadded};
use libfuzzer_sys::{arbitrary, arbitrary::Arbitrary, fuzz_target};
use rind::key_wrap::{AES_128, AES_256, AesKek};

mod edit;

fuzz_target!(|input: (Operation, edit::Edit)| {
    let (op, edit) = input;
    let (ours, theirs, kek, key) = match &op {
        Operation::Aes128 { kek, key } => (&AES_128, &aws_lc_rs::key_wrap::AES_128, &kek[..], key),
        Operation::Aes256 { kek, key } => (&AES_256, &aws_lc_rs::key_wrap::AES_256, &kek[..], key),
    };
    let ours = AesKek::new(ours, kek).unwrap();
    let theirs = || aws_lc_rs::key_wrap::AesKek::new(theirs, kek).unwrap();

    // Both wrap the keys RFC 5649 allows, alike, and refuse the rest.
    let mut wrapped = vec![0u8; key.len().next_multiple_of(8) + 8];
    let mut right = vec![0u8; key.len() + 15];
    let ours_padded = ours.wrap_padded(key, &mut wrapped);
    let theirs_padded = theirs().wrap_with_padding(key, &mut right);
    assert_eq!(ours_padded.is_ok(), theirs_padded.is_ok());
    if let Ok(right) = theirs_padded {
        assert_eq!(wrapped, right);

        // Both unwrap the wrapped key tampered with alike, and refuse it if
        // it changed.
        let changed = edit.apply(&mut wrapped);
        let mut ours_key = vec![0u8; wrapped.len().saturating_sub(8)];
        let ours_result = ours
            .unwrap_padded(&wrapped, &mut ours_key)
            .map(|k| k.to_vec());
        let mut theirs_key = vec![0u8; wrapped.len()];
        let theirs_result = theirs()
            .unwrap_with_padding(&wrapped, &mut theirs_key)
            .map(|out| out.to_vec());
        assert_eq!(ours_result.as_ref().ok(), theirs_result.as_ref().ok());
        assert_eq!(ours_result.is_err(), changed);
    }

    // Both wrap the keys RFC 3394 allows, alike, and refuse the rest.
    let mut wrapped = vec![0u8; key.len() + 8];
    let mut right = vec![0u8; key.len() + 8];
    let ours_result = ours.wrap(key, &mut wrapped);
    let theirs_result = theirs().wrap(key, &mut right);
    assert_eq!(ours_result.is_ok(), theirs_result.is_ok());
    if ours_result.is_err() {
        return;
    }
    assert_eq!(wrapped, right);

    // Both unwrap the wrapped key tampered with alike, and refuse it if it
    // changed.
    let changed = edit.apply(&mut wrapped);
    let mut ours_key = vec![0u8; wrapped.len().saturating_sub(8)];
    let ours_result = ours.unwrap(&wrapped, &mut ours_key).map(|()| ours_key);
    let mut theirs_key = vec![0u8; wrapped.len().saturating_sub(8)];
    let theirs_result = theirs()
        .unwrap(&wrapped, &mut theirs_key)
        .map(|out| out.to_vec());
    assert_eq!(ours_result.as_ref().ok(), theirs_result.as_ref().ok());
    assert_eq!(ours_result.is_err(), changed);
});

#[derive(Arbitrary, Debug)]
enum Operation {
    Aes128 { kek: [u8; 16], key: Vec<u8> },
    Aes256 { kek: [u8; 32], key: Vec<u8> },
}
