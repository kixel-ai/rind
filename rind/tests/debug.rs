//! Every symmetric key and keyed state's `Debug` names its algorithm and
//! never shows its bytes, and neither does any other secret's.

/// Formats `value`, whose secret bytes are all 0xff, failing if they show.
fn show(value: &impl core::fmt::Debug) -> String {
    let shown = format!("{value:?}");
    assert!(!shown.contains("255") && !shown.contains("ff"), "{shown}");
    shown
}

#[test]
fn aead() {
    use rind::aead::{
        AES_128_GCM, AES_192_GCM, AES_256_GCM, CHACHA20_POLY1305, Key, Nonce, RandomizedNonceKey,
    };
    for (algorithm, name) in [
        (&AES_128_GCM, "Aes128Gcm"),
        (&AES_192_GCM, "Aes192Gcm"),
        (&AES_256_GCM, "Aes256Gcm"),
        (&CHACHA20_POLY1305, "ChaCha20Poly1305"),
    ] {
        assert_eq!(
            format!("{algorithm:?}"),
            format!("Algorithm {{ id: {name} }}")
        );
        let key = Key::new(algorithm, &[0xff; 32][..algorithm.key_len()]).unwrap();
        assert_eq!(show(&key), format!("Key {{ algorithm: {name}, .. }}"));
    }
    let nonce = Nonce::assume_unique_for_key([0xff; 12]);
    assert_eq!(show(&nonce), "Nonce(..)");
    let key = RandomizedNonceKey::new(&[0xff; 32]);
    assert_eq!(show(&key), "RandomizedNonceKey { .. }");

    use rind::aead::gcm::{self, Iv, TagLength};
    use rind::cipher;
    for (algorithm, len) in [(&cipher::AES_128, 16), (&cipher::AES_256, 32)] {
        let key = gcm::Key::new(algorithm, &[0xff; 32][..len], TagLength::Full).unwrap();
        let algorithm = format!("Algorithm {{ key_len: {len} }}");
        assert_eq!(show(&key), format!("Key {{ algorithm: {algorithm}, .. }}"));
    }
    let iv = Iv::assume_unique_for_key(&[0xff; 12]).unwrap();
    assert_eq!(show(&iv), "Iv(..)");

    use rind::aead::quic::{AES_128, AES_256, CHACHA20, HeaderProtectionKey};
    for (algorithm, name) in [
        (&AES_128, "Aes128"),
        (&AES_256, "Aes256"),
        (&CHACHA20, "ChaCha20"),
    ] {
        let key = HeaderProtectionKey::new(algorithm, &[0xff; 32][..algorithm.key_len()]).unwrap();
        let expected = format!("HeaderProtectionKey {{ algorithm: {name}, .. }}");
        assert_eq!(show(&key), expected);
    }
}

#[test]
fn cipher() {
    use rind::cipher::{AES_128, AES_256, Aes, AesCtr, ChaCha20};
    use rind::key_wrap::{self, AesKek};
    for (algorithm, kek, len) in [
        (&AES_128, &key_wrap::AES_128, 16),
        (&AES_256, &key_wrap::AES_256, 32),
    ] {
        let key = &[0xff; 32][..len];
        let algorithm_shown = format!("Algorithm {{ key_len: {len} }}");
        let aes = Aes::new(algorithm, key).unwrap();
        assert_eq!(
            show(&aes),
            format!("Aes {{ algorithm: {algorithm_shown}, .. }}")
        );
        let ctr = AesCtr::new(algorithm, key, 128).unwrap();
        assert_eq!(
            show(&ctr),
            format!("AesCtr {{ algorithm: {algorithm_shown}, .. }}")
        );
        let kek = AesKek::new(kek, key).unwrap();
        assert_eq!(
            show(&kek),
            format!("AesKek {{ algorithm: {algorithm_shown}, .. }}")
        );
    }
    assert_eq!(show(&ChaCha20::new(&[0xff; 32])), "ChaCha20 { .. }");
}

#[test]
fn hmac() {
    use rind::{digest, hkdf, hmac, pbkdf2};
    let key = hmac::Key::new(&hmac::HMAC_SHA384, &[0xff; 32]);
    assert_eq!(show(&key), "Key { algorithm: Sha384, .. }");
    let mut ctx = hmac::Context::with_key(&key);
    ctx.update(&[0xff; 3]);
    assert_eq!(show(&ctx), "Context { algorithm: Sha384, .. }");

    let mut ctx = digest::Context::new(&digest::SHA512_256);
    ctx.update(&[0xff; 3]);
    assert_eq!(show(&ctx), "Context { algorithm: Sha512_256, .. }");

    let salt = hkdf::Salt::new(&hkdf::HKDF_SHA256, &[0xff; 32]);
    assert_eq!(show(&salt), "Salt { algorithm: Sha256, .. }");
    let prk = salt.extract(&[0xff; 32]);
    assert_eq!(show(&prk), "Prk { algorithm: Sha256, .. }");
    assert_eq!(show(&prk.expand(&[], 16)), "Okm { algorithm: Sha256, .. }");

    let secret = pbkdf2::Secret::new(&pbkdf2::PBKDF2_HMAC_SHA512, &[0xff; 8]);
    assert_eq!(show(&secret), "Secret { algorithm: Sha512, .. }");
    assert_eq!(format!("{:?}", hmac::HMAC_SHA384), "Algorithm(Sha384)");
}

#[test]
fn kem() {
    use rind::kem::{DecapsulationKey, ML_KEM_768};
    assert_eq!(format!("{ML_KEM_768:?}"), "MlKem768");
    let key = DecapsulationKey::generate(&ML_KEM_768).unwrap();
    assert_eq!(format!("{key:?}"), "DecapsulationKey { .. }");
    let public = key.public_key();
    let shown = format!("{:?}", public.as_ref());
    assert_eq!(format!("{public:?}"), format!("EncapsulationKey({shown})"));
    let (_, secret) = public.encapsulate().unwrap();
    assert_eq!(format!("{secret:?}"), "SharedSecret(..)");
}

#[test]
fn rsa() {
    use rind::rsa::{DecryptingKey, OAEP_SHA256};
    assert_eq!(format!("{OAEP_SHA256:?}"), "OaepAlgorithm(Sha256)");
    let der = include_bytes!("../src/high/rsa/rsa2048.der");
    let key = DecryptingKey::from_pkcs1(&OAEP_SHA256, der).unwrap();
    assert_eq!(
        format!("{key:?}"),
        "DecryptingKey { algorithm: OaepAlgorithm(Sha256), .. }"
    );
    let public = key.public_key();
    let bytes = format!("{:?}", public.as_ref());
    assert_eq!(
        format!("{public:?}"),
        format!("EncryptingKey {{ algorithm: OaepAlgorithm(Sha256), bytes: {bytes} }}")
    );
    let ciphertext = public.encrypt(&[0xff; 4], b"").unwrap();
    let bytes = format!("{:?}", ciphertext.as_ref());
    assert_eq!(format!("{ciphertext:?}"), format!("Ciphertext({bytes})"));
    let plaintext = key.decrypt(ciphertext.as_ref(), b"").unwrap();
    assert_eq!(show(&plaintext), "Plaintext(..)");
}
