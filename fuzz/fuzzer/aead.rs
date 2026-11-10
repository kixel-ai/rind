#![no_main]

//! Each AEAD sealing and opening, tampered with, against aws-lc-rs's, and
//! AES-GCM with any IV and tag length against aws-lc's, which aws-lc-rs does
//! not expose.

use libfuzzer_sys::{arbitrary, arbitrary::Arbitrary, fuzz_target};
use rind::aead::{Key, Nonce, gcm};

mod edit;

fuzz_target!(|input: (Operation, edit::Edit)| {
    let (op, edit) = input;
    let (ours, theirs, key, nonce, aad, plain) = match &op {
        Operation::Gcm {
            key,
            key_len,
            iv,
            tag_len,
            aad,
            plain,
        } => {
            let tag_len = TAG_LENGTHS[usize::from(*tag_len) % TAG_LENGTHS.len()];
            return gcm_any(&key[..key_len.bytes()], iv, tag_len, aad, plain, &edit);
        }
        Operation::ChaCha20Poly1305 {
            key,
            nonce,
            aad,
            plain,
        } => (
            &rind::aead::CHACHA20_POLY1305,
            &aws_lc_rs::aead::CHACHA20_POLY1305,
            &key[..],
            nonce,
            aad,
            plain,
        ),
        Operation::Aes128Gcm {
            key,
            nonce,
            aad,
            plain,
        } => (
            &rind::aead::AES_128_GCM,
            &aws_lc_rs::aead::AES_128_GCM,
            &key[..],
            nonce,
            aad,
            plain,
        ),
        Operation::Aes192Gcm {
            key,
            nonce,
            aad,
            plain,
        } => (
            &rind::aead::AES_192_GCM,
            &aws_lc_rs::aead::AES_192_GCM,
            &key[..],
            nonce,
            aad,
            plain,
        ),
        Operation::Aes256Gcm {
            key,
            nonce,
            aad,
            plain,
        } => (
            &rind::aead::AES_256_GCM,
            &aws_lc_rs::aead::AES_256_GCM,
            &key[..],
            nonce,
            aad,
            plain,
        ),
    };

    let right = baseline_encrypt(theirs, key, nonce, aad, plain);
    let k = Key::new(ours, key).unwrap();
    let left = {
        let mut cipher = plain.clone();
        let tag = k
            .seal_in_place_separate_tag(Nonce::assume_unique_for_key(*nonce), aad, &mut cipher)
            .unwrap();

        let mut roundtrip = cipher.clone();
        k.open_in_place_separate_tag(
            Nonce::assume_unique_for_key(*nonce),
            aad,
            tag,
            &mut roundtrip,
        )
        .unwrap();
        assert_eq!(&roundtrip, plain);
        (cipher, tag.as_ref().try_into().unwrap())
    };

    assert_eq!(left, right);

    // Both open the sealed message tampered with alike, and refuse it if
    // it changed.
    let (cipher, tag) = right;
    let mut sealed = [&cipher[..], &tag].concat();
    let changed = edit.apply(&mut sealed);
    let mut ours_sealed = sealed.clone();
    let ours_result = k
        .open_in_place(Nonce::assume_unique_for_key(*nonce), aad, &mut ours_sealed)
        .map(|plain| plain.to_vec());
    let theirs_result = baseline_decrypt(theirs, key, nonce, aad, sealed);
    assert_eq!(ours_result.as_ref().ok(), theirs_result.as_ref());
    assert_eq!(ours_result.is_err(), changed);
});

fn baseline_encrypt(
    alg: &'static aws_lc_rs::aead::Algorithm,
    key: &[u8],
    nonce: &[u8; 12],
    aad: &[u8],
    plain: &[u8],
) -> (Vec<u8>, [u8; 16]) {
    let k = aws_lc_rs::aead::LessSafeKey::new(aws_lc_rs::aead::UnboundKey::new(alg, key).unwrap());
    let mut cipher = plain.to_vec();
    let tag = k
        .seal_in_place_separate_tag(
            aws_lc_rs::aead::Nonce::assume_unique_for_key(*nonce),
            aws_lc_rs::aead::Aad::from(aad),
            &mut cipher,
        )
        .unwrap();

    let mut tag_array = [0u8; 16];
    tag_array.copy_from_slice(tag.as_ref());
    (cipher, tag_array)
}

fn baseline_decrypt(
    alg: &'static aws_lc_rs::aead::Algorithm,
    key: &[u8],
    nonce: &[u8; 12],
    aad: &[u8],
    mut sealed: Vec<u8>,
) -> Option<Vec<u8>> {
    let k = aws_lc_rs::aead::LessSafeKey::new(aws_lc_rs::aead::UnboundKey::new(alg, key).unwrap());
    k.open_in_place(
        aws_lc_rs::aead::Nonce::assume_unique_for_key(*nonce),
        aws_lc_rs::aead::Aad::from(aad),
        &mut sealed,
    )
    .ok()
    .map(|plain| plain.to_vec())
}

/// AES-GCM through `aead::gcm` with `iv` and tags of `tag_len`, sealing and
/// opening the sealed message tampered with as aws-lc does, and refusing it
/// if it changed.
fn gcm_any(
    key: &[u8],
    iv: &[u8],
    tag_len: gcm::TagLength,
    aad: &[u8],
    plain: &[u8],
    edit: &edit::Edit,
) {
    let algorithm = match key.len() {
        16 => &rind::cipher::AES_128,
        24 => &rind::cipher::AES_192,
        _ => &rind::cipher::AES_256,
    };
    let ours = gcm::Key::new(algorithm, key, tag_len).unwrap();
    let Ok(ours_iv) = gcm::Iv::assume_unique_for_key(iv) else {
        assert!(iv.is_empty());
        assert_eq!(
            aws_lc_gcm(Op::Seal, key, ours.tag_len(), iv, aad, plain),
            None
        );
        return;
    };

    let mut sealed = plain.to_vec();
    ours.seal_in_place_append_tag(ours_iv, aad, &mut sealed)
        .unwrap();
    let theirs = aws_lc_gcm(Op::Seal, key, ours.tag_len(), iv, aad, plain);
    assert_eq!(Some(&sealed), theirs.as_ref());

    let changed = edit.apply(&mut sealed);
    let theirs = aws_lc_gcm(Op::Open, key, ours.tag_len(), iv, aad, &sealed);
    let ours = ours
        .open_in_place(
            gcm::Iv::assume_unique_for_key(iv).unwrap(),
            aad,
            &mut sealed,
        )
        .map(|plain| plain.to_vec());
    assert_eq!(ours.as_ref().ok(), theirs.as_ref());
    match changed {
        true => assert!(ours.is_err()),
        false => assert_eq!(ours.unwrap(), plain),
    }
}

const TAG_LENGTHS: [gcm::TagLength; 7] = [
    gcm::TagLength::Full,
    gcm::TagLength::Truncated120,
    gcm::TagLength::Truncated112,
    gcm::TagLength::Truncated104,
    gcm::TagLength::Truncated96,
    gcm::TagLength::Truncated64,
    gcm::TagLength::Truncated32,
];

enum Op {
    Seal,
    Open,
}

/// aws-lc's AES-GCM output for `input` with tags of `tag_len` bytes, or
/// `None` if it refuses it.
fn aws_lc_gcm(
    op: Op,
    key: &[u8],
    tag_len: usize,
    iv: &[u8],
    aad: &[u8],
    input: &[u8],
) -> Option<Vec<u8>> {
    let mut out = vec![0; input.len() + tag_len];
    let mut out_len = 0;
    // SAFETY: each pointer and length describes a live buffer, and the
    // context is freed once, after its last use.
    let ok = unsafe {
        let aead = match key.len() {
            16 => aws_lc_sys::EVP_aead_aes_128_gcm(),
            24 => aws_lc_sys::EVP_aead_aes_192_gcm(),
            _ => aws_lc_sys::EVP_aead_aes_256_gcm(),
        };
        let ctx = aws_lc_sys::EVP_AEAD_CTX_new(aead, key.as_ptr(), key.len(), tag_len);
        assert!(!ctx.is_null());
        let f = match op {
            Op::Seal => aws_lc_sys::EVP_AEAD_CTX_seal,
            Op::Open => aws_lc_sys::EVP_AEAD_CTX_open,
        };
        let ok = f(
            ctx,
            out.as_mut_ptr(),
            &mut out_len,
            out.len(),
            iv.as_ptr(),
            iv.len(),
            input.as_ptr(),
            input.len(),
            aad.as_ptr(),
            aad.len(),
        );
        aws_lc_sys::EVP_AEAD_CTX_free(ctx);
        ok
    };
    out.truncate(out_len);
    (ok == 1).then_some(out)
}

#[derive(Arbitrary, Debug)]
enum Operation {
    /// The first `key_len` bytes of `key`, and the tag length `tag_len`
    /// indexes in [`TAG_LENGTHS`].
    Gcm {
        key: [u8; 32],
        key_len: AesKeyLen,
        iv: Vec<u8>,
        tag_len: u8,
        aad: Vec<u8>,
        plain: Vec<u8>,
    },
    ChaCha20Poly1305 {
        key: [u8; 32],
        nonce: [u8; 12],
        aad: Vec<u8>,
        plain: Vec<u8>,
    },
    Aes128Gcm {
        key: [u8; 16],
        nonce: [u8; 12],
        aad: Vec<u8>,
        plain: Vec<u8>,
    },
    Aes256Gcm {
        key: [u8; 32],
        nonce: [u8; 12],
        aad: Vec<u8>,
        plain: Vec<u8>,
    },
    Aes192Gcm {
        key: [u8; 24],
        nonce: [u8; 12],
        aad: Vec<u8>,
        plain: Vec<u8>,
    },
}

#[derive(Arbitrary, Debug)]
enum AesKeyLen {
    Aes128,
    Aes192,
    Aes256,
}

impl AesKeyLen {
    fn bytes(&self) -> usize {
        match self {
            Self::Aes128 => 16,
            Self::Aes192 => 24,
            Self::Aes256 => 32,
        }
    }
}
